# ==============================================================================
# devbox-win :: Core Engine & Module Orchestrator
# Path: core/engine.ps1
# Description: Dependency DAG resolution, module execution, state tracking.
# Standard: Zero emojis. Clean ANSI badges and status summaries.
# ==============================================================================

[CmdletBinding()]
param(
    [string]$ConfigFile = "",
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
    [switch]$Help
)

Set-StrictMode -Version Latest
$startTime = [System.Diagnostics.Stopwatch]::StartNew()

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))

# Load Core Libraries
. (Join-Path $PSScriptRoot "logger.ps1")
. (Join-Path $PSScriptRoot "config.ps1")
. (Join-Path $PSScriptRoot "state.ps1")
. (Join-Path $PSScriptRoot "symlink.ps1")
. (Join-Path $PSScriptRoot "manifest.ps1")

function Show-DevboxHelp {
    Write-DevboxBanner -SubTitle "CLI Usage and Command Reference"
    Write-Host "Usage: pwsh -NoProfile -File core/engine.ps1 [OPTIONS]`n"
    Write-Host "Commands & Operation Modes:"
    Write-Host "  (default)                     Apply full configuration according to config.yaml"
    Write-Host "  -DryRun                       Simulate provisioning actions without modifying disk"
    Write-Host "  -Preset <name>                Apply specific preset (frontend | backend | fullstack | devops | minimal)"
    Write-Host "  -Wizard                       Launch the interactive first-time setup wizard"
    Write-Host "  -Doctor                       Run comprehensive machine health and environment diagnostics"
    Write-Host "  -Export [-ExportPath <path>]  Reverse-engineer active machine toolchain into declarative YAML"
    Write-Host "  -Sync [-Push] [-Pull]         Synchronize workstation configurations with remote Git fork"
    Write-Host "  -Backup [-BackupPath <path>]  Create compressed backup of configs, dotfiles, and manifests"
    Write-Host "  -Restore -BackupPath <path>   Restore workstation configs and symlinks from backup zip"
    Write-Host "  -Marketplace [-ListModules]   Browse community module marketplace"
    Write-Host "  -InstallModule <name|url>     Install a community extension from catalog or remote URL"
    Write-Host "  -Dashboard [-NoLaunch]        Launch visual companion dashboard in Microsoft Edge app mode"
    Write-Host "  -Resume                       Resume provisioning after a system restart, skipping completed steps"
    Write-Host "  -Retry                        Re-execute only modules that previously failed"
    Write-Host "  -Module <name>                Run only a single specific module (core or community)"
    Write-Host "  -ConfigFile <path>            Specify an alternate YAML configuration file"
    Write-Host "  -Uninstall                    Revert symlinks, restore original backups, and clean devbox-win state"
    Write-Host "  -UninstallPackages            When combined with -Uninstall, also removes installed winget packages"
    Write-Host "  -Help                         Display this usage reference guide`n"
    Write-Host "Examples:"
    Write-Host "  pwsh -NoProfile -File core/engine.ps1"
    Write-Host "  pwsh -NoProfile -File core/engine.ps1 -Doctor"
    Write-Host "  pwsh -NoProfile -File core/engine.ps1 -Dashboard"
    Write-Host "  pwsh -NoProfile -File core/engine.ps1 -Sync -Push"
    Write-Host "  pwsh -NoProfile -File core/engine.ps1 -Backup -IncludeSSHKeys"
    Write-Host "  pwsh -NoProfile -File core/engine.ps1 -Marketplace"
    Write-Host "  pwsh -NoProfile -File core/engine.ps1 -Module gaming`n"
}

# Handle Help Request
if ($Help) {
    Show-DevboxHelp
    exit 0
}

# Handle Community Module Marketplace Request
if ($Marketplace -or $ListModules -or $InstallModule) {
    & (Join-Path $PSScriptRoot "marketplace.ps1") -InstallModule $InstallModule -ListModules:$ListModules -RepoRoot $repoRoot -DryRun:$DryRun
    exit $LASTEXITCODE
}

