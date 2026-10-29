# ==============================================================================
# devbox-win :: Core State
# Path: core/state.ps1
# Description: Execution state tracking, resume/retry persistence, failure logs.
# Standard: Stores state at ~/.devbox-win/state.json
# ==============================================================================

Set-StrictMode -Version Latest

if (Test-Path (Join-Path $PSScriptRoot "logger.ps1")) {
    . (Join-Path $PSScriptRoot "logger.ps1")
}
if (Test-Path (Join-Path $PSScriptRoot "manifest.ps1")) {
    . (Join-Path $PSScriptRoot "manifest.ps1")
}

function Get-DevboxStateDir {
    $dir = Join-Path $HOME ".devbox-win"
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return $dir
}

function Get-DevboxStatePath {
    return (Join-Path (Get-DevboxStateDir) "state.json")
}

function New-DevboxStateTemplate {
    return [ordered]@{
        schemaVersion    = "1.0.0"
        initializedAt    = (Get-Date -Format "o")
        lastRunAt        = (Get-Date -Format "o")
        completedModules = @()
        failedModules    = [ordered]@{}
        skippedModules   = @()
        executionLog     = @()
        needsReboot      = $false
        rebootModule     = $null
    }
}

function Load-DevboxState {
    $statePath = Get-DevboxStatePath
    if (Test-Path $statePath) {
        try {
            $raw = Get-Content -Path $statePath -Raw -Encoding utf8
            $state = $raw | ConvertFrom-Json -AsHashtable
            if ($null -ne $state) {
                return $state
            }
        } catch {
            # Corrupted state file, initialize fresh
        }
    }
    return New-DevboxStateTemplate
}

function Save-DevboxState {
    param([System.Collections.IDictionary]$State)

    $State["lastRunAt"] = (Get-Date -Format "o")
    $statePath = Get-DevboxStatePath
    $json = $State | ConvertTo-Json -Depth 10
    $tmpPath = "$statePath.tmp.$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
    Set-Content -Path $tmpPath -Value $json -Encoding utf8
    Move-Item -Path $tmpPath -Destination $statePath -Force
}

$global:DevboxInstalledPackageCache = $null

function Get-DevboxInstalledPackageSet {
    param([switch]$ForceRefresh)

    if ($null -ne $global:DevboxInstalledPackageCache -and (-not $ForceRefresh)) {
        return ,$global:DevboxInstalledPackageCache
    }

    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    if (Get-Command "winget" -ErrorAction SilentlyContinue) {
        try {
            $lines = & winget list --accept-source-agreements 2>$null
            if ($lines) {
                foreach ($line in $lines) {
                    $trim = $line.Trim()
                    if ($trim.Length -gt 0) {
                        $tokens = $trim -split '\s{2,}'
                        if ($tokens.Count -ge 2) {
                            $candidateId = $tokens[1].Trim()
                            if ($candidateId -match '^[a-zA-Z0-9_\.-]+$') {
                                [void]$set.Add($candidateId)
                            }
                        }
                    }
                }
            }
        } catch {
            # Graceful fallback on winget errors
        }
    }

    $global:DevboxInstalledPackageCache = $set
    return ,$set
}

function Test-DevboxPackageInstalledFast {
    param(
        [Parameter(Mandatory=$true)][string]$PackageId,
        [switch]$CheckCliFallback
    )

    $set = Get-DevboxInstalledPackageSet
    if ($set -is [System.Collections.Generic.HashSet[string]]) {
        if ($set.Contains($PackageId)) {
            return $true
        }
    } else {
        if ($set -contains $PackageId) {
            return $true
        }
    }

    if ($CheckCliFallback -and (Get-Command "winget" -ErrorAction SilentlyContinue)) {
        try {
            $result = & winget list --id $PackageId --exact --accept-source-agreements 2>$null | Out-String
            if ($result -match [regex]::Escape($PackageId)) {
                if ($set -is [System.Collections.Generic.HashSet[string]]) {
                    [void]$set.Add($PackageId)
                }
                return $true
            }
        } catch { }
    }

    return $false
}

function Get-DevboxCustomInstallLocation {
    param([System.Collections.IDictionary]$Config)

    if ($null -eq $Config) { return "" }
    if ($Config.Contains("paths") -and ($null -ne $Config["paths"])) {
        $p = $Config["paths"]
        if ($p -is [System.Collections.IDictionary] -and $p.Contains("apps") -and ($null -ne $p["apps"])) {
            return [string]$p["apps"]
        }
        if ($p -is [PSCustomObject] -and ($null -ne $p.apps)) {
            return [string]$p.apps
        }
    }
    if ($Config.Contains("install_location") -and ($null -ne $Config["install_location"])) {
        return [string]$Config["install_location"]
    }
    return ""
}

