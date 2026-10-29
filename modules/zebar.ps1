# ==============================================================================
# devbox-win :: Module: Zebar
# Path: modules/zebar.ps1
# Description: Idempotent Zebar status bar installation & configuration.
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

function Find-ZebarExecutable {
    $cmd = Get-Command "zebar" -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\zebar\zebar.exe"),
        "C:\Program Files\zebar\zebar.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    return $null
}

function Invoke-DevboxZebarModule {
    param(
        [System.Collections.IDictionary]$Config,
        [switch]$DryRun
    )

    $zebarConfig = if ($Config.Contains("zebar") -and ($null -ne $Config["zebar"])) {
        $Config["zebar"]
    } else {
        @{}
    }

    $shouldInstall = if ($zebarConfig.Contains("install")) { [bool]$zebarConfig["install"] } else { $true }
    $autostart     = if ($zebarConfig.Contains("autostart")) { [bool]$zebarConfig["autostart"] } else { $true }

    $repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
    $manifest = Load-DevboxManifest
    $installedCount = 0
    $skippedCount   = 0
    $failedCount    = 0

    $pkgId = "glzr-io.zebar"
    $exePath = Find-ZebarExecutable

    # 1. Package Installation
    if ($shouldInstall) {
        if ($exePath) {
            Write-DevboxSkip "Zebar" "Zebar executable already present at '$exePath'"
            $skippedCount++
        } else {
            $installLoc = Get-DevboxCustomInstallLocation -Config $Config
            $res = Install-DevboxWingetPackage -PackageId $pkgId -Location $installLoc -Manifest $manifest -DryRun:$DryRun
            if ($res.Skipped) {
                $skippedCount++
            } elseif ($res.Success) {
                $installedCount++
                $exePath = Find-ZebarExecutable
            } else {
                $failedCount++
            }
        }
    }

    # 2. Config & Theme Packs Verification
    $userConfigDir = Join-Path $HOME ".glzr\zebar"
    if (-not (Test-Path $userConfigDir) -and -not $DryRun) {
        New-Item -ItemType Directory -Path $userConfigDir -Force | Out-Null
    }

    # 2a. Zebar Settings Symlink (Zebar v3+)
    $settingsSrc = Join-Path $repoRoot "dotfiles\zebar\settings.json"
    $settingsDst = Join-Path $userConfigDir "settings.json"
    $legacySrc   = Join-Path $repoRoot "dotfiles\zebar\config.yaml"
    $legacyDst   = Join-Path $userConfigDir "config.yaml"

    if (Test-Path $settingsSrc) {
        if ($DryRun) {
            Write-DevboxDryRun "Would link Zebar settings: $settingsSrc -> $settingsDst"
            $installedCount++
        } else {
            $symRes = New-DevboxSymlink -Source $settingsSrc -Destination $settingsDst
            if ($symRes.Status -eq "OK") {
                Write-DevboxOk "Configured Zebar settings symlink: $settingsDst"
                Add-DevboxManifestSymlink -Manifest $manifest -Destination $settingsDst -Source $settingsSrc -BackupPath $symRes.BackupPath
                $installedCount++
            } elseif ($symRes.Status -eq "SKIP") {
                Write-DevboxSkip "Zebar Settings" $symRes.Message
                $skippedCount++
            } else {
                Write-DevboxFail "Failed to link Zebar settings" $symRes.Message
                $failedCount++
            }
        }
    } elseif (Test-Path $legacySrc) {
        if ($DryRun) {
            Write-DevboxDryRun "Would link legacy Zebar config: $legacySrc -> $legacyDst"
            $installedCount++
        } else {
            $symRes = New-DevboxSymlink -Source $legacySrc -Destination $legacyDst
            if ($symRes.Status -eq "OK") {
                Write-DevboxOk "Configured legacy Zebar config symlink: $legacyDst"
                Add-DevboxManifestSymlink -Manifest $manifest -Destination $legacyDst -Source $legacySrc -BackupPath $symRes.BackupPath
                $installedCount++
            } elseif ($symRes.Status -eq "SKIP") {
                Write-DevboxSkip "Zebar Config" $symRes.Message
                $skippedCount++
            } else {
                Write-DevboxFail "Failed to link legacy Zebar config" $symRes.Message
                $failedCount++
            }
        }
    }

    # 2b. Zebar Theme Packs Symlinks (e.g. packs/nord)
    $sourcePacksDir = Join-Path $repoRoot "dotfiles\zebar\packs"
    $userPacksDir   = Join-Path $userConfigDir "packs"

    if (Test-Path $sourcePacksDir) {
        if (-not (Test-Path $userPacksDir) -and -not $DryRun) {
            New-Item -ItemType Directory -Path $userPacksDir -Force | Out-Null
        }

        $packItems = Get-ChildItem -Path $sourcePacksDir -Directory -ErrorAction SilentlyContinue
        foreach ($pack in $packItems) {
            $destPack = Join-Path $userPacksDir $pack.Name
            if ($DryRun) {
                Write-DevboxDryRun "Would link Zebar Pack ($($pack.Name)): $($pack.FullName) -> $destPack"
                $installedCount++
            } else {
                $packRes = New-DevboxSymlink -Source $pack.FullName -Destination $destPack
                if ($packRes.Status -eq "OK") {
                    Write-DevboxOk "Configured Zebar Pack ($($pack.Name)) symlink: $destPack"
                    Add-DevboxManifestSymlink -Manifest $manifest -Destination $destPack -Source $pack.FullName -BackupPath $packRes.BackupPath
                    $installedCount++
                } elseif ($packRes.Status -eq "SKIP") {
                    Write-DevboxSkip "Zebar Pack ($($pack.Name))" $packRes.Message
                    $skippedCount++
                } else {
                    Write-DevboxFail "Failed to link Zebar Pack ($($pack.Name))" $packRes.Message
                    $failedCount++
                }
            }
        }
    }

    # 3. Startup Shortcut
    if ($autostart) {
        $wsh = New-Object -ComObject WScript.Shell
        $startupDir = $wsh.SpecialFolders.Item("Startup")
        $shortcutPath = Join-Path $startupDir "Zebar.lnk"

        $targetToLaunch = if ($exePath) { $exePath } else { "zebar.exe" }

        if (Test-Path $shortcutPath) {
            Write-DevboxSkip "Zebar Startup" "Startup shortcut already present at '$shortcutPath'"
            $skippedCount++
        } elseif ($DryRun) {
            Write-DevboxDryRun "Would create startup shortcut for Zebar: $shortcutPath -> $targetToLaunch"
            $installedCount++
        } else {
            try {
                $sc = $wsh.CreateShortcut($shortcutPath)
                $sc.TargetPath = $targetToLaunch
                if ($exePath) { $sc.WorkingDirectory = Split-Path -Parent $exePath }
                $sc.Save()
                Add-DevboxManifestShortcut -Manifest $manifest -Path $shortcutPath
                Write-DevboxOk "Created Zebar startup shortcut at: $shortcutPath"
                $installedCount++
            } catch {
                Write-DevboxFail "Failed to register Zebar startup shortcut" $_.Exception.Message
                $failedCount++
            }
        }
    }

    if ($failedCount -gt 0) {
        return [PSCustomObject]@{
            Status  = "FAIL"
            Message = "$failedCount Zebar step(s) failed"
        }
    }

    $finalStatus = if ($installedCount -gt 0) { "OK" } else { "SKIP" }
    return [PSCustomObject]@{
        Status  = $finalStatus
        Message = "$installedCount configured, $skippedCount skipped"
    }
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -notmatch '^\.') {
    Invoke-DevboxZebarModule -Config $Config -DryRun:$DryRun
}
