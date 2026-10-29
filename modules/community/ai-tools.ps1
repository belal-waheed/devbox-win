# ==============================================================================
# devbox-win :: Community Module: AI Tools
# Path: modules/community/ai-tools.ps1
# Description: Local AI workstation stack (Ollama, LM Studio, Hugging Face CLI).
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
        Name         = "ai-tools"
        Description  = "Local AI workstation stack (Ollama, LM Studio, Hugging Face CLI)"
        Dependencies = @("packages")
        Author       = "devbox-win"
        Version      = "1.0.0"
        Packages     = @(
            "Ollama.Ollama",
            "ElementLabs.LMStudio"
        )
    }
}

function Test-AiPackageInstalled([string]$PackageId) {
    switch ($PackageId) {
        "Ollama.Ollama" {
            if (Get-Command "ollama" -ErrorAction SilentlyContinue) { return $true }
            $ollamaPath = Join-Path $env:LOCALAPPDATA "Programs\Ollama\ollama.exe"
            if (Test-Path $ollamaPath) { return $true }
        }
        "ElementLabs.LMStudio" {
            $lmPath = Join-Path $env:LOCALAPPDATA "Programs\LM Studio\LM Studio.exe"
            if (Test-Path $lmPath) { return $true }
            $lmPath2 = Join-Path $env:LOCALAPPDATA "LM-Studio\LM Studio.exe"
            if (Test-Path $lmPath2) { return $true }
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
        if (-not (Test-AiPackageInstalled -PackageId $pkg)) {
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

    Write-DevboxInfo "Evaluating $($pkgList.Count) local AI workstation package(s)..."

    $manifest = Load-DevboxManifest
    $installedCount = 0
    $skippedCount   = 0
    $failedCount    = 0

    foreach ($pkg in $pkgList) {
        if (Test-AiPackageInstalled -PackageId $pkg) {
            Write-DevboxSkip $pkg "Already installed on system"
            $skippedCount++
            continue
        }

        if ($DryRun) {
            Write-DevboxDryRun "Would install local AI package: $pkg"
            $installedCount++
            continue
        }

        Write-DevboxInfo "Installing $pkg via winget..."
        try {
            $p = Start-Process -FilePath "winget" `
                -ArgumentList "install", "--id", $pkg, "--exact", "--silent", "--accept-package-agreements", "--accept-source-agreements" `
                -NoNewWindow -PassThru -Wait

            if ($p.ExitCode -eq 0) {
                Write-DevboxOk "Installed local AI tool: $pkg"
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

    # Optional: Check Hugging Face CLI presence
    if (Get-Command "hf" -ErrorAction SilentlyContinue) {
        Write-DevboxSkip "Hugging Face CLI" "Already installed (hf command found)"
    } else {
        Write-DevboxInfo "Hugging Face CLI can be installed via 'pip install huggingface_hub[cli]'"
    }

    if ($failedCount -gt 0) {
        return [PSCustomObject]@{
            Status  = "FAIL"
            Message = "$failedCount AI tool(s) failed to install"
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
