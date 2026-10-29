# ==============================================================================
# devbox-win :: Community Module: Gaming
# Path: modules/community/gaming.ps1
# Description: Optional gaming & streaming suite for developer workstations.
# Standard: Zero emojis. Pure ANSI status badges and manifest tracking.
# ==============================================================================

[CmdletBinding()]
param(
    [System.Collections.IDictionary]$Config = @{},
    [switch]$DryRun
)

Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "..\..\core\logger.ps1")
. (Join-Path $PSScriptRoot "..\..\core\manifest.ps1")

function Get-ModuleMetadata {
    return [ordered]@{
        Name         = "gaming"
        Description  = "Gaming & streaming toolchain (Steam, OBS Studio, Discord)"
        Dependencies = @("packages")
        Author       = "devbox-win"
        Version      = "1.0.0"
        Packages     = @(
            "Valve.Steam",
            "OBSProject.OBSStudio",
            "Discord.Discord"
        )
    }
}

function Test-GamingPackageInstalled([string]$PackageId) {
    switch ($PackageId) {
        "Valve.Steam" {
            $steamReg = @(
                "HKCU:\Software\Valve\Steam",
                "HKLM:\SOFTWARE\Valve\Steam",
                "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam"
            )
            foreach ($r in $steamReg) {
                if (Test-Path $r) { return $true }
            }
        }
        "Discord.Discord" {
            $discordPath = Join-Path $env:LOCALAPPDATA "Discord\Update.exe"
            if (Test-Path $discordPath) { return $true }
        }
        "OBSProject.OBSStudio" {
            $obsCandidates = @(
                "C:\Program Files\obs-studio\bin\64bit\obs64.exe",
                "C:\Program Files (x86)\obs-studio\bin\32bit\obs32.exe"
            )
            foreach ($c in $obsCandidates) {
                if (Test-Path $c) { return $true }
            }
        }
    }

    try {
        $result = & winget list --id $PackageId --exact --accept-source-agreements 2>$null | Out-String
        if ($result -match [regex]::Escape($PackageId)) {
            return $true
        }
    } catch {
        # Fall through
    }

    return $false
}

function Test-TargetState {
    param([System.Collections.IDictionary]$Config = @{})

    $meta = Get-ModuleMetadata
    foreach ($pkg in $meta.Packages) {
        if (-not (Test-GamingPackageInstalled -PackageId $pkg)) {
            return $false
        }
    }
    return $true
}

function Invoke-Module {
    param(
        [Parameter(Mandatory=$true)][System.Collections.IDictionary]$Config,
        [switch]$DryRun
    )

    $meta = Get-ModuleMetadata
    $pkgList = $meta.Packages

    Write-DevboxInfo "Evaluating $($pkgList.Count) gaming and streaming package(s)..."

    $manifest = Load-DevboxManifest
    $installedCount = 0
    $skippedCount   = 0
    $failedCount    = 0

    foreach ($pkg in $pkgList) {
        if (Test-GamingPackageInstalled -PackageId $pkg) {
            Write-DevboxSkip $pkg "Already installed on system"
            $skippedCount++
            continue
        }

        if ($DryRun) {
            Write-DevboxDryRun "Would install gaming package: $pkg"
            $installedCount++
            continue
        }

        Write-DevboxInfo "Installing $pkg via winget..."
        try {
            $p = Start-Process -FilePath "winget" `
                -ArgumentList "install", "--id", $pkg, "--exact", "--silent", "--accept-package-agreements", "--accept-source-agreements" `
                -NoNewWindow -PassThru -Wait

            if ($p.ExitCode -eq 0) {
                Write-DevboxOk "Installed gaming tool: $pkg"
                Add-DevboxManifestPackage -Manifest $manifest -PackageId $pkg
                $installedCount++
            } elseif ($p.ExitCode -eq -1978335189) {
                Write-DevboxSkip $pkg "Already installed"
                $skippedCount++
            } else {
                Write-DevboxFail "Failed to install $pkg (Exit code: $($p.ExitCode))"
                $failedCount++
            }
        } catch {
            Write-DevboxFail "Error installing $pkg" $_.Exception.Message
            $failedCount++
        }
    }

    if ($failedCount -gt 0) {
        return [PSCustomObject]@{
            Status  = "FAIL"
            Message = "$failedCount gaming package(s) failed"
        }
    }

    $finalStatus = if ($installedCount -gt 0) { "OK" } else { "SKIP" }
    return [PSCustomObject]@{
        Status  = $finalStatus
        Message = "$installedCount installed, $skippedCount skipped"
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Module -Config $Config -DryRun:$DryRun
}
