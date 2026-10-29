# ==============================================================================
# devbox-win :: Module: Runtimes
# Path: modules/runtimes.ps1
# Description: Idempotent installation of Node, Python, Rust, and .NET SDKs.
# Standard: Zero emojis. Detects existing compilers and runtime managers.
# ==============================================================================

param(
    [Parameter(Mandatory=$true)][System.Collections.IDictionary]$Config,
    [switch]$DryRun
)

Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "..\core\logger.ps1")
. (Join-Path $PSScriptRoot "..\core\state.ps1")
. (Join-Path $PSScriptRoot "..\core\manifest.ps1")

function Test-CommandAvailable([string]$CommandName) {
    return ($null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue))
}

function Invoke-DevboxRuntimesModule {
    param(
        [System.Collections.IDictionary]$Config,
        [switch]$DryRun
    )

    $runtimes = if ($Config.Contains("runtimes") -and ($null -ne $Config["runtimes"])) {
        $Config["runtimes"]
    } else {
        $null
    }

    if ($null -eq $runtimes) {
        Write-DevboxSkip "runtimes" "No runtimes configured"
        return [PSCustomObject]@{
            Status  = "SKIP"
            Message = "No runtimes configured"
        }
    }

    $manifest = Load-DevboxManifest
    $installedCount = 0
    $skippedCount   = 0
    $failedCount    = 0

    $installLoc = Get-DevboxCustomInstallLocation -Config $Config

    # 0. Git
    if ($runtimes.Contains("git") -and ($null -ne $runtimes["git"])) {
        $gitEnabled = if ($runtimes["git"] -is [bool]) { $runtimes["git"] } elseif ($runtimes["git"].Contains("install")) { [bool]$runtimes["git"]["install"] } else { $true }
        if ($gitEnabled) {
            if (Test-CommandAvailable "git") {
                Write-DevboxSkip "Git" "Git CLI already available"
                $skippedCount++
            } else {
                $gitRes = Install-DevboxWingetPackage -PackageId "Git.Git" -Location $installLoc -Manifest $manifest -DryRun:$DryRun
                if ($gitRes.Skipped) { $skippedCount++ }
                elseif ($gitRes.Success) { $installedCount++ }
                else { $failedCount++ }
            }
        }
    }

    # 1. Node.js (via nvm or fnm)
    if ($runtimes.Contains("node") -and ($null -ne $runtimes["node"])) {
        $nodeConfig = $runtimes["node"]
        $manager = if ($nodeConfig.Contains("manager") -and $nodeConfig["manager"]) { $nodeConfig["manager"].ToString().ToLower() } else { "nvm" }
        $defaultVer = if ($nodeConfig.Contains("default_version") -and $nodeConfig["default_version"]) { $nodeConfig["default_version"].ToString() } else { "lts" }

        $nodeInstalled = Test-CommandAvailable "node"
        if ($nodeInstalled) {
            $nodeVer = & node --version 2>$null
            Write-DevboxSkip "Node.js" "Node runtime already available ($nodeVer)"
            $skippedCount++
        } else {
            $pkgId = if ($manager -eq "fnm") { "Schniz.fnm" } else { "coreybutler.nvm-windows" }
            $managerCmd = if ($manager -eq "fnm") { "fnm" } else { "nvm" }

            if (-not (Test-CommandAvailable $managerCmd)) {
                $nodeRes = Install-DevboxWingetPackage -PackageId $pkgId -Location $installLoc -Manifest $manifest -DryRun:$DryRun
                if ($nodeRes.Skipped) {
                    $skippedCount++
                } elseif ($nodeRes.Success) {
                    $installedCount++
                    if (-not $DryRun -and (Test-CommandAvailable $managerCmd)) {
                        Write-DevboxInfo "Installing Node.js $defaultVer via $manager..."
                        if ($manager -eq "fnm") {
                            & fnm install $defaultVer
                            & fnm default $defaultVer
                        } else {
                            & nvm install $defaultVer
                            & nvm use $defaultVer
                        }
                        Write-DevboxOk "Installed Node.js $defaultVer"
                    }
                } else {
                    $failedCount++
                }
            } else {
                Write-DevboxSkip "Node Manager" "$manager is already installed"
                $skippedCount++
            }
        }
    }

    # 2. Python
    if ($runtimes.Contains("python") -and ($null -ne $runtimes["python"])) {
        $pyConfig = $runtimes["python"]
        $pyManager = if ($pyConfig.Contains("manager") -and $pyConfig["manager"]) { $pyConfig["manager"].ToString().ToLower() } else { "pyenv-win" }
        $pyVer = if ($pyConfig.Contains("default_version") -and $pyConfig["default_version"]) { $pyConfig["default_version"].ToString() } else { "3.12" }

        $pyInstalled = Test-CommandAvailable "python"
        if ($pyInstalled) {
            $currVer = & python --version 2>$null
            Write-DevboxSkip "Python" "Python already available ($currVer)"
            $skippedCount++
        } else {
            if ($pyManager -eq "pyenv-win") {
                $pyPkg = "pyenv-win.pyenv-win"
                if (Test-CommandAvailable "pyenv") {
                    Write-DevboxSkip "pyenv-win" "pyenv is already installed"
                    $skippedCount++
                } else {
                    $pyRes = Install-DevboxWingetPackage -PackageId $pyPkg -Location $installLoc -Manifest $manifest -DryRun:$DryRun
                    if ($pyRes.Skipped) { $skippedCount++ }
                    elseif ($pyRes.Success) { $installedCount++ }
                    else { $failedCount++ }
                }
            } else {
                $wingetPyPkg = "Python.Python.$pyVer"
                $pyRes = Install-DevboxWingetPackage -PackageId $wingetPyPkg -Location $installLoc -Manifest $manifest -DryRun:$DryRun
                if ($pyRes.Skipped) { $skippedCount++ }
                elseif ($pyRes.Success) { $installedCount++ }
                else { $failedCount++ }
            }
        }
    }

    # 3. Rust (rustup)
    if ($runtimes.Contains("rust") -and ($null -ne $runtimes["rust"])) {
        $rustCfg = $runtimes["rust"]
        $shouldInstall = if ($rustCfg -is [bool]) { $rustCfg } elseif ($rustCfg.Contains("install")) { [bool]$rustCfg["install"] } else { $true }

        if ($shouldInstall) {
            $cargoInstalled = Test-CommandAvailable "cargo"
            $rustupInstalled = Test-CommandAvailable "rustup"

            if ($cargoInstalled -or $rustupInstalled) {
                Write-DevboxSkip "Rust" "Rust toolchain already installed"
                $skippedCount++
            } else {
                $rustRes = Install-DevboxWingetPackage -PackageId "Rustlang.Rustup" -Location $installLoc -Manifest $manifest -DryRun:$DryRun
                if ($rustRes.Skipped) { $skippedCount++ }
                elseif ($rustRes.Success) { $installedCount++ }
                else { $failedCount++ }
            }
        }
    }

    # 4. .NET SDKs
    if ($runtimes.Contains("dotnet") -and ($null -ne $runtimes["dotnet"])) {
        $dotnetCfg = $runtimes["dotnet"]
        $requestedVersions = if ($dotnetCfg.Contains("versions")) { @($dotnetCfg["versions"]) } else { @("8.0") }

        $installedSdks = ""
        if (Test-CommandAvailable "dotnet") {
            $installedSdks = & dotnet --list-sdks 2>$null | Out-String
        }

        foreach ($reqVer in $requestedVersions) {
            $vStr = $reqVer.ToString().Trim()
            $majorPrefix = $vStr.TrimStart('v')
            if ($installedSdks -and ($installedSdks -match "(?m)^$([regex]::Escape($majorPrefix))\.")) {
                Write-DevboxSkip ".NET SDK $vStr" "Already installed"
                $skippedCount++
                continue
            }

            $majorNum = ($majorPrefix -split '\.')[0]
            $sdkPkgId = "Microsoft.DotNet.SDK.$majorNum"

            $netRes = Install-DevboxWingetPackage -PackageId $sdkPkgId -Location $installLoc -Manifest $manifest -DryRun:$DryRun
            if ($netRes.Skipped) {
                $skippedCount++
            } elseif ($netRes.Success) {
                $installedCount++
            } else {
                $failedCount++
            }
        }
    }

    if ($failedCount -gt 0) {
        return [PSCustomObject]@{
            Status  = "FAIL"
            Message = "$failedCount runtime installation(s) failed"
        }
    }

    $finalStatus = if ($installedCount -gt 0) { "OK" } else { "SKIP" }
    return [PSCustomObject]@{
        Status  = $finalStatus
        Message = "$installedCount installed, $skippedCount skipped"
    }
}

Invoke-DevboxRuntimesModule -Config $Config -DryRun:$DryRun
