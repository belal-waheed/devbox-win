# ==============================================================================
# devbox-win :: Module: Keybindings
# Path: modules/keybindings.ps1
# Description: Configures PowerToys, AutoHotkey v2, and startup hotkey scripts.
# Standard: Zero emojis. Checks installed states and startup registrations.
# ==============================================================================

param(
    [Parameter(Mandatory=$true)][System.Collections.IDictionary]$Config,
    [switch]$DryRun
)

Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "..\core\logger.ps1")
. (Join-Path $PSScriptRoot "..\core\state.ps1")
. (Join-Path $PSScriptRoot "..\core\manifest.ps1")

function Test-PackageInstalledFast([string]$PackageId) {
    return Test-DevboxPackageInstalledFast -PackageId $PackageId -CheckCliFallback
}

function Set-StartupShortcut {
    param(
        [string]$ShortcutName,
        [string]$TargetPath,
        [string]$Arguments = "",
        [System.Collections.IDictionary]$Manifest = $null,
        [switch]$DryRun
    )

    $wsh = New-Object -ComObject WScript.Shell
    $startupDir = $wsh.SpecialFolders.Item("Startup")
    $shortcutPath = Join-Path $startupDir "$ShortcutName.lnk"

    if (Test-Path $shortcutPath) {
        try {
            $existing = $wsh.CreateShortcut($shortcutPath)
            if ($existing.TargetPath -eq $TargetPath) {
                Write-DevboxSkip "Startup Shortcut" "$ShortcutName already configured to target '$TargetPath'"
                return "SKIP"
            }
        } catch {
            # Recreate below
        }
    }

    if ($DryRun) {
        Write-DevboxDryRun "Would register startup shortcut: $shortcutPath -> $TargetPath"
        return "OK"
    }

    try {
        $sc = $wsh.CreateShortcut($shortcutPath)
        $sc.TargetPath = $TargetPath
        if ($Arguments) { $sc.Arguments = $Arguments }
        $sc.WorkingDirectory = Split-Path -Parent $TargetPath
        $sc.Save()
        if ($null -ne $Manifest) {
            Add-DevboxManifestShortcut -Manifest $Manifest -Path $shortcutPath
        }
        Write-DevboxOk "Created startup shortcut: $shortcutPath -> $TargetPath"
        return "OK"
    } catch {
        Write-DevboxFail "Failed to create startup shortcut: $shortcutPath" $_.Exception.Message
        return "FAIL"
    }
}

function Invoke-DevboxKeybindingsModule {
    param(
        [System.Collections.IDictionary]$Config,
        [switch]$DryRun
    )

    $keyConfig = if ($Config.Contains("keybindings") -and ($null -ne $Config["keybindings"])) {
        $Config["keybindings"]
    } else {
        $null
    }

    if ($null -eq $keyConfig) {
        Write-DevboxSkip "keybindings" "No keybindings configured"
        return [PSCustomObject]@{
            Status  = "SKIP"
            Message = "No keybindings configured"
        }
    }

    $repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
    $manifest = Load-DevboxManifest
    $installedCount = 0
    $skippedCount   = 0
    $failedCount    = 0

    $powertoysEnabled = if ($keyConfig.Contains("powertoys")) { [bool]$keyConfig["powertoys"] } else { $false }
    $ahkEnabled       = if ($keyConfig.Contains("autohotkey")) { [bool]$keyConfig["autohotkey"] } else { $false }
    $startupEnabled   = if ($keyConfig.Contains("startup_script")) { [bool]$keyConfig["startup_script"] } else { $ahkEnabled }

    # 1. PowerToys
    if ($powertoysEnabled) {
        $ptPkg = "Microsoft.PowerToys"
        $ptInstalled = Test-PackageInstalledFast -PackageId $ptPkg

        if ($ptInstalled) {
            Write-DevboxSkip "PowerToys" "Microsoft.PowerToys is already installed"
            $skippedCount++
        } elseif ($DryRun) {
            Write-DevboxDryRun "Would install $ptPkg via winget"
            $installedCount++
        } else {
            Write-DevboxInfo "Installing PowerToys via winget..."
            try {
                $p = Start-Process -FilePath "winget" `
                    -ArgumentList "install", "--id", $ptPkg, "--exact", "--silent", "--accept-package-agreements", "--accept-source-agreements" `
                    -NoNewWindow -PassThru -Wait
                if ($p.ExitCode -eq 0) {
                    Write-DevboxOk "Installed PowerToys"
                    Add-DevboxManifestPackage -Manifest $manifest -PackageId $ptPkg
                    $installedCount++
                } else {
                    Write-DevboxFail "Failed to install PowerToys (Exit code: $($p.ExitCode))"
                    $failedCount++
                }
            } catch {
                Write-DevboxFail "Error installing PowerToys" $_.Exception.Message
                $failedCount++
            }
        }
    }

    # 2. AutoHotkey v2
    if ($ahkEnabled) {
        $ahkPkg = "AutoHotkey.AutoHotkey"
        $ahkInstalled = (Get-Command "AutoHotkey64.exe" -ErrorAction SilentlyContinue) -or (Test-PackageInstalledFast -PackageId $ahkPkg)

        if ($ahkInstalled) {
            Write-DevboxSkip "AutoHotkey" "AutoHotkey is already installed"
            $skippedCount++
        } elseif ($DryRun) {
            Write-DevboxDryRun "Would install $ahkPkg via winget"
            $installedCount++
        } else {
            Write-DevboxInfo "Installing AutoHotkey v2 via winget..."
            try {
                $p = Start-Process -FilePath "winget" `
                    -ArgumentList "install", "--id", $ahkPkg, "--exact", "--silent", "--accept-package-agreements", "--accept-source-agreements" `
                    -NoNewWindow -PassThru -Wait
                if ($p.ExitCode -eq 0) {
                    Write-DevboxOk "Installed AutoHotkey v2"
                    Add-DevboxManifestPackage -Manifest $manifest -PackageId $ahkPkg
                    $installedCount++
                } else {
                    Write-DevboxFail "Failed to install AutoHotkey (Exit code: $($p.ExitCode))"
                    $failedCount++
                }
            } catch {
                Write-DevboxFail "Error installing AutoHotkey" $_.Exception.Message
                $failedCount++
            }
        }
    }

    # 3. AutoHotkey Startup Link
    if ($startupEnabled) {
        $ahkScript = Join-Path $repoRoot "dotfiles\ahk\hotkeys.ahk"
        if (Test-Path $ahkScript) {
            $scRes = Set-StartupShortcut -ShortcutName "devbox-hotkeys" -TargetPath $ahkScript -Manifest $manifest -DryRun:$DryRun
            if ($scRes -eq "OK") {
                $installedCount++
            } elseif ($scRes -eq "SKIP") {
                $skippedCount++
            } else {
                $failedCount++
            }
        } else {
            Write-DevboxSkip "Startup hotkeys" "dotfiles\ahk\hotkeys.ahk does not exist"
            $skippedCount++
        }
    }

    if ($failedCount -gt 0) {
        return [PSCustomObject]@{
            Status  = "FAIL"
            Message = "$failedCount keybinding configuration(s) failed"
        }
    }

    $finalStatus = if ($installedCount -gt 0) { "OK" } else { "SKIP" }
    return [PSCustomObject]@{
        Status  = $finalStatus
        Message = "$installedCount configured, $skippedCount skipped"
    }
}

Invoke-DevboxKeybindingsModule -Config $Config -DryRun:$DryRun
