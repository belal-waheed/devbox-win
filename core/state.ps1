# ==============================================================================
# devbox-win :: Core State
# Path: core/state.ps1
# Description: Execution state tracking, resume/retry persistence, failure logs.
# Standard: Stores state at ~/.devbox-win/state.json
# ==============================================================================

Set-StrictMode -Version Latest

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
    Set-Content -Path $statePath -Value $json -Encoding utf8
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
