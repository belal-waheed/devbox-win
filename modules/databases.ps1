# ==============================================================================
# devbox-win :: Module: Databases
# Path: modules/databases.ps1
# Description: Idempotent database engine and CLI client tooling installation.
# Standard: Zero emojis. Checks binary existence and winget registry state.
# ==============================================================================

param(
    [Parameter(Mandatory=$true)][System.Collections.IDictionary]$Config,
    [switch]$DryRun
)

Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "..\core\logger.ps1")
. (Join-Path $PSScriptRoot "..\core\manifest.ps1")

function Test-DatabaseBinaryOrPackageInstalled([string]$PackageId) {
    # Check well-known CLI binaries first for instant zero-overhead check
    switch -Wildcard ($PackageId.ToLower()) {
        "*postgres*" {
            if (Get-Command "psql" -ErrorAction SilentlyContinue) { return $true }
        }
        "*redis*" {
            if (Get-Command "redis-cli" -ErrorAction SilentlyContinue) { return $true }
        }
        "*mongo*" {
            if (Get-Command "mongosh" -ErrorAction SilentlyContinue -or (Get-Command "mongod" -ErrorAction SilentlyContinue)) { return $true }
        }
        "*sqlite*" {
            if (Get-Command "sqlite3" -ErrorAction SilentlyContinue) { return $true }
        }
    }

    # Check winget list
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

function Invoke-DevboxDatabasesModule {
    param(
        [System.Collections.IDictionary]$Config,
        [switch]$DryRun
    )

    $dbList = if ($Config.Contains("databases") -and ($null -ne $Config["databases"])) {
        @($Config["databases"])
    } else {
        @()
    }

    if ($dbList.Count -eq 0) {
        Write-DevboxSkip "databases" "No database tools configured"
        return [PSCustomObject]@{
            Status  = "SKIP"
            Message = "No databases configured"
        }
    }

    $manifest = Load-DevboxManifest
    $installedCount = 0
    $skippedCount   = 0
    $failedCount    = 0

    Write-DevboxInfo "Evaluating $($dbList.Count) database client(s) and toolchain(s)..."

    foreach ($dbItem in $dbList) {
        if (-not $dbItem) { continue }
        $pkgId = $dbItem.ToString().Trim()

        if (Test-DatabaseBinaryOrPackageInstalled -PackageId $pkgId) {
            Write-DevboxSkip $pkgId "Already installed or CLI tool present in PATH"
            $skippedCount++
            continue
        }

        if ($DryRun) {
            Write-DevboxDryRun "Would install database package: $pkgId"
            $installedCount++
            continue
        }

        Write-DevboxInfo "Installing database tool $pkgId via winget..."
        try {
            $p = Start-Process -FilePath "winget" `
                -ArgumentList "install", "--id", $pkgId, "--exact", "--silent", "--accept-package-agreements", "--accept-source-agreements" `
                -NoNewWindow -PassThru -Wait

            if ($p.ExitCode -eq 0) {
                Write-DevboxOk "Installed database tool: $pkgId"
                Add-DevboxManifestPackage -Manifest $manifest -PackageId $pkgId
                $installedCount++
            } elseif ($p.ExitCode -eq -1978335189) {
                Write-DevboxSkip $pkgId "Already installed"
                $skippedCount++
            } else {
                Write-DevboxFail "Failed to install $pkgId (Exit code: $($p.ExitCode))"
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
            Message = "$failedCount database installation(s) failed"
        }
    }

    $finalStatus = if ($installedCount -gt 0) { "OK" } else { "SKIP" }
    return [PSCustomObject]@{
        Status  = $finalStatus
        Message = "$installedCount installed, $skippedCount skipped"
    }
}

Invoke-DevboxDatabasesModule -Config $Config -DryRun:$DryRun
