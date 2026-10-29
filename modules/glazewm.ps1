# ==============================================================================
# devbox-win :: Module: GlazeWM
# Path: modules/glazewm.ps1
# Description: Idempotent GlazeWM tiling window manager installation & configuration.
# Standard: Zero emojis. Verifies installation, config paths, and startup entry.
# ==============================================================================

param(
    [Parameter(Mandatory=$true)][System.Collections.IDictionary]$Config,
    [switch]$DryRun
)

Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "..\core\logger.ps1")
. (Join-Path $PSScriptRoot "..\core\state.ps1")
. (Join-Path $PSScriptRoot "..\core\manifest.ps1")
. (Join-Path $PSScriptRoot "..\core\symlink.ps1")

function Find-GlazewmExecutable {
    $cmd = Get-Command "glazewm" -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\glazewm\glazewm.exe"),
        "C:\Program Files\glazewm\glazewm.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    return $null
}

function Invoke-DevboxGlazewmModule {
    param(
        [System.Collections.IDictionary]$Config,
        [switch]$DryRun
    )

    $glazeConfig = if ($Config.Contains("glazewm") -and ($null -ne $Config["glazewm"])) {
        $Config["glazewm"]
    } else {
        @{}
    }

    $shouldInstall = if ($glazeConfig.Contains("install")) { [bool]$glazeConfig["install"] } else { $true }
    $autostart     = if ($glazeConfig.Contains("autostart")) { [bool]$glazeConfig["autostart"] } else { $true }

    $repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
    $manifest = Load-DevboxManifest
    $installedCount = 0
    $skippedCount   = 0
    $failedCount    = 0

    $pkgId = "glzr-io.glazewm"
    $exePath = Find-GlazewmExecutable

    # 1. Package Installation
    if ($shouldInstall) {
        if ($exePath) {
            Write-DevboxSkip "GlazeWM" "GlazeWM executable already present at '$exePath'"
            $skippedCount++
        } else {
            $installLoc = if ($Config.paths -and $Config.paths.apps) { $Config.paths.apps } elseif ($Config.install_location) { $Config.install_location } else { "" }
            $res = Install-DevboxWingetPackage -PackageId $pkgId -Location $installLoc -Manifest $manifest -DryRun:$DryRun
            if ($res.Skipped) {
                $skippedCount++
            } elseif ($res.Success) {
                $installedCount++
                $exePath = Find-GlazewmExecutable
            } else {
                $failedCount++
            }
        }
    }

    # 2. Config Verification
    $userConfigDir = Join-Path $HOME ".glzr\glazewm"
    $userConfigFile = Join-Path $userConfigDir "config.yaml"
    $sourceConfigFile = Join-Path $repoRoot "dotfiles\glazewm\config.yaml"

    if (Test-Path $userConfigFile) {
        Write-DevboxSkip "GlazeWM Config" "Configuration verified at '$userConfigFile'"
        $skippedCount++
    } elseif (Test-Path $sourceConfigFile) {
        if ($DryRun) {
            Write-DevboxDryRun "Would link GlazeWM config: $sourceConfigFile -> $userConfigFile"
            $installedCount++
        } else {
            $symRes = New-DevboxSymlink -Source $sourceConfigFile -Destination $userConfigFile
            if ($symRes.Status -eq "OK") {
                Write-DevboxOk "Configured GlazeWM config symlink: $userConfigFile"
                Add-DevboxManifestSymlink -Manifest $manifest -Destination $userConfigFile -Source $sourceConfigFile -BackupPath $symRes.BackupPath
                $installedCount++
            } else {
                Write-DevboxSkip "GlazeWM Config" $symRes.Message
                $skippedCount++
            }
        }
    }

    # 3. Startup Shortcut
    if ($autostart) {
        $wsh = New-Object -ComObject WScript.Shell
        $startupDir = $wsh.SpecialFolders.Item("Startup")
        $shortcutPath = Join-Path $startupDir "GlazeWM.lnk"

        $targetToLaunch = if ($exePath) { $exePath } else { "glazewm.exe" }

        if (Test-Path $shortcutPath) {
            Write-DevboxSkip "GlazeWM Startup" "Startup shortcut already present at '$shortcutPath'"
            $skippedCount++
        } elseif ($DryRun) {
            Write-DevboxDryRun "Would create startup shortcut for GlazeWM: $shortcutPath -> $targetToLaunch"
            $installedCount++
        } else {
            try {
                $sc = $wsh.CreateShortcut($shortcutPath)
                $sc.TargetPath = $targetToLaunch
                if ($exePath) { $sc.WorkingDirectory = Split-Path -Parent $exePath }
                $sc.Save()
                Add-DevboxManifestShortcut -Manifest $manifest -Path $shortcutPath
                Write-DevboxOk "Created GlazeWM startup shortcut at: $shortcutPath"
                $installedCount++
            } catch {
                Write-DevboxFail "Failed to register GlazeWM startup shortcut" $_.Exception.Message
                $failedCount++
            }
        }
    }

    if ($failedCount -gt 0) {
        return [PSCustomObject]@{
            Status  = "FAIL"
            Message = "$failedCount GlazeWM step(s) failed"
        }
    }

    $finalStatus = if ($installedCount -gt 0) { "OK" } else { "SKIP" }
    return [PSCustomObject]@{
        Status  = $finalStatus
        Message = "$installedCount configured, $skippedCount skipped"
    }
}

Invoke-DevboxGlazewmModule -Config $Config -DryRun:$DryRun
