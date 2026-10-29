# ==============================================================================
# devbox-win :: Core Logger
# Path: core/logger.ps1
# Description: Rich TUI output, status badges, progress tracking, and ANSI styling.
# Standard: Zero emojis. Pure ANSI color formatting and clean Unicode/ASCII badges.
# ==============================================================================

Set-StrictMode -Version Latest

$script:C = @{
    Reset       = "`e[0m"
    Bold        = "`e[1m"
    Dim         = "`e[2m"
    Cyan        = "`e[36m"
    BrightCyan  = "`e[96m"
    Green       = "`e[32m"
    BrightGreen = "`e[92m"
    Yellow      = "`e[33m"
    BrightYellow= "`e[93m"
    Red         = "`e[31m"
    BrightRed   = "`e[91m"
    Magenta     = "`e[35m"
    Gray        = "`e[90m"
    White       = "`e[97m"
}

function Write-DevboxBanner {
    param(
        [string]$Version = "1.0.0-mvp",
        [string]$SubTitle = "Native Windows 11 Developer Machine Provisioner"
    )

    $banner = @"
$($script:C.BrightCyan)$($script:C.Bold)
  ____  _______     ______   _____  __  __        _____ _   _ 
 |  _ \| ____\ \   / / __ ) / _ \ \/ /  \ \      / /_ _| \ | |
 | | | |  _|  \ \ / /|  _ \| | | \  /____\ \ /\ / / | ||  \| |
 | |_| | |___  \ V / | |_) | |_| /  \_____\ V  V /  | || |\  |
 |____/|_____|  \_/  |____/ \___/_/\_\     \_/\_/  |___|_| \_|
$($script:C.Reset)
$($script:C.Gray)==============================================================================$($script:C.Reset)
  $($script:C.Bold)$SubTitle$($script:C.Reset)
  $($script:C.Dim)Version:$($script:C.Reset) $($script:C.BrightGreen)$Version$($script:C.Reset)  $($script:C.Dim)|$($script:C.Reset)  $($script:C.Dim)Host:$($script:C.Reset) $($script:C.White)$($env:COMPUTERNAME)$($script:C.Reset)  $($script:C.Dim)|$($script:C.Reset)  $($script:C.Dim)User:$($script:C.Reset) $($script:C.White)$($env:USERNAME)$($script:C.Reset)
$($script:C.Gray)==============================================================================$($script:C.Reset)
"@
    Write-Host $banner
}

function Write-DevboxSection {
    param([string]$Title)
    $line = "=" * [Math]::Max(4, (78 - $Title.Length - 4))
    Write-Host ""
    Write-Host "$($script:C.BrightCyan)$($script:C.Bold)[== $Title $line]$($script:C.Reset)"
}

function Write-DevboxStep {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Name,
        [string]$Description = ""
    )
    $stepPrefix = "$($script:C.Bold)$($script:C.White)[$Current/$Total]$($script:C.Reset)"
    $moduleTag = "$($script:C.BrightCyan)$($script:C.Bold)$Name$($script:C.Reset)"
    $descText = if ($Description) { " - $($script:C.Dim)$Description$($script:C.Reset)" } else { "" }
    Write-Host ""
    Write-Host "$stepPrefix $moduleTag$descText"
}

function Write-DevboxOk {
    param([string]$Message)
    $badge = "$($script:C.BrightGreen)$($script:C.Bold)[OK]$($script:C.Reset)"
    Write-Host "  $badge $Message"
}

function Write-DevboxSkip {
    param(
        [string]$Message,
        [string]$Reason = ""
    )
    $badge = "$($script:C.Yellow)$($script:C.Bold)[SKIP]$($script:C.Reset)"
    $reasonText = if ($Reason) { " $($script:C.Dim)($Reason)$($script:C.Reset)" } else { "" }
    Write-Host "  $badge $Message$reasonText"
}

function Write-DevboxFail {
    param(
        [string]$Message,
        [string]$ErrorDetail = ""
    )
    $badge = "$($script:C.BrightRed)$($script:C.Bold)[FAIL]$($script:C.Reset)"
    Write-Host "  $badge $Message"
    if ($ErrorDetail) {
        Write-Host "         $($script:C.Red)$ErrorDetail$($script:C.Reset)"
    }
}

function Write-DevboxInfo {
    param([string]$Message)
    $badge = "$($script:C.Cyan)[INFO]$($script:C.Reset)"
    Write-Host "  $badge $Message"
}

function Write-DevboxWarn {
    param([string]$Message)
    $badge = "$($script:C.BrightYellow)$($script:C.Bold)[WARN]$($script:C.Reset)"
    Write-Host "  $badge $Message"
}

function Write-DevboxDryRun {
    param([string]$Message)
    $badge = "$($script:C.Magenta)$($script:C.Bold)[DRY-RUN]$($script:C.Reset)"
    Write-Host "  $badge $Message"
}

function Write-DevboxSync {
    param([string]$Message)
    $badge = "$($script:C.BrightCyan)$($script:C.Bold)[SYNC]$($script:C.Reset)"
    Write-Host "  $badge $Message"
}

function Write-DevboxBackup {
    param([string]$Message)
    $badge = "$($script:C.BrightYellow)$($script:C.Bold)[BACKUP]$($script:C.Reset)"
    Write-Host "  $badge $Message"
}

function Write-DevboxSummary {
    param(
        [array]$Results,
        [timespan]$Duration = [timespan]::Zero
    )
    $succeeded = @($Results | Where-Object { $_.Status -eq "OK" }).Count
    $skipped   = @($Results | Where-Object { $_.Status -eq "SKIP" }).Count
    $failed    = @($Results | Where-Object { $_.Status -eq "FAIL" }).Count
    $total     = $Results.Count

    Write-Host ""
    Write-Host "$($script:C.Gray)==============================================================================$($script:C.Reset)"
    Write-Host "  $($script:C.Bold)EXECUTION SUMMARY$($script:C.Reset)"
    Write-Host "$($script:C.Gray)------------------------------------------------------------------------------$($script:C.Reset)"
    Write-Host "  Total Modules : $total"
    Write-Host "  $($script:C.BrightGreen)[OK]   Succeeded$($script:C.Reset) : $succeeded"
    Write-Host "  $($script:C.Yellow)[SKIP] Skipped$($script:C.Reset)   : $skipped"
    if ($failed -gt 0) {
        Write-Host "  $($script:C.BrightRed)[FAIL] Failed$($script:C.Reset)    : $failed"
    } else {
        Write-Host "  $($script:C.Dim)[FAIL] Failed    : 0$($script:C.Reset)"
    }
    if ($Duration -gt [timespan]::Zero) {
        $formattedDuration = "{0:mm\:ss}" -f $Duration
        Write-Host "  Duration      : $formattedDuration"
    }
    Write-Host "$($script:C.Gray)==============================================================================$($script:C.Reset)"

    if ($failed -gt 0) {
        Write-Host ""
        Write-Host "  $($script:C.BrightYellow)To retry failed modules, run:$($script:C.Reset)"
        Write-Host "  $($script:C.White)pwsh -NoProfile -File core/engine.ps1 -Retry$($script:C.Reset)"
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "  $($script:C.BrightGreen)$($script:C.Bold)All modules processed successfully.$($script:C.Reset)"
        Write-Host "  $($script:C.Dim)Restart Windows Terminal or reboot to ensure all environment changes take effect.$($script:C.Reset)"
        Write-Host ""
    }
}
