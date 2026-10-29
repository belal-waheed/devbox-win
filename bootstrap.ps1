# ==============================================================================
# devbox-win :: Bootstrap Entry Point
# Path: bootstrap.ps1
# Usage:
#   irm https://raw.githubusercontent.com/<you>/devbox-win/main/bootstrap.ps1 | iex
#   or locally: pwsh -NoProfile -ExecutionPolicy Bypass -File bootstrap.ps1
# Standard: Zero emojis. Windows 11 / PowerShell 7+ / winget preflight checks.
# ==============================================================================

[CmdletBinding()]
param(
    [string]$RepoUrl = "https://github.com/belal-waheed/devbox-win.git",
    [string]$Branch = "main",
    [string]$TargetDir = "",
    [string]$ConfigFile = "",
    [string]$InstallLocation = "",
    [switch]$DryRun,
    [string]$Module = "",
    [switch]$Retry,
    [switch]$Resume,
    [switch]$Wizard,
    [string]$Preset = "",
    [switch]$Doctor,
    [switch]$Export,
    [string]$ExportPath = "",
    [switch]$Uninstall,
    [switch]$UninstallPackages,
    [switch]$Sync,
    [switch]$Push,
    [switch]$Pull,
    [switch]$Backup,
    [string]$BackupPath = "",
    [switch]$IncludeSSHKeys,
    [switch]$Restore,
    [switch]$Marketplace,
    [string]$InstallModule = "",
    [switch]$ListModules,
    [switch]$Dashboard,
    [switch]$NoLaunch,
    [switch]$Gui,
    [switch]$NonInteractive,
    [switch]$Silent,
    [switch]$SkipDevMode,
    [switch]$Help
)

Set-StrictMode -Version Latest

# ANSI Color Codes
$C_Reset   = "`e[0m"
$C_Bold    = "`e[1m"
$C_Cyan    = "`e[36m"
$C_Green   = "`e[32m"
$C_Yellow  = "`e[33m"
$C_Red     = "`e[31m"
$C_Gray    = "`e[90m"

function Write-BootInfo([string]$msg) { Write-Host "$C_Cyan[INFO]$C_Reset $msg" }
function Write-BootOk([string]$msg)   { Write-Host "$C_Green[OK]$C_Reset   $msg" }
function Write-BootWarn([string]$msg) { Write-Host "$C_Yellow[WARN]$C_Reset $msg" }
function Write-BootFail([string]$msg) { Write-Host "$C_Red[FAIL]$C_Reset $msg" }

Write-Host ""
Write-Host "$C_Cyan$C_Bold==============================================================================$C_Reset"
Write-Host "  devbox-win :: Bootstrap Initializer"
Write-Host "$C_Cyan$C_Bold==============================================================================$C_Reset"

# 1. OS Version Preflight (Windows 11 Build 22000+)
$osBuild = [System.Environment]::OSVersion.Version.Build
if ($osBuild -lt 22000) {
    Write-BootFail "Unsupported Operating System (Build $osBuild). devbox-win requires Windows 11 (Build 22000+)."
    exit 1
}
Write-BootOk "Operating System: Windows 11 (Build $osBuild)"

