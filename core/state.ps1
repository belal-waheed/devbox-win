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

function Optimize-DevboxWingetNetwork {
    [CmdletBinding()]
    param(
        [string]$SettingsPath = ""
    )

    try {
        if ([string]::IsNullOrWhiteSpace($SettingsPath)) {
            $localApp = $env:LOCALAPPDATA
            if ([string]::IsNullOrWhiteSpace($localApp)) {
                $localApp = [System.IO.Path]::Combine($HOME, "AppData\Local")
            }
            $targetDir = [System.IO.Path]::Combine($localApp, "Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState")
            $SettingsPath = [System.IO.Path]::Combine($targetDir, "settings.json")
        } else {
            $targetDir = [System.IO.Path]::GetDirectoryName($SettingsPath)
        }

        if (-not [string]::IsNullOrWhiteSpace($targetDir) -and -not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }

        $settings = [ordered]@{}
        if (Test-Path $SettingsPath) {
            try {
                $raw = Get-Content -Path $SettingsPath -Raw -Encoding utf8
                if (-not [string]::IsNullOrWhiteSpace($raw)) {
                    $parsed = $raw | ConvertFrom-Json -AsHashtable
                    if ($parsed -is [System.Collections.IDictionary]) {
                        foreach ($k in $parsed.Keys) {
                            $settings[$k] = $parsed[$k]
                        }
                    }
                }
            } catch {
                $settings = [ordered]@{}
            }
        }

        $needsWrite = $true
        if ($settings.Contains("network")) {
            $existingNet = $settings["network"]
            if ($existingNet -is [System.Collections.IDictionary] -and $existingNet.Contains("downloader") -and $existingNet["downloader"] -eq "wininet") {
                $needsWrite = $false
            }
        }

        if ($needsWrite) {
            $netMap = [ordered]@{}
            if ($settings.Contains("network") -and ($settings["network"] -is [System.Collections.IDictionary])) {
                foreach ($k in $settings["network"].Keys) {
                    $netMap[$k] = $settings["network"][$k]
                }
            }
            $netMap["downloader"] = "wininet"
            $settings["network"] = $netMap

            $json = $settings | ConvertTo-Json -Depth 10
            Set-Content -Path $SettingsPath -Value $json -Encoding utf8
        }
        return $true
    } catch {
        return $false
    }
}

$global:DevboxInstalledPackageCache = $null

function Initialize-DevboxPackageCache {
    [CmdletBinding()]
    param([switch]$ForceRefresh)

    Optimize-DevboxWingetNetwork | Out-Null
    return Get-DevboxInstalledPackageSet -ForceRefresh:$ForceRefresh
}