# Handle Git Synchronization Request
if ($Sync -or $Push -or $Pull) {
    & (Join-Path $PSScriptRoot "sync.ps1") -Push:$Push -Pull:$Pull -DryRun:$DryRun -RepoRoot $repoRoot
    exit $LASTEXITCODE
}

# Handle Backup / Disaster Recovery Request
if ($Backup -or $Restore) {
    & (Join-Path $PSScriptRoot "backup.ps1") -Backup:$Backup -Restore:$Restore -BackupPath $BackupPath -IncludeSSHKeys:$IncludeSSHKeys -DryRun:$DryRun -RepoRoot $repoRoot
    exit $LASTEXITCODE
}

# Handle Visual Dashboard Request
if ($Dashboard) {
    & (Join-Path $PSScriptRoot "dashboard.ps1") -NoLaunch:$NoLaunch -RepoRoot $repoRoot
    exit $LASTEXITCODE
}

# Handle Health Audit Request (Doctor)
if ($Doctor) {
    & (Join-Path $PSScriptRoot "doctor.ps1")
    exit $LASTEXITCODE
}

# Handle Reverse-Engineering Export Request
if ($Export) {
    $targetOut = if ($ExportPath) { $ExportPath } else { Join-Path $repoRoot "config.exported.yaml" }
    & (Join-Path $PSScriptRoot "export.ps1") -OutputPath $targetOut
    exit $LASTEXITCODE
}

# Handle GUI Utility Request (CTT winutil style)
if ($Gui) {
    $guiScript = Join-Path $PSScriptRoot "gui.ps1"
    if (Test-Path $guiScript) {
        $guiRes = & $guiScript -RepoRoot $repoRoot -DryRun:$DryRun
        if ($null -ne $guiRes -and $guiRes.Action -in @("Install", "DryRun")) {
            $userConfigYaml = Join-Path $repoRoot "config.yaml"
            Export-GuiConfigToYamlFile -Config $guiRes.Config -Path $userConfigYaml
            $ConfigFile = $userConfigYaml
            if ($guiRes.DryRun) { $DryRun = $true }
        } elseif ($guiRes.Action -eq "Doctor") {
            & (Join-Path $PSScriptRoot "doctor.ps1")
            exit $LASTEXITCODE
        } elseif ($guiRes.Action -eq "Backup") {
            & (Join-Path $PSScriptRoot "backup.ps1") -Backup
            exit $LASTEXITCODE
        } elseif ($guiRes.Action -eq "Export") {
            & (Join-Path $PSScriptRoot "export.ps1")
            exit $LASTEXITCODE
        } else {
            exit 0
        }
    }
}

# Handle Interactive Wizard Request
if ($Wizard) {
    & (Join-Path $PSScriptRoot "wizard.ps1")
    exit 0
}

# Handle Uninstall / Revert Request
if ($Uninstall) {
    Write-DevboxBanner
    Invoke-DevboxRevert -UninstallPackages:$UninstallPackages -DryRun:$DryRun
    exit 0
}

# Resolve Configuration File
if ([string]::IsNullOrWhiteSpace($ConfigFile)) {
    $ConfigFile = Join-Path $repoRoot "config.yaml"
    if (-not (Test-Path $ConfigFile)) {
        $ConfigFile = Join-Path $repoRoot "config.example.yaml"
    }
}

Write-DevboxBanner

if (-not (Test-Path $ConfigFile)) {
    Write-DevboxInfo "No config file found. Launching interactive setup wizard..."
    & (Join-Path $PSScriptRoot "wizard.ps1")
    exit 0
}

Write-DevboxInfo "Using configuration: $ConfigFile"
if ($Preset) {
    Write-DevboxInfo "Active preset override: $Preset"
}
if ($DryRun) {
    Write-DevboxWarn "DRY RUN MODE ENABLED - No changes will be written to disk"
}