function Install-DevboxWingetPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId,
        [string]$Location = "",
        [int]$TimeoutSeconds = 180,
        [hashtable]$Manifest = $null,
        [switch]$DryRun
    )

    if (Test-DevboxPackageInstalledFast -PackageId $PackageId) {
        if (Get-Command "Write-DevboxSkip" -ErrorAction SilentlyContinue) {
            Write-DevboxSkip $PackageId "Already installed"
        }
        return [PSCustomObject]@{
            Success  = $true
            Skipped  = $true
            DryRun   = [bool]$DryRun
            ExitCode = 0
            TimedOut = $false
            Location = $Location
        }
    }

    if ($DryRun) {
        $locMsg = if (-not [string]::IsNullOrWhiteSpace($Location)) { " (Location: '$Location')" } else { "" }
        if (Get-Command "Write-DevboxOk" -ErrorAction SilentlyContinue) {
            Write-DevboxOk "[DRY-RUN] Would install $PackageId via winget$locMsg"
        } else {
            Write-Host "  [OK] [DRY-RUN] Would install $PackageId via winget$locMsg"
        }
        return [PSCustomObject]@{
            Success  = $true
            Skipped  = $false
            DryRun   = $true
            ExitCode = 0
            TimedOut = $false
            Location = $Location
        }
    }

    $baseArgs = @("install", "--id", $PackageId, "--exact", "--silent", "--accept-package-agreements", "--accept-source-agreements")
    $argsToRun = @($baseArgs)
    $hasCustomLocation = (-not [string]::IsNullOrWhiteSpace($Location))
    if ($hasCustomLocation) {
        $argsToRun += @("--location", $Location)
        if (Get-Command "Write-DevboxInfo" -ErrorAction SilentlyContinue) {
            Write-DevboxInfo "Installing $PackageId via winget (custom location: '$Location')..."
        }
    } else {
        if (Get-Command "Write-DevboxInfo" -ErrorAction SilentlyContinue) {
            Write-DevboxInfo "Installing $PackageId via winget..."
        }
    }

    $timeoutMs = $TimeoutSeconds * 1000

    function Invoke-WingetCli([string[]]$cliArgs) {
        try {
            $p = Start-Process -FilePath "winget" -ArgumentList $cliArgs -NoNewWindow -PassThru
            $exited = $p.WaitForExit($timeoutMs)
            if (-not $exited) {
                try { $p.Kill($true) } catch { }
                return @{ TimedOut = $true; ExitCode = -1 }
            }
            return @{ TimedOut = $false; ExitCode = $p.ExitCode }
        } catch {
            return @{ TimedOut = $false; ExitCode = -1; Error = $_.Exception.Message }
        }
    }

    $execRes = Invoke-WingetCli -cliArgs $argsToRun

    if ($execRes.TimedOut) {
        if (Get-Command "Write-DevboxFail" -ErrorAction SilentlyContinue) {
            Write-DevboxFail "Package $PackageId installation timed out (circuit breaker triggered)"
        }
        return [PSCustomObject]@{
            Success  = $false
            Skipped  = $false
            DryRun   = [bool]$DryRun
            ExitCode = -1
            TimedOut = $true
            Location = $Location
        }
    }

    $exitCode = $execRes.ExitCode

    if (($exitCode -eq -1978335212 -or $exitCode -eq [int]0x8a150014) -and $hasCustomLocation) {
        if (Get-Command "Write-DevboxWarn" -ErrorAction SilentlyContinue) {
            Write-DevboxWarn "Package '$PackageId' does not support custom installation location. Retrying with default location..."
        } else {
            Write-Host "  [WARN] Package '$PackageId' does not support custom installation location. Retrying with default location..."
        }

        $execRes = Invoke-WingetCli -cliArgs $baseArgs
        if ($execRes.TimedOut) {
            if (Get-Command "Write-DevboxFail" -ErrorAction SilentlyContinue) {
                Write-DevboxFail "Package $PackageId installation timed out on retry (circuit breaker triggered)"
            }
            return [PSCustomObject]@{
                Success  = $false
                Skipped  = $false
                DryRun   = [bool]$DryRun
                ExitCode = -1
                TimedOut = $true
                Location = $Location
            }
        }
        $exitCode = $execRes.ExitCode
    }

    if ($exitCode -eq 0) {
        if (Get-Command "Write-DevboxOk" -ErrorAction SilentlyContinue) {
            Write-DevboxOk "Installed: $PackageId"
        }
        if ($null -ne $Manifest -and (Get-Command "Add-DevboxManifestPackage" -ErrorAction SilentlyContinue)) {
            Add-DevboxManifestPackage -Manifest $Manifest -PackageId $PackageId
        }
        if ($null -eq $global:DevboxInstalledPackageCache) {
            Get-DevboxInstalledPackageSet | Out-Null
        }
        if ($null -ne $global:DevboxInstalledPackageCache) {
            $global:DevboxInstalledPackageCache.Add($PackageId) | Out-Null
        }
        return [PSCustomObject]@{
            Success  = $true
            Skipped  = $false
            DryRun   = [bool]$DryRun
            ExitCode = 0
            TimedOut = $false
            Location = $Location
        }
    } elseif ($exitCode -eq -1978335189) {
        if (Get-Command "Write-DevboxSkip" -ErrorAction SilentlyContinue) {
            Write-DevboxSkip $PackageId "Already installed"
        }
        return [PSCustomObject]@{
            Success  = $true
            Skipped  = $true
            DryRun   = [bool]$DryRun
            ExitCode = $exitCode
            TimedOut = $false
            Location = $Location
        }
    } else {
        $detail = if ($execRes.ContainsKey("Error")) { $execRes.Error } else { "" }
        if (Get-Command "Write-DevboxFail" -ErrorAction SilentlyContinue) {
            Write-DevboxFail "Failed to install: $PackageId (Exit code: $exitCode)" $detail
        }
        return [PSCustomObject]@{
            Success  = $false
            Skipped  = $false
            DryRun   = [bool]$DryRun
            ExitCode = $exitCode
            TimedOut = $false
            Location = $Location
        }
    }
}