function Get-DevboxInstalledPackageSet {
    param([switch]$ForceRefresh)

    Optimize-DevboxWingetNetwork | Out-Null

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

function Test-DevboxWingetPackageInstalled {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$PackageId,
        [switch]$CheckCliFallback
    )

    # Font registry fallback check: recognize installed fonts even if winget didn't record them
    $fontCandidate = $null
    $fontMapping = @{
        "DEVCOM.JetBrainsMonoNerdFont" = "JetBrainsMono"
        "DEVCOM.FiraCodeNerdFont"       = "FiraCode"
        "Microsoft.CascadiaCode"        = "CascadiaCode"
    }

    if ($fontMapping.ContainsKey($PackageId)) {
        $fontCandidate = $fontMapping[$PackageId]
    } elseif ($PackageId -match 'DEVCOM\.(.+?)NerdFont') {
        $fontCandidate = $Matches[1]
    }

    if (-not [string]::IsNullOrWhiteSpace($fontCandidate)) {
        $hklm = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -ErrorAction SilentlyContinue
        $hkcu = Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -ErrorAction SilentlyContinue

        $fontNames = @()
        if ($hklm) { $fontNames += $hklm.PSObject.Properties.Name }
        if ($hkcu) { $fontNames += $hkcu.PSObject.Properties.Name }

        $cleanTarget = ($fontCandidate -replace '\s+', '').ToLower()
        foreach ($fn in $fontNames) {
            $cleanInstalled = ($fn -replace '\s+', '').ToLower()
            if ($cleanInstalled -match $cleanTarget) {
                return $true
            }
        }

        # Check local appdata fonts directory
        $localApp = $env:LOCALAPPDATA
        if (-not [string]::IsNullOrWhiteSpace($localApp)) {
            $userFontsDir = Join-Path $localApp "Microsoft\Windows\Fonts"
            if (Test-Path $userFontsDir) {
                $matching = @(Get-ChildItem -Path $userFontsDir -Filter "*$fontCandidate*" -ErrorAction SilentlyContinue)
                if ($matching.Count -gt 0) {
                    return $true
                }
            }
        }
    }

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

function Test-DevboxPackageInstalledFast {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$PackageId,
        [switch]$CheckCliFallback
    )
    return Test-DevboxWingetPackageInstalled -PackageId $PackageId -CheckCliFallback:$CheckCliFallback
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
        [int]$TimeoutSeconds = 600,
        [hashtable]$Manifest = $null,
        [switch]$DryRun
    )

    Optimize-DevboxWingetNetwork | Out-Null

    if (Test-DevboxWingetPackageInstalled -PackageId $PackageId) {
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

    $isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $hasCustomLocation = (-not [string]::IsNullOrWhiteSpace($Location))

    $baseArgs = @("install", "--id", $PackageId, "--exact", "--silent", "--accept-package-agreements", "--accept-source-agreements")
    $argsToRun = @($baseArgs)
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

    # If non-elevated, attempt user scope first to avoid machine-wide MSI elevation blocks
    $attemptedUserScope = $false
    if (-not $isElevated) {
        $argsToRun += @("--scope", "user")
        $attemptedUserScope = $true
    }

    $timeoutMs = $TimeoutSeconds * 1000

    function Invoke-WingetCli([string[]]$cliArgs) {
        try {
            $p = Start-Process -FilePath "winget" -ArgumentList $cliArgs -NoNewWindow -PassThru -ErrorAction Stop
            if ($null -eq $p) {
                return @{ TimedOut = $false; ExitCode = -1; Error = "Failed to start winget process" }
            }
            $exited = $p.WaitForExit($timeoutMs)
            if (-not $exited) {
                try { $p.Kill($true) } catch { }
                return @{ TimedOut = $true; ExitCode = -1 }
            }
            $rawCode = $p.ExitCode
            $finalCode = if ($null -ne $rawCode) { [int]$rawCode } else { 0 }
            return @{ TimedOut = $false; ExitCode = $finalCode }
        } catch {
            return @{ TimedOut = $false; ExitCode = -1; Error = $_.Exception.Message }
        }
    }

    $execRes = Invoke-WingetCli -cliArgs $argsToRun

    if ($execRes.TimedOut) {
        if (Get-Command "Write-DevboxWarn" -ErrorAction SilentlyContinue) {
            Write-DevboxWarn "Package $PackageId installation timed out (circuit breaker triggered). Skipped to prevent pipeline abort."
        } else {
            Write-Host "  [WARN] Package $PackageId installation timed out (circuit breaker triggered). Skipped to prevent pipeline abort."
        }
        return [PSCustomObject]@{
            Success  = $false
            Skipped  = $true
            DryRun   = [bool]$DryRun
            ExitCode = -1
            TimedOut = $true
            Location = $Location
        }
    }

    $exitCode = $execRes.ExitCode

    # If user-scope was attempted but failed because scope is unsupported, retry without --scope user
    if ($attemptedUserScope -and ($exitCode -eq -1978335178 -or $exitCode -eq [int]0x8a150036 -or $exitCode -eq -1978335212 -or $exitCode -eq -1978335216 -or $exitCode -eq [int]0x8a150010)) {
        if (Get-Command "Write-DevboxWarn" -ErrorAction SilentlyContinue) {
            Write-DevboxWarn "Package '$PackageId' does not support user scope. Attempting default scope..."
        }
        $retryArgs = @($baseArgs)
        if ($hasCustomLocation) { $retryArgs += @("--location", $Location) }
        $execRes = Invoke-WingetCli -cliArgs $retryArgs
        if ($execRes.TimedOut) {
            if (Get-Command "Write-DevboxWarn" -ErrorAction SilentlyContinue) {
                Write-DevboxWarn "Package $PackageId installation timed out on retry (circuit breaker triggered). Skipped to prevent pipeline abort."
            }
            return [PSCustomObject]@{
                Success  = $false
                Skipped  = $true
                DryRun   = [bool]$DryRun
                ExitCode = -1
                TimedOut = $true
                Location = $Location
            }
        }
        $exitCode = $execRes.ExitCode
    }

    # If custom location was rejected, retry without custom location
    if (($exitCode -eq -1978335212 -or $exitCode -eq [int]0x8a150014) -and $hasCustomLocation) {
        if (Get-Command "Write-DevboxWarn" -ErrorAction SilentlyContinue) {
            Write-DevboxWarn "Package '$PackageId' does not support custom installation location. Retrying with default location..."
        } else {
            Write-Host "  [WARN] Package '$PackageId' does not support custom installation location. Retrying with default location..."
        }

        $retryBaseArgs = @($baseArgs)
        if ($attemptedUserScope) { $retryBaseArgs += @("--scope", "user") }
        $execRes = Invoke-WingetCli -cliArgs $retryBaseArgs
        if ($execRes.TimedOut) {
            if (Get-Command "Write-DevboxWarn" -ErrorAction SilentlyContinue) {
                Write-DevboxWarn "Package $PackageId installation timed out on retry (circuit breaker triggered). Skipped to prevent pipeline abort."
            }
            return [PSCustomObject]@{
                Success  = $false
                Skipped  = $true
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
    } elseif ($exitCode -eq 1602 -or $exitCode -eq -2147023294 -or $exitCode -eq -1978335181 -or (-not $isElevated -and ($exitCode -eq 5 -or $exitCode -eq -2147024891))) {
        if (Get-Command "Write-DevboxWarn" -ErrorAction SilentlyContinue) {
            Write-DevboxWarn "Package $PackageId was cancelled or requires elevation. Skipped to prevent pipeline abort."
        } else {
            Write-Host "  [WARN] Package $PackageId was cancelled or requires elevation. Skipped to prevent pipeline abort."
        }
        return [PSCustomObject]@{
            Success  = $false
            Skipped  = $true
            DryRun   = [bool]$DryRun
            ExitCode = $exitCode
            TimedOut = $false
            Location = $Location
        }
    } else {
        $detail = if ($execRes.ContainsKey("Error")) { $execRes.Error } else { "" }
        if (Get-Command "Write-DevboxWarn" -ErrorAction SilentlyContinue) {
            Write-DevboxWarn "Package $PackageId was cancelled or requires elevation. Skipped to prevent pipeline abort."
        } else {
            Write-Host "  [WARN] Package $PackageId was cancelled or requires elevation. Skipped to prevent pipeline abort."
        }
        return [PSCustomObject]@{
            Success  = $false
            Skipped  = $true
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
