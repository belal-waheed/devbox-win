# ==============================================================================
# devbox-win :: Module: Fonts
# Path: modules/fonts.ps1
# Description: Idempotent Nerd Font installation and registration.
# Standard: Zero emojis. Checks Windows font registry and winget inventory.
# ==============================================================================

param(
    [Parameter(Mandatory=$true)][System.Collections.IDictionary]$Config,
    [switch]$DryRun
)

Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "..\core\logger.ps1")
. (Join-Path $PSScriptRoot "..\core\manifest.ps1")

$script:FontMap = [ordered]@{
    "JetBrainsMono"   = "DEVCOM.JetBrainsMonoNerdFont"
    "JetBrains Mono"  = "DEVCOM.JetBrainsMonoNerdFont"
    "CascadiaCode"    = "Microsoft.CascadiaCode"
    "Cascadia Code"   = "Microsoft.CascadiaCode"
    "FiraCode"        = "DEVCOM.FiraCodeNerdFont"
}

function Test-FontInstalled {
    param([string]$FontName)

    # Check Windows font registry (HKLM and HKCU)
    $hklm = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -ErrorAction SilentlyContinue
    $hkcu = Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -ErrorAction SilentlyContinue

    $installedNames = @()
    if ($hklm) { $installedNames += $hklm.PSObject.Properties.Name }
    if ($hkcu) { $installedNames += $hkcu.PSObject.Properties.Name }

    $cleanTarget = ($FontName -replace '\s+', '').ToLower()
    foreach ($fn in $installedNames) {
        $cleanInstalled = ($fn -replace '\s+', '').ToLower()
        if ($cleanInstalled -match $cleanTarget) {
            return $true
        }
    }

    # Also check user font directory
    $userFontsDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    if (Test-Path $userFontsDir) {
        $matchingFiles = @(Get-ChildItem -Path $userFontsDir -Filter "*$FontName*" -ErrorAction SilentlyContinue)
        if ($matchingFiles.Count -gt 0) {
            return $true
        }
    }

    return $false
}

function Invoke-DevboxFontsModule {
    param(
        [System.Collections.IDictionary]$Config,
        [switch]$DryRun
    )

    $rawFonts = if ($Config.Contains("fonts") -and ($null -ne $Config["fonts"])) {
        $Config["fonts"]
    } else {
        @("JetBrainsMono")
    }

    $fonts = [System.Collections.Generic.List[string]]::new()
    if ($rawFonts -is [System.Collections.IEnumerable] -and -not ($rawFonts -is [string])) {
        foreach ($f in $rawFonts) {
            if ($f) { $fonts.Add($f.ToString()) }
        }
    } elseif ($rawFonts) {
        $fonts.Add($rawFonts.ToString())
    }

    if ($fonts.Count -eq 0) {
        Write-DevboxSkip "fonts" "No fonts configured"
        return [PSCustomObject]@{
            Status  = "SKIP"
            Message = "No fonts configured"
        }
    }

    $installedCount = 0
    $skippedCount   = 0
    $failedCount    = 0
    $manifest       = Load-DevboxManifest

    Write-DevboxInfo "Evaluating $($fonts.Count) font(s)..."

    foreach ($font in $fonts) {
        if (-not $font) { continue }
        $fontName = $font.Trim()

        if (Test-FontInstalled -FontName $fontName) {
            Write-DevboxSkip $fontName "Already registered in Windows fonts"
            $skippedCount++
            continue
        }

        # Resolve winget ID
        $wingetId = if ($script:FontMap.Contains($fontName)) {
            $script:FontMap[$fontName]
        } else {
            $fontName
        }

        if ($DryRun) {
            Write-DevboxDryRun "Would install font: $fontName (winget ID: $wingetId)"
            $installedCount++
            continue
        }

        Write-DevboxInfo "Installing font $fontName ($wingetId) via winget..."
        try {
            $proc = Start-Process -FilePath "winget" `
                -ArgumentList "install", "--id", $wingetId, "--exact", "--silent", "--accept-package-agreements", "--accept-source-agreements" `
                -NoNewWindow -PassThru -Wait

            if ($proc.ExitCode -eq 0) {
                Write-DevboxOk "Installed font: $fontName"
                Add-DevboxManifestPackage -Manifest $manifest -PackageId $wingetId
                $installedCount++
            } else {
                Write-DevboxWarn "Winget install exited with code $($proc.ExitCode). Verifying font registration..."
                if (Test-FontInstalled -FontName $fontName) {
                    Write-DevboxOk "Font detected in system: $fontName"
                    $installedCount++
                } else {
                    Write-DevboxFail "Could not install font $fontName" "Exit code: $($proc.ExitCode)"
                    $failedCount++
                }
            }
        } catch {
            Write-DevboxFail "Error installing font $fontName" $_.Exception.Message
            $failedCount++
        }
    }

    if ($failedCount -gt 0) {
        return [PSCustomObject]@{
            Status  = "FAIL"
            Message = "$failedCount font(s) failed to install"
        }
    }

    $status = if ($installedCount -gt 0) { "OK" } else { "SKIP" }
    return [PSCustomObject]@{
        Status  = $status
        Message = "$installedCount installed, $skippedCount skipped"
    }
}

Invoke-DevboxFontsModule -Config $Config -DryRun:$DryRun
