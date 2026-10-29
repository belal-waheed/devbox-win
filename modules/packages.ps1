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

    foreach ($pkg in $packages) {
        if (-not $pkg) { continue }
        $pkgId = $pkg.ToString().Trim()

        $isInstalled = Test-WingetPackageInstalled -PackageId $pkgId

        if ($isInstalled) {
            Write-DevboxSkip $pkgId "Already installed"
            $skippedCount++
            continue
        }

        if ($DryRun) {
            Write-DevboxDryRun "Would install: $pkgId"
            $installedCount++
            continue
        }

        Write-DevboxInfo "Installing $pkgId via winget..."
        try {
            $process = Start-Process -FilePath "winget" `
                -ArgumentList "install", "--id", $pkgId, "--exact", "--silent", "--accept-package-agreements", "--accept-source-agreements" `
                -NoNewWindow -PassThru

            $exited = $process.WaitForExit(180000)
            if (-not $exited) {
                Write-DevboxWarn "Installation of $pkgId timed out after 180 seconds. Terminating process..."
                try {
                    $process.Kill($true)
                } catch {
                    # Process might have exited between check and kill
                }
                Write-DevboxFail "Package $pkgId installation timed out (circuit breaker triggered)"
                $failedCount++
                continue
            }

            if ($process.ExitCode -eq 0) {
                Write-DevboxOk "Installed: $pkgId"
                Add-DevboxManifestPackage -Manifest $manifest -PackageId $pkgId
                $installedCount++
            } elseif ($process.ExitCode -eq -1978335189) {
                Write-DevboxSkip $pkgId "Already installed"
                $skippedCount++
            } else {
                Write-DevboxFail "Failed to install: $pkgId (Exit code: $($process.ExitCode))"
                $failedCount++
            }
        } catch {
            Write-DevboxFail "Error installing $pkgId" $_.Exception.Message
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