# Load and validate configuration
try {
    $config = Read-DevboxConfigFile -Path $ConfigFile -PresetOverride $Preset
} catch {
    Write-DevboxFail "Failed to parse YAML configuration" $_.Exception.Message
    exit 1
}

$validation = Test-DevboxConfig -Config $config
if (-not $validation.Valid) {
    foreach ($err in $validation.Errors) {
        Write-DevboxFail "Config Error: $err"
    }
    exit 1
}

# Module Registry & Dependency Definition (Full 12 Modules)
$moduleRegistry = [ordered]@{
    "packages" = @{
        Name        = "packages"
        Description = "Install Winget toolchain packages"
        Script      = Join-Path $repoRoot "modules\packages.ps1"
        Deps        = @()
    }
    "fonts" = @{
        Name        = "fonts"
        Description = "Install Nerd Fonts"
        Script      = Join-Path $repoRoot "modules\fonts.ps1"
        Deps        = @()
    }
    "envvars" = @{
        Name        = "envvars"
        Description = "Configure user environment variables & PATH"
        Script      = Join-Path $repoRoot "modules\envvars.ps1"
        Deps        = @()
    }
    "git" = @{
        Name        = "git"
        Description = "Configure Git global settings & SSH keys"
        Script      = Join-Path $repoRoot "modules\git.ps1"
        Deps        = @("packages")
    }
    "shell" = @{
        Name        = "shell"
        Description = "Configure Windows Terminal & PowerShell profile"
        Script      = Join-Path $repoRoot "modules\shell.ps1"
        Deps        = @("packages", "fonts")
    }
    "editor" = @{
        Name        = "editor"
        Description = "Configure VS Code settings & extensions"
        Script      = Join-Path $repoRoot "modules\editor.ps1"
        Deps        = @("packages", "fonts")
    }
    "runtimes" = @{
        Name        = "runtimes"
        Description = "Install language runtimes (Node, Python, Rust, .NET)"
        Script      = Join-Path $repoRoot "modules\runtimes.ps1"
        Deps        = @("packages", "envvars")
    }
    "databases" = @{
        Name        = "databases"
        Description = "Install database CLI tools and client engines"
        Script      = Join-Path $repoRoot "modules\databases.ps1"
        Deps        = @("packages")
    }
    "keybindings" = @{
        Name        = "keybindings"
        Description = "Configure PowerToys & AutoHotkey v2 shortcuts"
        Script      = Join-Path $repoRoot "modules\keybindings.ps1"
        Deps        = @("packages")
    }
    "glazewm" = @{
        Name        = "glazewm"
        Description = "Configure GlazeWM tiling window manager"
        Script      = Join-Path $repoRoot "modules\glazewm.ps1"
        Deps        = @("packages")
    }
    "zebar" = @{
        Name        = "zebar"
        Description = "Configure Zebar status bar"
        Script      = Join-Path $repoRoot "modules\zebar.ps1"
        Deps        = @("packages")
    }
    "dotfiles" = @{
        Name        = "dotfiles"
        Description = "Symlink dotfiles (.gitconfig, Starship, GlazeWM, Zebar, AHK)"
        Script      = Join-Path $repoRoot "modules\dotfiles.ps1"
        Deps        = @("shell", "git", "editor", "glazewm", "zebar", "keybindings")
    }
}

