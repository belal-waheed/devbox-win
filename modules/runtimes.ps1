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
                if ($DryRun) {
                    Write-DevboxDryRun "Would install Node manager '$manager' ($pkgId) and Node $defaultVer"
                    $installedCount++
                } else {
                    Write-DevboxInfo "Installing Node manager ($pkgId) via winget..."
                    try {
                        $p = Start-Process -FilePath "winget" `
                            -ArgumentList "install", "--id", $pkgId, "--exact", "--silent", "--accept-package-agreements", "--accept-source-agreements" `
                            -NoNewWindow -PassThru -Wait

                        if ($p.ExitCode -eq 0) {
                            Write-DevboxOk "Installed Node manager: $pkgId"
                            Add-DevboxManifestPackage -Manifest $manifest -PackageId $pkgId
                            $installedCount++

                            # Attempt to install default version if manager CLI is directly accessible
                            if (Test-CommandAvailable $managerCmd) {
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
                            Write-DevboxFail "Failed to install Node manager $pkgId (Exit code: $($p.ExitCode))"
                            $failedCount++
                        }
                    } catch {
                        Write-DevboxFail "Error installing Node manager $pkgId" $_.Exception.Message
                        $failedCount++
                    }
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
                } elseif ($DryRun) {
                    Write-DevboxDryRun "Would install pyenv-win and Python $pyVer"
                    $installedCount++
                } else {
                    Write-DevboxInfo "Installing pyenv-win via winget..."
                    try {
                        $p = Start-Process -FilePath "winget" `
                            -ArgumentList "install", "--id", $pyPkg, "--exact", "--silent", "--accept-package-agreements", "--accept-source-agreements" `
                            -NoNewWindow -PassThru -Wait
                        if ($p.ExitCode -eq 0) {
                            Write-DevboxOk "Installed pyenv-win"
                            Add-DevboxManifestPackage -Manifest $manifest -PackageId $pyPkg
                            $installedCount++
                        } else {
                            Write-DevboxFail "Failed to install pyenv-win (Exit code: $($p.ExitCode))"
                            $failedCount++
                        }
                    } catch {
                        Write-DevboxFail "Error installing pyenv-win" $_.Exception.Message
                        $failedCount++
                    }
                }
            } else {
                # Direct winget install
                $wingetPyPkg = "Python.Python.$pyVer"
                if ($DryRun) {
                    Write-DevboxDryRun "Would install $wingetPyPkg via winget"
                    $installedCount++
                } else {
                    Write-DevboxInfo "Installing $wingetPyPkg via winget..."
                    try {
                        $p = Start-Process -FilePath "winget" `
                            -ArgumentList "install", "--id", $wingetPyPkg, "--silent", "--accept-package-agreements", "--accept-source-agreements" `
                            -NoNewWindow -PassThru -Wait
                        if ($p.ExitCode -eq 0) {
                            Write-DevboxOk "Installed $wingetPyPkg"
                            Add-DevboxManifestPackage -Manifest $manifest -PackageId $wingetPyPkg
                            $installedCount++
                        } else {
                            Write-DevboxFail "Failed to install $wingetPyPkg (Exit code: $($p.ExitCode))"
                            $failedCount++
                        }
                    } catch {
                        Write-DevboxFail "Error installing $wingetPyPkg" $_.Exception.Message
                        $failedCount++
                    }
                }
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
            } elseif ($DryRun) {
                Write-DevboxDryRun "Would install Rustlang.Rustup via winget"
                $installedCount++
            } else {
                Write-DevboxInfo "Installing Rustup via winget..."
                try {
                    $p = Start-Process -FilePath "winget" `
                        -ArgumentList "install", "--id", "Rustlang.Rustup", "--exact", "--silent", "--accept-package-agreements", "--accept-source-agreements" `
                        -NoNewWindow -PassThru -Wait
                    if ($p.ExitCode -eq 0) {
                        Write-DevboxOk "Installed Rustup toolchain"
                        Add-DevboxManifestPackage -Manifest $manifest -PackageId "Rustlang.Rustup"
                        $installedCount++
                    } else {
                        Write-DevboxFail "Failed to install Rustup (Exit code: $($p.ExitCode))"
                        $failedCount++
                    }
                } catch {
                    Write-DevboxFail "Error installing Rustup" $_.Exception.Message
                    $failedCount++
                }
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
            # Check if installed
            if ($installedSdks -and ($installedSdks -match "(?m)^$([regex]::Escape($majorPrefix))\.")) {
                Write-DevboxSkip ".NET SDK $vStr" "Already installed"
                $skippedCount++
                continue
            }

            # Map to winget package ID: e.g. "8.0" -> "Microsoft.DotNet.SDK.8"
            $majorNum = ($majorPrefix -split '\.')[0]
            $sdkPkgId = "Microsoft.DotNet.SDK.$majorNum"

            if ($DryRun) {
                Write-DevboxDryRun "Would install .NET SDK $vStr ($sdkPkgId) via winget"
                $installedCount++
                continue
            }

            Write-DevboxInfo "Installing .NET SDK $vStr ($sdkPkgId) via winget..."
            try {
                $p = Start-Process -FilePath "winget" `
                    -ArgumentList "install", "--id", $sdkPkgId, "--exact", "--silent", "--accept-package-agreements", "--accept-source-agreements" `
                    -NoNewWindow -PassThru -Wait
                if ($p.ExitCode -eq 0) {
                    Write-DevboxOk "Installed .NET SDK $vStr ($sdkPkgId)"
                    Add-DevboxManifestPackage -Manifest $manifest -PackageId $sdkPkgId
                    $installedCount++
                } else {
                    Write-DevboxFail "Failed to install $sdkPkgId (Exit code: $($p.ExitCode))"
                    $failedCount++
                }
            } catch {
                Write-DevboxFail "Error installing $sdkPkgId" $_.Exception.Message
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