function Set-DevboxModuleResult {
    param(
        [System.Collections.IDictionary]$State,
        [string]$ModuleName,
        [ValidateSet("OK", "SKIP", "FAIL")][string]$Status,
        [string]$Detail = ""
    )

    $completed = [System.Collections.Generic.List[string]]::new()
    if ($State.Contains("completedModules") -and ($null -ne $State["completedModules"])) {
        foreach ($m in $State["completedModules"]) {
            $completed.Add($m.ToString())
        }
    }

    $skipped = [System.Collections.Generic.List[string]]::new()
    if ($State.Contains("skippedModules") -and ($null -ne $State["skippedModules"])) {
        foreach ($m in $State["skippedModules"]) {
            $skipped.Add($m.ToString())
        }
    }

    $failed = if ($State.Contains("failedModules") -and ($null -ne $State["failedModules"])) {
        $State["failedModules"]
    } else {
        [ordered]@{}
    }

    $history = [System.Collections.Generic.List[object]]::new()
    if ($State.Contains("executionLog") -and ($null -ne $State["executionLog"])) {
        foreach ($entry in $State["executionLog"]) {
            $history.Add($entry)
        }
    }

    # Clean existing references to module
    if ($completed.Contains($ModuleName)) { [void]$completed.Remove($ModuleName) }
    if ($skipped.Contains($ModuleName)) { [void]$skipped.Remove($ModuleName) }
    if ($failed.Contains($ModuleName)) { [void]$failed.Remove($ModuleName) }

    switch ($Status) {
        "OK" {
            $completed.Add($ModuleName)
        }
        "SKIP" {
            $skipped.Add($ModuleName)
        }
        "FAIL" {
            $failed[$ModuleName] = [ordered]@{
                failedAt = (Get-Date -Format "o")
                error    = $Detail
            }
        }
    }

    $history.Add([ordered]@{
        module    = $ModuleName
        status    = $Status
        detail    = $Detail
        timestamp = (Get-Date -Format "o")
    })

    $State["completedModules"] = @($completed)
    $State["skippedModules"]   = @($skipped)
    $State["failedModules"]    = $failed
    $State["executionLog"]     = @($history)

    Save-DevboxState -State $State
}

function Reset-DevboxState {
    $fresh = New-DevboxStateTemplate
    Save-DevboxState -State $fresh
    return $fresh
}

function Set-DevboxRebootRequired {
    param(
        [System.Collections.IDictionary]$State,
        [string]$ModuleName,
        [string]$Reason = "",
        [string]$RepoRoot = "",
        [switch]$DryRun
    )

    $State["needsReboot"]  = $true
    $State["rebootModule"] = $ModuleName
    $State["rebootReason"] = $Reason

    if (-not $DryRun) {
        if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
            $RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
        }
        $enginePath = Join-Path $RepoRoot "core\engine.ps1"
        $runOnceKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
        $cmd = "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File `"$enginePath`" -Resume"

        try {
            if (-not (Test-Path $runOnceKey)) {
                New-Item -Path $runOnceKey -Force | Out-Null
            }
            Set-ItemProperty -Path $runOnceKey -Name "DevboxWinResume" -Value $cmd -Force
        } catch {
            # Non-fatal if registry cannot be updated
        }
    }

    Save-DevboxState -State $State
}

function Clear-DevboxRebootRequired {
    param(
        [System.Collections.IDictionary]$State,
        [switch]$DryRun
    )

    $State["needsReboot"]  = $false
    $State["rebootModule"] = $null
    $State["rebootReason"] = $null

    if (-not $DryRun) {
        $runOnceKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
        try {
            if (Test-Path $runOnceKey) {
                Remove-ItemProperty -Path $runOnceKey -Name "DevboxWinResume" -ErrorAction SilentlyContinue
            }
        } catch {
            # Ignore
        }
    }

    Save-DevboxState -State $State
}

function Test-DevboxRebootRequired {
    param([System.Collections.IDictionary]$State)

    if ($null -eq $State) { return $false }
    if ($State.Contains("needsReboot") -and [bool]$State["needsReboot"]) {
        return $true
    }
    return $false
}