# Dynamically register community modules enabled in config
$preservedDryRun = [bool]$DryRun
if ($config.Contains("community_modules") -and ($null -ne $config["community_modules"])) {
    . (Join-Path $PSScriptRoot "marketplace.ps1") -DryRun:$preservedDryRun
    $DryRun = $preservedDryRun
    $commList = @($config["community_modules"])
    foreach ($cMod in $commList) {
        if (-not $cMod) { continue }
        $cModName = $cMod.ToString().Trim().ToLower()
        $cModScript = Join-Path $repoRoot "modules\community\$cModName.ps1"
        if (Test-Path $cModScript) {
            $contract = Test-DevboxCommunityModuleContract -Path $cModScript
            if ($contract.Valid) {
                $cDeps = if ($contract.Metadata.Contains("Dependencies")) { @($contract.Metadata["Dependencies"]) } else { @("packages") }
                $moduleRegistry[$cModName] = @{
                    Name        = $contract.Metadata["Name"]
                    Description = $contract.Metadata["Description"]
                    Script      = $cModScript
                    Deps        = $cDeps
                }
            } else {
                Write-DevboxWarn "Community module '$cModName' failed contract validation. Skipped."
            }
        } else {
            Write-DevboxWarn "Community module '$cModName' specified in config.yaml not found in modules/community/."
        }
    }
}

# If a single community module was requested directly via -Module
if ($Module) {
    $targetCandidate = $Module.ToLower()
    $candidateScript = Join-Path $repoRoot "modules\community\$targetCandidate.ps1"
    if ((-not $moduleRegistry.Contains($targetCandidate)) -and (Test-Path $candidateScript)) {
        . (Join-Path $PSScriptRoot "marketplace.ps1") -DryRun:$preservedDryRun
        $DryRun = $preservedDryRun
        $contract = Test-DevboxCommunityModuleContract -Path $candidateScript
        if ($contract.Valid) {
            $cDeps = if ($contract.Metadata.Contains("Dependencies")) { @($contract.Metadata["Dependencies"]) } else { @("packages") }
            $moduleRegistry[$targetCandidate] = @{
                Name        = $contract.Metadata["Name"]
                Description = $contract.Metadata["Description"]
                Script      = $candidateScript
                Deps        = $cDeps
            }
        }
    }
}

# Load Current State
$state = Load-DevboxState

if ($Resume) {
    if (Test-DevboxRebootRequired -State $state) {
        Write-DevboxInfo "Resuming setup after reboot (Module: $($state.rebootModule))..."
        Clear-DevboxRebootRequired -State $state -DryRun:$DryRun
    } else {
        Write-DevboxInfo "Resume requested. Skipping already-completed modules."
    }
}

# Determine target modules
$enabledModules = [System.Collections.Generic.List[string]]::new()

if ($Module) {
    $targetMod = $Module.ToLower()
    if (-not $moduleRegistry.Contains($targetMod)) {
        Write-DevboxFail "Unknown module: $Module. Available modules: $($moduleRegistry.Keys -join ', ')"
        exit 1
    }
    $enabledModules.Add($targetMod)
} elseif ($Retry) {
    $failedKeys = if ($state.Contains("failedModules") -and ($null -ne $state["failedModules"])) {
        @($state["failedModules"].Keys)
    } else {
        @()
    }

    if ($failedKeys.Count -eq 0) {
        Write-DevboxOk "No failed modules found to retry."
        exit 0
    }

    Write-DevboxInfo "Retrying $($failedKeys.Count) failed module(s): $($failedKeys -join ', ')"
    foreach ($k in $failedKeys) {
        if ($moduleRegistry.Contains($k)) {
            $enabledModules.Add($k)
        }
    }
} else {
    # Read enabled modules from config
    $modConfig = if ($config.Contains("modules") -and ($null -ne $config["modules"])) { $config["modules"] } else { @{} }
    foreach ($key in $moduleRegistry.Keys) {
        $isEnabled = $true
        if ($modConfig.Contains($key)) {
            $isEnabled = [bool]$modConfig[$key]
        }
        if ($isEnabled) {
            $enabledModules.Add($key)
        }
    }
}

