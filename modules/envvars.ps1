# ==============================================================================
# devbox-win :: Module: Environment Variables
# Path: modules/envvars.ps1
# Description: Idempotent user environment variable and PATH configuration.
# Standard: Zero emojis. Checks existing state before updating registry.
# ==============================================================================

param(
    [Parameter(Mandatory=$true)][System.Collections.IDictionary]$Config,
    [switch]$DryRun
)

Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "..\core\logger.ps1")
. (Join-Path $PSScriptRoot "..\core\manifest.ps1")

function Invoke-DevboxEnvvarsModule {
    param(
        [System.Collections.IDictionary]$Config,
        [switch]$DryRun
    )

    $envvars = if ($Config.Contains("envvars") -and ($null -ne $Config["envvars"])) {
        $Config["envvars"]
    } else {
        $null
    }

    $pathAdditions = [System.Collections.Generic.List[string]]::new()
    if ($Config.Contains("path_additions") -and ($null -ne $Config["path_additions"])) {
        foreach ($p in $Config["path_additions"]) {
            if ($p) { $pathAdditions.Add($p.ToString().Trim()) }
        }
    }

    if ($null -eq $envvars -and $pathAdditions.Count -eq 0) {
        Write-DevboxSkip "envvars" "No environment variables or PATH additions configured"
        return [PSCustomObject]@{
            Status  = "SKIP"
            Message = "No environment variables configured"
        }
    }

    $manifest = Load-DevboxManifest
    $updatedCount = 0
    $skippedCount = 0
    $failedCount  = 0

    # 1. Process Key-Value Environment Variables
    if ($null -ne $envvars) {
        foreach ($key in $envvars.Keys) {
            $keyName = $key.ToString().Trim()
            $targetVal = $envvars[$key]

            # Special handling if PATH is defined under envvars
            if ($keyName -eq "PATH" -or $keyName -eq "Path") {
                if ($targetVal -is [System.Collections.IEnumerable] -and -not ($targetVal -is [string])) {
                    foreach ($entry in $targetVal) {
                        if ($entry) { $pathAdditions.Add($entry.ToString().Trim()) }
                    }
                    continue
                }
            }

            $strVal = if ($null -eq $targetVal) { "" } else { $targetVal.ToString().Trim() }
            $currentVal = [System.Environment]::GetEnvironmentVariable($keyName, [System.EnvironmentVariableTarget]::User)

            if ($currentVal -eq $strVal) {
                Write-DevboxSkip $keyName "Already set to '$strVal'"
                $skippedCount++
                continue
            }

            if ($DryRun) {
                Write-DevboxDryRun "Would set env var $keyName = '$strVal' (User)"
                $updatedCount++
                continue
            }

            try {
                Add-DevboxManifestEnvVar -Manifest $manifest -Name $keyName -PreviousValue $currentVal
                [System.Environment]::SetEnvironmentVariable($keyName, $strVal, [System.EnvironmentVariableTarget]::User)
                [System.Environment]::SetEnvironmentVariable($keyName, $strVal, [System.EnvironmentVariableTarget]::Process)
                Write-DevboxOk "Configured env var: $keyName = '$strVal'"
                $updatedCount++
            } catch {
                Write-DevboxFail "Failed to set env var $keyName" $_.Exception.Message
                $failedCount++
            }
        }
    }

    # 2. Process PATH Additions
    if ($pathAdditions.Count -gt 0) {
        $currentUserPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
        if ($null -eq $currentUserPath) { $currentUserPath = "" }
        $existingParts = @($currentUserPath -split ';' | Where-Object { [string]::IsNullOrWhiteSpace($_) -eq $false } | ForEach-Object { $_.Trim().TrimEnd('\', '/') })

        $newPathsToAdd = [System.Collections.Generic.List[string]]::new()
        foreach ($candidate in $pathAdditions) {
            $norm = $candidate.TrimEnd('\', '/')
            $alreadyPresent = $false
            foreach ($p in $existingParts) {
                if ($p -eq $norm) {
                    $alreadyPresent = $true
                    break
                }
            }

            if ($alreadyPresent) {
                Write-DevboxSkip "PATH addition" "'$candidate' already in User PATH"
                $skippedCount++
            } else {
                $newPathsToAdd.Add($candidate)
            }
        }

        if ($newPathsToAdd.Count -gt 0) {
            $updatedPath = ($existingParts + $newPathsToAdd) -join ';'
            if ($updatedPath.Length -gt 2048) {
                Write-DevboxWarn "User PATH length ($($updatedPath.Length) chars) exceeds safe threshold of 2048. Skipping PATH modification to prevent corruption."
                $failedCount++
            } elseif ($DryRun) {
                foreach ($add in $newPathsToAdd) {
                    Write-DevboxDryRun "Would append to User PATH: $add"
                }
                $updatedCount += $newPathsToAdd.Count
            } else {
                try {
                    Add-DevboxManifestEnvVar -Manifest $manifest -Name "Path" -PreviousValue $currentUserPath
                    [System.Environment]::SetEnvironmentVariable("Path", $updatedPath, [System.EnvironmentVariableTarget]::User)
                    # Also update process PATH
                    $env:Path = "$env:Path;$($newPathsToAdd -join ';')"
                    foreach ($add in $newPathsToAdd) {
                        Write-DevboxOk "Appended to User PATH: $add"
                    }
                    $updatedCount += $newPathsToAdd.Count
                } catch {
                    Write-DevboxFail "Failed to update User PATH" $_.Exception.Message
                    $failedCount++
                }
            }
        }
    }

    if ($failedCount -gt 0) {
        return [PSCustomObject]@{
            Status  = "FAIL"
            Message = "$failedCount error(s) updating environment variables"
        }
    }

    $finalStatus = if ($updatedCount -gt 0) { "OK" } else { "SKIP" }
    return [PSCustomObject]@{
        Status  = $finalStatus
        Message = "$updatedCount configured, $skippedCount skipped"
    }
}

Invoke-DevboxEnvvarsModule -Config $Config -DryRun:$DryRun