# 2. Developer Mode Verification (enables unprivileged symlinks)
if (-not $SkipDevMode) {
    $devModeReg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    $devModeVal = (Get-ItemProperty -Path $devModeReg -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense

    if ($devModeVal -eq 1) {
        Write-BootOk "Windows Developer Mode is enabled"
    } else {
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if ($isAdmin) {
            Write-BootInfo "Enabling Windows Developer Mode for symlink support..."
            if (-not (Test-Path $devModeReg)) {
                New-Item -Path $devModeReg -Force | Out-Null
            }
            Set-ItemProperty -Path $devModeReg -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -Force
            Write-BootOk "Windows Developer Mode enabled successfully"
        } else {
            Write-BootWarn "Windows Developer Mode is disabled (required for unprivileged symlinks)."
            Write-BootInfo "Triggering one-time elevation prompt to enable Developer Mode..."
            $elevateCommand = "if (-not (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock')) { New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Force | Out-Null }; Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Name 'AllowDevelopmentWithoutDevLicense' -Value 1 -Force"
            try {
                $elevateProc = Start-Process -FilePath "pwsh" -ArgumentList "-NoProfile", "-Command", $elevateCommand -Verb RunAs -Wait -PassThru -ErrorAction Stop
                $devModeValAfter = (Get-ItemProperty -Path $devModeReg -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
                if ($devModeValAfter -eq 1) {
                    Write-BootOk "Windows Developer Mode enabled successfully via elevation"
                } else {
                    Write-BootWarn "Developer Mode not enabled. Symlinks may fall back to file copies."
                }
            } catch {
                Write-BootWarn "Elevation was declined or unavailable. Symlinks may require administrator privileges or fall back to file copies."
            }
        }
    }
}

# 3. Winget Verification
$wingetCmd = Get-Command "winget" -ErrorAction SilentlyContinue
if (-not $wingetCmd) {
    Write-BootFail "winget is not available in PATH. Please install 'App Installer' from the Microsoft Store or update Windows."
    exit 1
}
Write-BootOk "Package manager: winget is available"

# 4. PowerShell 7+ Verification and Respawner
$psMajor = $PSVersionTable.PSVersion.Major
if ($psMajor -lt 7) {
    Write-BootWarn "Running in Windows PowerShell $psMajor. PowerShell 7+ is required."

    # Look for existing pwsh.exe installation
    $pwshCandidates = @(
        "C:\Program Files\PowerShell\7\pwsh.exe",
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\pwsh.exe"
    )
    $foundPwsh = $null
    foreach ($cand in $pwshCandidates) {
        if (Test-Path $cand) {
            $foundPwsh = $cand
            break
        }
    }

    if (-not $foundPwsh) {
        Write-BootInfo "Installing PowerShell 7 via winget..."
        & winget install --id Microsoft.PowerShell --exact --silent --accept-package-agreements --accept-source-agreements
        foreach ($cand in $pwshCandidates) {
            if (Test-Path $cand) {
                $foundPwsh = $cand
                break
            }
        }
    }

    if ($foundPwsh) {
        Write-BootInfo "Respawning under PowerShell 7 ($foundPwsh)..."
        $scriptPath = if ($MyInvocation.MyCommand.Path) { $MyInvocation.MyCommand.Path } else { "$env:TEMP\devbox_bootstrap.ps1" }
        if (-not (Test-Path $scriptPath)) {
            $scriptContent = $MyInvocation.MyCommand.ScriptContents
            Set-Content -Path $scriptPath -Value $scriptContent -Encoding utf8
        }

        $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptPath)
        if ($ConfigFile) { $argList += "-ConfigFile"; $argList += $ConfigFile }
        if ($InstallLocation) { $argList += "-InstallLocation"; $argList += $InstallLocation }
        if ($DryRun) { $argList += "-DryRun" }
        if ($Module) { $argList += "-Module"; $argList += $Module }
        if ($Retry)  { $argList += "-Retry" }
        if ($Resume) { $argList += "-Resume" }
        if ($Wizard) { $argList += "-Wizard" }
        if ($Preset) { $argList += "-Preset"; $argList += $Preset }
        if ($Doctor) { $argList += "-Doctor" }
        if ($Export) { $argList += "-Export" }
        if ($ExportPath) { $argList += "-ExportPath"; $argList += $ExportPath }
        if ($Uninstall) { $argList += "-Uninstall" }
        if ($UninstallPackages) { $argList += "-UninstallPackages" }
        if ($Help)   { $argList += "-Help" }

        Start-Process -FilePath $foundPwsh -ArgumentList $argList -Wait -NoNewWindow
        exit 0
    } else {
        Write-BootFail "Failed to locate or install PowerShell 7. Please install it manually and re-run."
        exit 1
    }
}
Write-BootOk "Runtime: PowerShell $($PSVersionTable.PSVersion)"

# 5. Locate or Clone Repository
$workDir = ""
$isLocalRepo = $false

if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "core\engine.ps1"))) {
    $workDir = $PSScriptRoot
    $isLocalRepo = $true
    Write-BootOk "Executing from local repository at: $workDir"
} else {
    $target = if ($TargetDir) { $TargetDir } else { (Join-Path $HOME ".devbox-win\repo") }
    $workDir = $target

    if (Test-Path (Join-Path $workDir "core\engine.ps1")) {
        Write-BootOk "Existing repository found at: $workDir"
        if (Get-Command "git" -ErrorAction SilentlyContinue) {
            Write-BootInfo "Pulling latest changes from $Branch..."
            & git -C $workDir pull origin $Branch 2>$null | Out-Null
        }
    } else {
        Write-BootInfo "Bootstrapping repository to $workDir..."
        if (Test-Path $workDir) {
            # If the directory exists but does not contain the core engine, clean the broken residue
            if (-not (Test-Path (Join-Path $workDir "core\engine.ps1"))) {
                Write-BootWarn "Found incomplete directory at $workDir. Resetting for clean bootstrap..."
                Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        if (Get-Command "git" -ErrorAction SilentlyContinue) {
            & git clone --branch $Branch $RepoUrl $workDir
        } else {
            # Download zip from GitHub if git is not yet installed
            $zipUrl = "$($RepoUrl -replace '\.git$', '')/archive/refs/heads/$Branch.zip"
            $zipPath = Join-Path $env:TEMP "devbox-win.zip"
            Write-BootInfo "Downloading archive: $zipUrl"
            Invoke-RestMethod -Uri $zipUrl -OutFile $zipPath
            $extractDir = Join-Path $env:TEMP "devbox_extract"
            Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
            $extractedRoot = Get-ChildItem -Path $extractDir -Directory | Select-Object -First 1
            Copy-Item -Path "$($extractedRoot.FullName)\*" -Destination $workDir -Recurse -Force
            Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# 6. Launch Core Engine or GUI
$engineScript = Join-Path $workDir "core\engine.ps1"
if (-not (Test-Path $engineScript)) {
    Write-BootFail "Core engine not found at: $engineScript"
    exit 1
}

$engineParams = @{}
if ($ConfigFile) { $engineParams["ConfigFile"] = $ConfigFile }
if ($InstallLocation) { $engineParams["InstallLocation"] = $InstallLocation }
if ($DryRun)     { $engineParams["DryRun"] = $true }
if ($Module)     { $engineParams["Module"] = $Module }
if ($Retry)      { $engineParams["Retry"] = $true }
if ($Resume)     { $engineParams["Resume"] = $true }
if ($Wizard)     { $engineParams["Wizard"] = $true }
if ($Preset)     { $engineParams["Preset"] = $Preset }
if ($Doctor)     { $engineParams["Doctor"] = $true }
if ($Export)     { $engineParams["Export"] = $true }
if ($ExportPath) { $engineParams["ExportPath"] = $ExportPath }
if ($Uninstall)  { $engineParams["Uninstall"] = $true }
if ($UninstallPackages) { $engineParams["UninstallPackages"] = $true }
if ($Sync)       { $engineParams["Sync"] = $true }
if ($Push)       { $engineParams["Push"] = $true }
if ($Pull)       { $engineParams["Pull"] = $true }
if ($Backup)     { $engineParams["Backup"] = $true }
if ($BackupPath) { $engineParams["BackupPath"] = $BackupPath }
if ($IncludeSSHKeys) { $engineParams["IncludeSSHKeys"] = $true }
if ($Restore)    { $engineParams["Restore"] = $true }
if ($Marketplace) { $engineParams["Marketplace"] = $true }
if ($InstallModule) { $engineParams["InstallModule"] = $InstallModule }
if ($ListModules) { $engineParams["ListModules"] = $true }
if ($Dashboard)  { $engineParams["Dashboard"] = $true }
if ($NoLaunch)   { $engineParams["NoLaunch"] = $true }
if ($Help)       { $engineParams["Help"] = $true }

# Interactive Desktop Mode (CTT winutil style):
# When executed without batch parameters in an interactive console, default to GUI utility.
Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue

$guiScript = Join-Path $workDir "core\gui.ps1"
if ([System.Windows.Forms.SystemInformation]::UserInteractive -and (Test-Path $guiScript) -and (($engineParams.Count -eq 0) -or $Gui) -and (-not $NonInteractive) -and (-not $Silent)) {
    Write-BootInfo "Launching devbox-win Windows Developer Utility (GUI)..."
    $guiResult = & $guiScript -RepoRoot $workDir
    if ($null -ne $guiResult -and $guiResult.Action -ne "Cancel") {
        if ($guiResult.Action -eq "Doctor") {
            & $engineScript -Doctor
            exit $LASTEXITCODE
        }
        if ($guiResult.Action -eq "Backup") {
            & $engineScript -Backup
            exit $LASTEXITCODE
        }
        if ($guiResult.Action -eq "Export") {
            & $engineScript -Export
            exit $LASTEXITCODE
        }
        if ($guiResult.Action -in @("Install", "DryRun")) {
            . (Join-Path $workDir "core\config.ps1")
            $userConfigYaml = Join-Path $workDir "config.yaml"
            Export-GuiConfigToYamlFile -Config $guiResult.Config -Path $userConfigYaml
            $isDry = ($guiResult.DryRun -or $DryRun)
            Write-BootInfo "Applying configuration from GUI selection..."
            & $engineScript -ConfigFile $userConfigYaml -DryRun:$isDry
            exit $LASTEXITCODE
        }
    } else {
        Write-BootInfo "Devbox Windows Utility closed by user."
        exit 0
    }
}

Write-BootInfo "Transferring execution to core engine..."
& $engineScript @engineParams
exit $LASTEXITCODE
