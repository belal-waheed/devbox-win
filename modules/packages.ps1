# ==============================================================================
# devbox-win :: Module: Packages
# Path: modules/packages.ps1
# Description: Idempotent winget package installation.
# Standard: Zero emojis. Checks installed state prior to triggering installs.
# ==============================================================================

param(
    [Parameter(Mandatory=$true)][System.Collections.IDictionary]$Config,
    [switch]$DryRun
)

Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "..\core\logger.ps1")
. (Join-Path $PSScriptRoot "..\core\state.ps1")
. (Join-Path $PSScriptRoot "..\core\manifest.ps1")

# Curated Package Catalog
$script:PackageCatalog = @(
    "Microsoft.VisualStudioCode",
    "Zed.Zed",
    "Git.Git",
    "GitHub.cli",
    "Microsoft.WindowsTerminal",
    "Starship.Starship",
    "DEVCOM.JetBrainsMonoNerdFont",
    "Docker.DockerDesktop",
    "PostgreSQL.PostgreSQL",
    "Redis.Redis",
    "glzr-io.glazewm",
    "glzr-io.zebar",
    "AutoHotkey.AutoHotkey",
    "Microsoft.PowerToys",
    "7zip.7zip",
    "Google.Chrome"
)

function Test-WingetPackageInstalled {
    param([string]$PackageId)
    return Test-DevboxPackageInstalledFast -PackageId $PackageId -CheckCliFallback
}

function Invoke-DevboxPackagesModule {
    param(
        [System.Collections.IDictionary]$Config,
        [switch]$DryRun
    )

    $packages = if ($Config.Contains("packages") -and ($null -ne $Config["packages"])) {
        @($Config["packages"])
    } else {
        @()
    }

    if ($packages.Count -eq 0) {
        Write-DevboxSkip "packages" "No packages specified in configuration"
        return [PSCustomObject]@{
            Status  = "SKIP"
            Message = "No packages configured"
        }
    }

    $installedCount = 0
    $skippedCount   = 0
    $failedCount    = 0
    $manifest       = Load-DevboxManifest

    Write-DevboxInfo "Evaluating $($packages.Count) winget packages..."

    # Pre-populate installed set via session-wide cache for instant batch lookup
    $installedSet = Get-DevboxInstalledPackageSet

    $installLoc = Get-DevboxCustomInstallLocation -Config $Config

    foreach ($pkg in $packages) {
        if (-not $pkg) { continue }
        $pkgId = $pkg.ToString().Trim()

        $result = Install-DevboxWingetPackage -PackageId $pkgId -Location $installLoc -Manifest $manifest -DryRun:$DryRun
        if ($result.Skipped) {
            $skippedCount++
        } elseif ($result.Success) {
            $installedCount++
        } else {
            $failedCount++
        }
    }

    if ($failedCount -gt 0) {
        return [PSCustomObject]@{
            Status  = "FAIL"
            Message = "$failedCount package(s) failed to install"
        }
    }

    $summaryStatus = if ($installedCount -gt 0) { "OK" } else { "SKIP" }
    return [PSCustomObject]@{
        Status  = $summaryStatus
        Message = "$installedCount installed, $skippedCount skipped"
    }
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -notmatch '^\.') {
    Invoke-DevboxPackagesModule -Config $Config -DryRun:$DryRun
}