# Topological DAG Sorter
function Resolve-ModuleDag {
    param(
        [hashtable]$Registry,
        [System.Collections.Generic.List[string]]$TargetList
    )
    $sorted = [System.Collections.Generic.List[string]]::new()
    $visited = [System.Collections.Generic.HashSet[string]]::new()
    $visiting = [System.Collections.Generic.HashSet[string]]::new()

    function Visit([string]$node) {
        if ($visited.Contains($node)) { return }
        if ($visiting.Contains($node)) { throw "Cyclic dependency detected at module '$node'" }
        [void]$visiting.Add($node)

        if ($Registry.Contains($node)) {
            foreach ($dep in $Registry[$node].Deps) {
                if ($TargetList.Contains($dep)) {
                    Visit $dep
                }
            }
        }

        [void]$visiting.Remove($node)
        [void]$visited.Add($node)
        $sorted.Add($node)
    }

    foreach ($m in $TargetList) {
        Visit $m
    }
    return ,$sorted
}

$executionOrder = Resolve-ModuleDag -Registry $moduleRegistry -TargetList $enabledModules

Write-DevboxSection "Planned Execution DAG"
Write-DevboxInfo "Execution Order: $($executionOrder -join ' -> ')"

$results = [System.Collections.Generic.List[object]]::new()
$stepIndex = 1
$totalSteps = @($executionOrder).Count

foreach ($modName in $executionOrder) {
    $modDef = $moduleRegistry[$modName]
    Write-DevboxStep -Current $stepIndex -Total $totalSteps -Name $modDef.Name -Description $modDef.Description
    $stepIndex++

    # Check if module was already completed when resuming
    if ($Resume -and ($state.completedModules -contains $modName)) {
        Write-DevboxSkip $modName "Already completed prior to resume"
        $results.Add([PSCustomObject]@{ Module = $modName; Status = "SKIP"; Message = "Already completed prior to resume" })
        continue
    }

    if (-not (Test-Path $modDef.Script)) {
        Write-DevboxFail "Module script not found: $($modDef.Script)"
        Set-DevboxModuleResult -State $state -ModuleName $modName -Status "FAIL" -Detail "Script missing"
        $results.Add([PSCustomObject]@{ Module = $modName; Status = "FAIL" })
        continue
    }

    try {
        $rawOutput = @(& $modDef.Script -Config $config -DryRun:$DryRun)
        $status = "OK"
        $msg    = ""
        $needsReboot = $false

        # Isolate the structured result object from any stdout/pipeline noise
        $result = $rawOutput | Where-Object {
            $null -ne $_ -and
            $_.GetType().FullName -ne "System.String" -and
            ($_.PSObject.Properties.Match('Status').Count -gt 0)
        } | Select-Object -Last 1

        if ($null -ne $result) {
            if ($result.PSObject.Properties['Status']) {
                $status = $result.Status
            }
            if ($result.PSObject.Properties['Message']) {
                $msg = $result.Message
            }
            if ($result.PSObject.Properties['NeedsReboot']) {
                $needsReboot = [bool]$result.NeedsReboot
            }
        }

        if (-not $DryRun) {
            Set-DevboxModuleResult -State $state -ModuleName $modName -Status $status -Detail $msg
        }

        $results.Add([PSCustomObject]@{ Module = $modName; Status = $status; Message = $msg })

        if ($needsReboot) {
            Set-DevboxRebootRequired -State $state -ModuleName $modName -Reason $msg -RepoRoot $repoRoot -DryRun:$DryRun
            Write-DevboxWarn "Reboot required by module '$modName'. Registered RunOnce resume."
            Write-DevboxInfo "Please restart your machine. Setup will automatically resume after login."
            break
        }
    } catch {
        Write-DevboxFail "Module execution failed" $_.Exception.Message
        if (-not $DryRun) {
            Set-DevboxModuleResult -State $state -ModuleName $modName -Status "FAIL" -Detail $_.Exception.Message
        }
        $results.Add([PSCustomObject]@{ Module = $modName; Status = "FAIL"; Message = $_.Exception.Message })
    }
}

$startTime.Stop()
Write-DevboxSummary -Results $results -Duration $startTime.Elapsed

$hasFailures = @($results | Where-Object { $_.Status -eq "FAIL" }).Count -gt 0
if ($hasFailures) {
    exit 1
} else {
    exit 0
}
