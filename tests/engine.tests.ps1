# ==============================================================================
# devbox-win :: Verification Test Suite
# Path: tests/engine.tests.ps1
# Standard: Zero emojis. AAA verification pattern for core components.
# ==============================================================================

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$testRoot = $PSScriptRoot
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $testRoot ".."))

. (Join-Path $projectRoot "core\logger.ps1")
. (Join-Path $projectRoot "core\config.ps1")
. (Join-Path $projectRoot "core\state.ps1")
. (Join-Path $projectRoot "core\symlink.ps1")
. (Join-Path $projectRoot "core\manifest.ps1")

$passCount = 0
$failCount = 0

function Assert-True([bool]$Condition, [string]$TestName) {
    if ($Condition) {
        Write-DevboxOk "TEST PASS: $TestName"
        $script:passCount++
    } else {
        Write-DevboxFail "TEST FAIL: $TestName"
        $script:failCount++
    }
}

Write-DevboxBanner -SubTitle "Automated Test Suite"

# Test 1: Simple YAML Parser
Write-DevboxSection "Test: YAML Configuration Parser"
$testYaml = @"
user:
  name: "Test User"
  email: "test@example.com"
preset: fullstack
modules:
  packages: true
  git: false
packages:
  - Git.Git
  - Microsoft.VisualStudioCode
notes: 'Hash # inside single quotes' # trailing comment
"@
$parsed = ConvertFrom-SimpleYaml -YamlText $testYaml
Assert-True ($parsed.user.name -eq "Test User") "Parses user.name correctly"
Assert-True ($parsed.user.email -eq "test@example.com") "Parses user.email correctly"
Assert-True ($parsed.modules.packages -eq $true) "Parses boolean true"
Assert-True ($parsed.modules.git -eq $false) "Parses boolean false"
Assert-True ($parsed.packages.Count -eq 2) "Parses package list count"
Assert-True ($parsed.packages[0] -eq "Git.Git") "Parses list item value"
Assert-True ($parsed.notes -eq "Hash # inside single quotes") "Preserves hashes inside single-quoted strings with trailing comments"

# Test 2: Config Validator
Write-DevboxSection "Test: Config Validator"
$valResult = Test-DevboxConfig -Config $parsed
Assert-True ($valResult.Valid -eq $true) "Valid configuration passes schema validation"

# Test 3: State Initialization and Record
Write-DevboxSection "Test: State Management"
$tempState = New-DevboxStateTemplate
Assert-True ($tempState.schemaVersion -eq "1.0.0") "Initializes fresh state template"
Set-DevboxModuleResult -State $tempState -ModuleName "packages" -Status "OK" -Detail "Test install"
Assert-True ($tempState.completedModules -contains "packages") "Records completed module in state"

# Test 4: Reboot State Checkpointing & Resume
Write-DevboxSection "Test: Reboot State Checkpointing"
Set-DevboxRebootRequired -State $tempState -ModuleName "runtimes" -Reason "Path update" -DryRun
Assert-True ($tempState.needsReboot -eq $true) "Flags state as needing reboot"
Assert-True ($tempState.rebootModule -eq "runtimes") "Records reboot-requesting module"
Assert-True (Test-DevboxRebootRequired -State $tempState) "Test-DevboxRebootRequired returns true"

Clear-DevboxRebootRequired -State $tempState -DryRun
Assert-True ($tempState.needsReboot -eq $false) "Clears reboot flag on resume"
Assert-True ($null -eq $tempState.rebootModule) "Clears reboot-requesting module"
Assert-True (-not (Test-DevboxRebootRequired -State $tempState)) "Test-DevboxRebootRequired returns false after clear"

# Test 5: Preset Loading & Deep Merging
Write-DevboxSection "Test: Presets and Configuration Merging"
$frontendPreset = Get-DevboxPreset -PresetName "frontend" -RepoRoot $projectRoot
Assert-True ($null -ne $frontendPreset) "Loads frontend preset successfully"
Assert-True ($frontendPreset.preset -eq "frontend") "Frontend preset has correct preset identifier"
Assert-True ($frontendPreset.packages -contains "Google.Chrome") "Frontend preset contains Google.Chrome"

$backendPreset = Get-DevboxPreset -PresetName "backend" -RepoRoot $projectRoot
Assert-True ($null -ne $backendPreset) "Loads backend preset successfully"
Assert-True ($backendPreset.databases -contains "PostgreSQL.PostgreSQL") "Backend preset contains PostgreSQL"

$fullstackPreset = Get-DevboxPreset -PresetName "fullstack" -RepoRoot $projectRoot
Assert-True ($null -ne $fullstackPreset) "Loads fullstack preset successfully"
Assert-True ($fullstackPreset.modules.glazewm -eq $true) "Fullstack preset enables GlazeWM"
Assert-True ($fullstackPreset.modules.zebar -eq $true) "Fullstack preset enables Zebar"

$belalPreset = Get-DevboxPreset -PresetName "belal-catppuccin" -RepoRoot $projectRoot
Assert-True ($null -ne $belalPreset) "Loads belal-catppuccin preset successfully"
Assert-True ($belalPreset.preset -eq "belal-catppuccin") "belal-catppuccin preset has correct identifier"
Assert-True ($belalPreset.packages -contains "Zed.Zed") "belal-catppuccin preset contains Zed.Zed"
Assert-True ($belalPreset.packages -contains "glzr-io.glazewm") "belal-catppuccin preset contains GlazeWM"
Assert-True ($belalPreset.packages -contains "glzr-io.zebar") "belal-catppuccin preset contains Zebar"
Assert-True ($belalPreset.editor.primary -eq "zed") "belal-catppuccin specifies primary editor as zed"
Assert-True ($belalPreset.glazewm.hide_method -eq "cloak") "belal-catppuccin specifies glazewm cloak hide_method"
Assert-True ($belalPreset.glazewm.border_color -eq "#cba6f7") "belal-catppuccin specifies Catppuccin lavender border"
Assert-True ($belalPreset.zebar.pack -eq "nord") "belal-catppuccin specifies Zebar nord pack"

# Test Deep Merge
$baseConfig = [ordered]@{
    preset = "frontend"
    user   = [ordered]@{ name = "Default User"; email = "default@example.com" }
    editor = [ordered]@{ primary = "vscode"; sync_settings = $true }
}
$overrideConfig = [ordered]@{
    user   = [ordered]@{ name = "Custom Developer" }
    editor = [ordered]@{ primary = "cursor" }
}
$merged = Merge-DevboxConfig -Base $baseConfig -Override $overrideConfig
Assert-True ($merged.user.name -eq "Custom Developer") "Merged override value overrides base (user.name)"
Assert-True ($merged.user.email -eq "default@example.com") "Merged retains non-overridden base field (user.email)"
Assert-True ($merged.editor.primary -eq "cursor") "Merged override dictionary property (editor.primary)"
Assert-True ($merged.editor.sync_settings -eq $true) "Merged retains base dictionary property (editor.sync_settings)"

# Test 6: Wizard Non-Interactive Config Generation
Write-DevboxSection "Test: Interactive Wizard Config Generator"
. (Join-Path $projectRoot "core\wizard.ps1")
$testWizardOutput = Join-Path $env:TEMP "devbox_wizard_test_$(Get-Random).yaml"
$wizRes = Invoke-DevboxWizard `
    -NonInteractive `
    -Name "Jane Developer" `
    -Email "jane@company.com" `
    -GithubUser "janedev" `
    -Preset "backend" `
    -DisableTilingWM `
    -OutputPath $testWizardOutput

Assert-True (Test-Path $testWizardOutput) "Wizard generated config file exists"
$parsedWiz = Read-DevboxConfigFile -Path $testWizardOutput
Assert-True ($parsedWiz.user.name -eq "Jane Developer") "Wizard generated user.name matches"
Assert-True ($parsedWiz.user.email -eq "jane@company.com") "Wizard generated user.email matches"
Assert-True ($parsedWiz.preset -eq "backend") "Wizard generated preset matches"
Assert-True ($parsedWiz.modules.glazewm -eq $false) "Wizard disable tiling WM honored"
Remove-Item -Path $testWizardOutput -Force -ErrorAction SilentlyContinue

# Wizard default execution test (Author signature rice default)
$defaultWizOutput = Join-Path $env:TEMP "devbox_wizard_default_$(Get-Random).yaml"
$defaultWizRes = Invoke-DevboxWizard `
    -NonInteractive `
    -OutputPath $defaultWizOutput

Assert-True (Test-Path $defaultWizOutput) "Wizard default run generates config file"
$parsedDefaultWiz = Read-DevboxConfigFile -Path $defaultWizOutput
Assert-True ($parsedDefaultWiz.preset -eq "belal-catppuccin") "Wizard default preset is belal-catppuccin"
Assert-True ($parsedDefaultWiz.modules.glazewm -eq $true) "Wizard default enables GlazeWM"
Assert-True ($parsedDefaultWiz.modules.zebar -eq $true) "Wizard default enables Zebar"
Assert-True ($parsedDefaultWiz.editor.primary -eq "zed") "Wizard default selects Zed primary editor"
Assert-True ($parsedDefaultWiz.packages -contains "Zed.Zed") "Wizard default packages include Zed.Zed"
Assert-True ($parsedDefaultWiz.packages -contains "DEVCOM.JetBrainsMonoNerdFont") "Wizard default packages include JetBrainsMono NF"
Remove-Item -Path $defaultWizOutput -Force -ErrorAction SilentlyContinue

# Test 7: Symlink Creation and Target Verification
Write-DevboxSection "Test: Symlink and Backup Engine"
$tmpDir = Join-Path $env:TEMP "devbox_test_$(Get-Random)"
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

$srcFile = Join-Path $tmpDir "source.txt"
$dstFile = Join-Path $tmpDir "destination.txt"
Set-Content -Path $srcFile -Value "Devbox Symlink Test Source"

$linkRes = New-DevboxSymlink -Source $srcFile -Destination $dstFile
Assert-True ($linkRes.Status -eq "OK") "Creates symbolic link successfully"
Assert-True (Test-DevboxSymlinkTarget -LinkPath $dstFile -ExpectedSource $srcFile) "Symlink target resolves to source"

# Idempotent re-run test
$repeatRes = New-DevboxSymlink -Source $srcFile -Destination $dstFile
Assert-True ($repeatRes.Status -eq "SKIP") "Second run is idempotent (SKIP status)"

# Test real file backup on overwrite
$existingRealFile = Join-Path $tmpDir "real_existing.txt"
Set-Content -Path $existingRealFile -Value "Original Content To Backup"
$overwriteSrc = Join-Path $tmpDir "new_symlink_source.txt"
Set-Content -Path $overwriteSrc -Value "New Symlink Target Content"
$replaceRes = New-DevboxSymlink -Source $overwriteSrc -Destination $existingRealFile
Assert-True ($replaceRes.Status -eq "OK") "Replaces existing real file with symlink"
Assert-True (-not [string]::IsNullOrWhiteSpace($replaceRes.BackupPath)) "Returns BackupPath on real file replacement"
Assert-True (Test-Path $replaceRes.BackupPath) "Backup file exists on disk at BackupPath"
Assert-True ((Get-Content $replaceRes.BackupPath -Raw) -match "Original Content To Backup") "Backup file contains original contents"

# Test collision-free backups for identical leaf names
$subDirA = Join-Path $tmpDir "appA"
$subDirB = Join-Path $tmpDir "appB"
New-Item -ItemType Directory -Path $subDirA, $subDirB -Force | Out-Null
$leafA = Join-Path $subDirA "settings.json"
$leafB = Join-Path $subDirB "settings.json"
Set-Content -Path $leafA -Value "App A Config"
Set-Content -Path $leafB -Value "App B Config"
$backupA = Backup-DevboxPath -Path $leafA
$backupB = Backup-DevboxPath -Path $leafB
Assert-True ($backupA -ne $backupB) "Distinct backup paths generated for identical leaf names"
Assert-True (Test-Path $backupA) "First leaf backup exists"
Assert-True (Test-Path $backupB) "Second leaf backup exists"

# Clean up temporary test files
Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $backupA, $backupB -Force -ErrorAction SilentlyContinue
if ($replaceRes.BackupPath) { Remove-Item -Path $replaceRes.BackupPath -Force -ErrorAction SilentlyContinue }

# Test 8: Machine Health Doctor Audit
Write-DevboxSection "Test: Machine Health Doctor Diagnostics"
. (Join-Path $projectRoot "core\doctor.ps1")
$doctorObj = Invoke-DevboxDoctor -AsObject -Quiet
Assert-True ($null -ne $doctorObj) "Doctor diagnostic returns structured object"
Assert-True ($doctorObj.Checks.Count -ge 10) "Doctor performs comprehensive checks (count: $($doctorObj.Checks.Count))"
Assert-True ($doctorObj.Passed -gt 0) "Doctor records passed health checks (passed: $($doctorObj.Passed))"
$osCheck = $doctorObj.Checks | Where-Object { $_.Name -eq "Windows 11 Build" }
Assert-True ($null -ne $osCheck) "Doctor validates Windows 11 Build"
$psCheck = $doctorObj.Checks | Where-Object { $_.Name -eq "PowerShell Runtime" }
Assert-True ($null -ne $psCheck -and ($psCheck.Status -eq "OK" -or $psCheck.Status -eq "WARN")) "Doctor validates PowerShell Runtime"
$netCheck = $doctorObj.Checks | Where-Object { $_.Name -eq "Network Connectivity" }
Assert-True ($null -ne $netCheck) "Doctor validates network connectivity to GitHub"
$symCheck = $doctorObj.Checks | Where-Object { $_.Name -eq "Symlink Integrity" }
Assert-True ($null -ne $symCheck) "Doctor audits symlink integrity from manifest"

# Audit resilience on pristine machines / CI runners without registered symlinks
function Load-DevboxManifest { return New-DevboxManifestTemplate }
$doctorClean = Invoke-DevboxDoctor -AsObject -Quiet
$cleanSymCheck = $doctorClean.Checks | Where-Object { $_.Name -eq "Symlink Integrity" }
Assert-True ($null -ne $cleanSymCheck) "Doctor safely audits empty symlinks manifest without PropertyNotFoundException"
Assert-True ($cleanSymCheck.Status -eq "INFO") "Doctor marks empty symlinks as INFO on pristine environments"
. (Join-Path $projectRoot "core\manifest.ps1")

# Test 9: Workstation State Exporter
Write-DevboxSection "Test: Workstation State Exporter"
. (Join-Path $projectRoot "core\export.ps1")
$testExportPath = Join-Path $env:TEMP "devbox_test_export_$(Get-Random).yaml"
$exportRes = Invoke-DevboxExport -OutputPath $testExportPath -AsObject -Quiet

Assert-True (Test-Path $testExportPath) "Export command writes config file to destination"
$exportedConfig = Read-DevboxConfigFile -Path $testExportPath
Assert-True ($null -ne $exportedConfig.user) "Exported YAML contains user configuration"
Assert-True (-not [string]::IsNullOrWhiteSpace($exportedConfig.user.name)) "Exported user.name is populated"
Assert-True ($exportedConfig.preset -eq "custom") "Exported preset identifier is 'custom'"
Assert-True ($exportedConfig.modules.packages -eq $true) "Exported config enables packages module"
Assert-True ($exportedConfig.packages.Count -gt 0) "Exported config includes detected winget catalog packages"
Assert-True ($null -ne $exportedConfig.runtimes) "Exported config captures runtime configurations"
Assert-True ($null -ne $exportedConfig.fonts) "Exported config captures detected fonts"

$exportValidation = Test-DevboxConfig -Config $exportedConfig
Assert-True ($exportValidation.Valid -eq $true) "Exported YAML configuration passes schema validation"
Remove-Item -Path $testExportPath -Force -ErrorAction SilentlyContinue

# Test 10: Community Module Marketplace & Contract Verification
Write-DevboxSection "Test: Community Module Marketplace & Contract"
. (Join-Path $projectRoot "core\marketplace.ps1")

$gamingPath = Join-Path $projectRoot "modules\community\gaming.ps1"
Assert-True (Test-Path $gamingPath) "gaming.ps1 community module exists"
$gamingContract = Test-DevboxCommunityModuleContract -Path $gamingPath
Assert-True ($gamingContract.Valid -eq $true) "gaming.ps1 satisfies community module contract"
Assert-True ($gamingContract.Metadata["Name"] -eq "gaming") "gaming.ps1 metadata has name 'gaming'"
Assert-True (@($gamingContract.Metadata["Dependencies"]) -contains "packages") "gaming.ps1 depends on packages module"

$aiPath = Join-Path $projectRoot "modules\community\ai-tools.ps1"
Assert-True (Test-Path $aiPath) "ai-tools.ps1 community module exists"
$aiContract = Test-DevboxCommunityModuleContract -Path $aiPath
Assert-True ($aiContract.Valid -eq $true) "ai-tools.ps1 satisfies community module contract"
Assert-True ($aiContract.Metadata["Name"] -eq "ai-tools") "ai-tools.ps1 metadata has name 'ai-tools'"

# Test invalid module contract detection
$invalidModPath = Join-Path $env:TEMP "devbox_invalid_mod_$(Get-Random).ps1"
Set-Content -Path $invalidModPath -Value "function Do-Something { Write-Host 'Missing required contract methods' }"
$invalidContract = Test-DevboxCommunityModuleContract -Path $invalidModPath
Assert-True ($invalidContract.Valid -eq $false) "Identifies invalid contract in non-conforming module"
Assert-True (@($invalidContract.Errors).Count -gt 0) "Captures contract error details"
Remove-Item -Path $invalidModPath -Force -ErrorAction SilentlyContinue

# Test community modules discovery
$discoveredCommunity = Get-DevboxCommunityModules -RepoRoot $projectRoot
Assert-True (@($discoveredCommunity).Count -ge 2) "Discovers installed community modules (count: $(@($discoveredCommunity).Count))"
$discoveredNames = @($discoveredCommunity | ForEach-Object { $_.Name })
Assert-True ($discoveredNames -contains "gaming") "Discovered list contains gaming"
Assert-True ($discoveredNames -contains "ai-tools") "Discovered list contains ai-tools"

# Test 11: Cross-Machine Synchronization Engine
Write-DevboxSection "Test: Cross-Machine Synchronization Engine"
. (Join-Path $projectRoot "core\sync.ps1")
$syncStatus = Get-DevboxSyncStatus -RepoRoot $projectRoot
Assert-True ($null -ne $syncStatus) "Returns structured synchronization status object"
Assert-True ($syncStatus.IsGitRepo -eq $true) "Identifies git repository root"
Assert-True (-not [string]::IsNullOrWhiteSpace($syncStatus.Branch)) "Identifies active branch ($($syncStatus.Branch))"
Assert-True (-not [string]::IsNullOrWhiteSpace($syncStatus.SyncStatus)) "Assigns valid SyncStatus enum ($($syncStatus.SyncStatus))"

# Test Dry-Run Push & Pull
$syncPullDry = Invoke-DevboxSyncPull -RepoRoot $projectRoot -DryRun
Assert-True ($null -ne $syncPullDry) "Evaluates pull synchronization in dry-run mode"
$syncPushDry = Invoke-DevboxSyncPush -RepoRoot $projectRoot -DryRun
Assert-True ($null -ne $syncPushDry) "Evaluates push synchronization in dry-run mode"

# Test 12: Secure Backup & Disaster Recovery System
Write-DevboxSection "Test: Secure Backup & Disaster Recovery System"
. (Join-Path $projectRoot "core\backup.ps1")
$testBackupPath = Join-Path $env:TEMP "devbox_test_backup_suite_$(Get-Random).zip"
$backupResult = Invoke-DevboxBackup -BackupPath $testBackupPath -IncludeSSHKeys -RepoRoot $projectRoot

Assert-True (Test-Path $testBackupPath) "Backup zip archive created successfully"
Assert-True ($backupResult.Status -eq "OK") "Backup reports OK status"
Assert-True ($backupResult.FileCount -gt 0) "Backup includes workstation files (count: $($backupResult.FileCount))"

$testShaFile = "$testBackupPath.sha256"
Assert-True (Test-Path $testShaFile) "Companion .sha256 checksum file generated"
$computedSha = (Get-FileSha256 -Path $testBackupPath)
Assert-True ($computedSha -eq $backupResult.Sha256) "SHA256 checksum matches computed hash"

# Test Restore Dry-Run
$restoreDry = Invoke-DevboxRestore -BackupPath $testBackupPath -DryRun -RepoRoot $projectRoot
Assert-True ($restoreDry.Status -eq "OK") "Restore dry-run succeeds"
Assert-True (@($restoreDry.RestoredFiles).Count -gt 0) "Restore identifies files to restore"

# Clean up test archive
Remove-Item -Path $testBackupPath -Force -ErrorAction SilentlyContinue
Remove-Item -Path $testShaFile -Force -ErrorAction SilentlyContinue

# Test 13: Lightweight Visual Dashboard Generator
Write-DevboxSection "Test: Visual Dashboard Generator"
. (Join-Path $projectRoot "core\dashboard.ps1")
$testDashboardPath = Join-Path $env:TEMP "devbox_test_dashboard_$(Get-Random).html"
$dashboardResult = New-DevboxDashboardHtml -RepoRoot $projectRoot -DestinationPath $testDashboardPath

Assert-True (Test-Path $testDashboardPath) "Dashboard HTML file generated at target path"
$dashContent = Get-Content -Path $testDashboardPath -Raw -Encoding utf8
Assert-True ($dashContent -match "<!DOCTYPE html>") "Dashboard contains valid HTML5 DOCTYPE"
Assert-True ($dashContent -match "devbox-win :: Workstation Dashboard") "Dashboard contains expected title"
Assert-True ($dashContent -match "tab-overview" -and $dashContent -match "tab-doctor") "Dashboard contains tab navigation"
Assert-True ($dashContent -match "<svg class=""icon""") "Dashboard contains vector SVG icons"
Assert-True (-not ($dashContent -match "[\uD83C-\uDBFF\uDC00-\uDFFF]")) "Dashboard contains ZERO emojis (adheres to design standard)"
Remove-Item -Path $testDashboardPath -Force -ErrorAction SilentlyContinue

# Test 14: Zed Editor and Author Signature Rice Validation
Write-DevboxSection "Test: Zed Editor and Author Signature Rice"
$packagesScript = Get-Content -Path (Join-Path $projectRoot "modules\packages.ps1") -Raw -Encoding utf8
Assert-True ($packagesScript -match '"Zed\.Zed"') "Package catalog in modules/packages.ps1 contains Zed.Zed"

$exportScript = Get-Content -Path (Join-Path $projectRoot "core\export.ps1") -Raw -Encoding utf8
Assert-True ($exportScript -match '"Zed\.Zed"') "Export engine catalog contains Zed.Zed"

$zedSettingsPath = Join-Path $projectRoot "dotfiles\zed\settings.json"
Assert-True (Test-Path $zedSettingsPath) "dotfiles/zed/settings.json exists on disk"
$zedSettingsJson = Get-Content -Path $zedSettingsPath -Raw -Encoding utf8 | ConvertFrom-Json
Assert-True ($zedSettingsJson.buffer_font_family -eq "JetBrainsMono Nerd Font") "Zed settings use JetBrainsMono Nerd Font"
Assert-True ($null -ne $zedSettingsJson.theme.dark -and $zedSettingsJson.theme.dark -match "Catppuccin") "Zed settings use Catppuccin theme"
Assert-True ($zedSettingsJson.terminal.shell.program -eq "pwsh.exe") "Zed settings use pwsh terminal"

# Editor module dry-run
$editorDryRes = & (Join-Path $projectRoot "modules\editor.ps1") -Config @{ editor = @{ sync_settings = $true; install_extensions = $false } } -DryRun
Assert-True ($editorDryRes.Status -eq "OK") "Editor module dry-run succeeds for VS Code and Zed"

# Zebar dotfiles & packs
$zebarSettingsPath = Join-Path $projectRoot "dotfiles\zebar\settings.json"
Assert-True (Test-Path $zebarSettingsPath) "dotfiles/zebar/settings.json exists on disk"
$zebarNordPath = Join-Path $projectRoot "dotfiles\zebar\packs\nord\zpack.json"
Assert-True (Test-Path $zebarNordPath) "dotfiles/zebar/packs/nord/zpack.json exists"

# Zebar module dry-run
$zebarDryRes = & (Join-Path $projectRoot "modules\zebar.ps1") -Config @{ zebar = @{ install = $false; autostart = $false } } -DryRun
Assert-True ($zebarDryRes.Status -in @("OK", "SKIP")) "Zebar module dry-run executes successfully"

# GlazeWM live dotfile verification
$glazeConfigPath = Join-Path $projectRoot "dotfiles\glazewm\config.yaml"
$glazeConfigText = Get-Content -Path $glazeConfigPath -Raw -Encoding utf8
Assert-True ($glazeConfigText -match 'hide_method:\s*"cloak"') "GlazeWM config features DWM cloaking"
Assert-True ($glazeConfigText -match '#cba6f7') "GlazeWM config features Catppuccin lavender border"

# Test 15: Session Package Cache and Atomic Persistence
Write-DevboxSection "Test: Session Package Cache and Persistence"
$pkgSet = Get-DevboxInstalledPackageSet
Assert-True ($null -ne $pkgSet) "Package cache initializes successfully"
$testFastPkg = Test-DevboxPackageInstalledFast -PackageId "NonExistentPackage_99999"
Assert-True ($testFastPkg -eq $false) "Fast package test handles missing packages gracefully"

# Test 16: Windows Developer Utility GUI (WPF XAML)
Write-DevboxSection "Test: Windows Developer Utility GUI (WPF)"
$guiPath = Join-Path $projectRoot "core\gui.ps1"
Assert-True (Test-Path $guiPath) "core/gui.ps1 exists on disk"

# Headless WPF GUI Initialization Test Group
$guiErr = $null
$guiExecRes = $null
try {
    $guiExecRes = & $guiPath -RepoRoot $projectRoot -NoShow
} catch {
    $guiErr = $_
}
Assert-True ($null -eq $guiErr) "Invoking core/gui.ps1 with -NoShow completes with zero errors"
Assert-True ($null -ne $guiExecRes -and $guiExecRes.Action -eq "Cancel") "GUI returns default cancel state in headless mode"

$guiDotResult = . $guiPath -RepoRoot $projectRoot -Preset "belal-catppuccin" -NoShow
Assert-True ($null -ne $script:DevboxGuiWindow) "WPF window object DevboxGuiWindow is instantiated"
Assert-True ($null -ne $chk_zed) "Checkbox chk_zed exists and is resolved"
Assert-True ($null -ne $chk_glazewm) "Checkbox chk_glazewm exists and is resolved"
Assert-True ($null -ne $chk_starship) "Checkbox chk_starship exists and is resolved"
Assert-True ($null -ne $chk_node) "Checkbox chk_node exists and is resolved"
Assert-True ($null -ne $chk_docker) "Checkbox chk_docker exists and is resolved"
Assert-True ($chk_zed.IsChecked -eq $true) "Preset belal-catppuccin marks chk_zed as checked"
Assert-True ($chk_glazewm.IsChecked -eq $true) "Preset belal-catppuccin marks chk_glazewm as checked"

# Modern 2-Column Sidebar & Live Package Detection Verification Group
Assert-True ($null -ne $btnScanInstalled) "Scan button btnScanInstalled exists and is resolved"
Assert-True ($null -ne $txtSearch) "Search input txtSearch exists and is resolved"
Assert-True ($null -ne $btnNavToolchain) "Sidebar navigation button btnNavToolchain exists and is resolved"
Assert-True ($null -ne $btnNavTiling) "Sidebar navigation button btnNavTiling exists and is resolved"
Assert-True ($null -ne $btnNavRuntimes) "Sidebar navigation button btnNavRuntimes exists and is resolved"
Assert-True ($null -ne $badge_zed) "Status badge badge_zed exists and is resolved"
Assert-True ($null -ne $badge_vscode) "Status badge badge_vscode exists and is resolved"
Assert-True ($null -ne $badge_docker) "Status badge badge_docker exists and is resolved"

$badgeScanErr = $null
try {
    Update-PackageInstallBadges
} catch {
    $badgeScanErr = $_.Exception.Message
}
Assert-True ($null -eq $badgeScanErr) "Update-PackageInstallBadges executes without exception"
Assert-True ($badge_zed.Text -in @("INSTALLED", "AVAILABLE")) "Badge text evaluates to valid status enum (INSTALLED or AVAILABLE)"

# Preset State Switching Verification
Apply-PresetState "minimal"
Assert-True ($chk_terminal.IsChecked -eq $true -and $chk_zed.IsChecked -eq $false -and $chk_docker.IsChecked -eq $false) "Apply-PresetState minimal sets expected minimal checkboxes"

Apply-PresetState "catppuccin"
Assert-True ($chk_zed.IsChecked -eq $true -and $chk_glazewm.IsChecked -eq $true -and $chk_docker.IsChecked -eq $true) "Apply-PresetState catppuccin sets expected signature rice checkboxes"

# Compiled Config Verification from UI
$uiCompiledConfig = Get-CompiledConfigFromUI
Assert-True ($null -ne $uiCompiledConfig) "Get-CompiledConfigFromUI returns non-null configuration"
Assert-True ($uiCompiledConfig.packages.Count -gt 0) "Get-CompiledConfigFromUI compiles selected packages count"
Assert-True ($uiCompiledConfig.modules.packages -eq $true) "Get-CompiledConfigFromUI marks packages module enabled"
Assert-True ($uiCompiledConfig.editor.primary -eq "zed") "Get-CompiledConfigFromUI sets primary editor"
Assert-True ($uiCompiledConfig.glazewm.hide_method -eq "cloak") "Get-CompiledConfigFromUI sets GlazeWM hide_method"

$dummyConfig = [ordered]@{
    user = [ordered]@{ name = "TestUser"; email = "test@domain.com"; github_username = "testgit" }
    preset = "belal-catppuccin"
    modules = [ordered]@{ packages = $true; fonts = $true; git = $true; shell = $true; editor = $true; runtimes = $true; databases = $true; envvars = $true; keybindings = $true; glazewm = $true; zebar = $true; dotfiles = $true }
    packages = @("Zed.Zed", "Git.Git")
    databases = @("PostgreSQL.PostgreSQL")
    community_modules = @("ai-tools")
    editor = [ordered]@{ primary = "zed"; sync_settings = $true; install_extensions = $true }
    git = [ordered]@{ default_branch = "main"; autocrlf = "input"; generate_ssh_key = $true; ssh_key_type = "ed25519" }
    runtimes = [ordered]@{ node = $true; python = $true; rust = $false; dotnet = $false }
    glazewm = [ordered]@{ install = $true; autostart = $true; hide_method = "cloak"; border_color = "#cba6f7" }
    zebar = [ordered]@{ install = $true; autostart = $true; pack = "nord" }
}

$tmpGuiYaml = Join-Path $env:TEMP "test_gui_export_$([System.Guid]::NewGuid().ToString('N').Substring(0,8)).yaml"
Export-GuiConfigToYamlFile -Config $dummyConfig -Path $tmpGuiYaml
Assert-True (Test-Path $tmpGuiYaml) "GUI exported YAML exists on disk"
$parsedGuiYaml = Read-DevboxConfigFile -Path $tmpGuiYaml -SkipPresetResolution
Assert-True ($parsedGuiYaml.user.name -eq "TestUser") "GUI exported YAML parses user.name"
Assert-True ($parsedGuiYaml.preset -eq "belal-catppuccin") "GUI exported YAML parses preset"
Assert-True ($parsedGuiYaml.packages.Count -eq 2) "GUI exported YAML parses packages count"
Remove-Item -Path $tmpGuiYaml -Force -ErrorAction SilentlyContinue

# Test 17: Core Winget Package Engine and Custom Install Paths
Write-DevboxSection "Test: Core Winget Package Engine and Custom Install Paths"
$dryRunRes = Install-DevboxWingetPackage -PackageId "NonExistent.MockPackage.999" -Location "D:\CustomTools" -DryRun
Assert-True ($dryRunRes.Success -eq $true -and $dryRunRes.DryRun -eq $true) "Install-DevboxWingetPackage dry-run succeeds"
Assert-True ($dryRunRes.Location -eq "D:\CustomTools") "Install-DevboxWingetPackage respects custom --location in dry-run"

# Test package already installed fast
$dummyInstalledId = "Existing.MockPackage.111"
$null = Get-DevboxInstalledPackageSet
if ($null -ne $global:DevboxInstalledPackageCache) {
    [void]$global:DevboxInstalledPackageCache.Add($dummyInstalledId)
}
$alreadyInstalledRes = Install-DevboxWingetPackage -PackageId $dummyInstalledId -Location "D:\CustomTools"
Assert-True ($alreadyInstalledRes.Success -eq $true -and $alreadyInstalledRes.Skipped -eq $true) "Install-DevboxWingetPackage skips already installed packages"

# Test 18: GUI Config Compiler Custom Path & XAML Components
Write-DevboxSection "Test: GUI Config Compiler and Custom Path Components"
$guiContent = Get-Content -Path $guiPath -Raw -Encoding utf8
Assert-True ($guiContent -match 'x:Name="txtCustomPath"') "core/gui.ps1 XAML contains txtCustomPath TextBox"
Assert-True ($guiContent -match 'x:Name="btnBrowsePath"') "core/gui.ps1 XAML contains btnBrowsePath Button"

$dummyConfigWithPaths = [ordered]@{
    user = [ordered]@{ name = "TestUser"; email = "test@domain.com"; github_username = "testgit" }
    preset = "custom"
    paths = [ordered]@{ apps = "D:\DevBoxTools" }
    install_location = "D:\DevBoxTools"
    modules = [ordered]@{ packages = $true; fonts = $true; git = $true; shell = $true; editor = $true; runtimes = $true; databases = $true; envvars = $true; keybindings = $true; glazewm = $true; zebar = $true; dotfiles = $true }
    packages = @("Zed.Zed")
    databases = @()
    community_modules = @()
    editor = [ordered]@{ primary = "zed"; sync_settings = $true; install_extensions = $true }
    git = [ordered]@{ default_branch = "main"; autocrlf = "input"; generate_ssh_key = $true; ssh_key_type = "ed25519" }
    runtimes = [ordered]@{ node = $true; python = $true; rust = $false; dotnet = $false }
    glazewm = [ordered]@{ install = $true; autostart = $true; hide_method = "cloak"; border_color = "#cba6f7" }
    zebar = [ordered]@{ install = $true; autostart = $true; pack = "nord" }
}

$tmpGuiYaml2 = Join-Path $env:TEMP "test_gui_custom_path_$([System.Guid]::NewGuid().ToString('N').Substring(0,8)).yaml"
Export-GuiConfigToYamlFile -Config $dummyConfigWithPaths -Path $tmpGuiYaml2
Assert-True (Test-Path $tmpGuiYaml2) "GUI exported YAML with paths exists"
$parsedGuiYaml2 = Read-DevboxConfigFile -Path $tmpGuiYaml2 -SkipPresetResolution
Assert-True ($parsedGuiYaml2.paths.apps -eq "D:\DevBoxTools") "GUI config compiler correctly captures paths.apps"
Assert-True ($parsedGuiYaml2.install_location -eq "D:\DevBoxTools") "GUI config compiler correctly captures install_location"
Remove-Item -Path $tmpGuiYaml2 -Force -ErrorAction SilentlyContinue

# Test 19: CLI Parameters and Engine Install Location
Write-DevboxSection "Test: CLI Parameters and Engine Install Location"
$engineCmd = Get-Command (Join-Path $projectRoot "core\engine.ps1")
Assert-True ($engineCmd.Parameters.ContainsKey("InstallLocation")) "core/engine.ps1 accepts -InstallLocation parameter"

$bootCmd = Get-Command (Join-Path $projectRoot "bootstrap.ps1")
Assert-True ($bootCmd.Parameters.ContainsKey("InstallLocation")) "bootstrap.ps1 accepts -InstallLocation parameter"

$engineDryOutput = & pwsh -NoProfile -File (Join-Path $projectRoot "core\engine.ps1") -ConfigFile (Join-Path $projectRoot "config.example.yaml") -InstallLocation "E:\EngineCustomPath" -Module "packages" -DryRun 2>&1 | Out-String
Assert-True ($engineDryOutput -match "DRY RUN MODE ENABLED") "Engine executes with -InstallLocation in dry-run mode"

# Test 20: Manifest Safe Operations and Type Resilience
Write-DevboxSection "Test: Manifest Safe Operations and Type Resilience"

$realManifestPath = Get-DevboxManifestPath
$originalManifestContent = $null
if (Test-Path $realManifestPath) {
    $originalManifestContent = Get-Content -Path $realManifestPath -Raw -Encoding utf8
}

try {
    # Initialize a test manifest with object[] arrays simulating deserialized JSON
    $testManifest = [ordered]@{
        schemaVersion = "1.0.0"
        createdAt     = (Get-Date -Format "o")
        updatedAt     = (Get-Date -Format "o")
        symlinks      = [object[]]@()
        packages      = [object[]]@("Git.Git", "Microsoft.WindowsTerminal")
        envvars       = [object[]]@(
            [ordered]@{ name = "EXISTING_VAR"; previousValue = "old"; timestamp = "2026-01-01" }
        )
        shortcuts     = [object[]]@("C:\Users\test\Desktop\existing.lnk")
    }

    # Verify Add-DevboxManifestPackage records package without constructor overload error
    $pkgAddError = $null
    try {
        Add-DevboxManifestPackage -Manifest $testManifest -PackageId "Zed.Zed"
    } catch {
        $pkgAddError = $_.Exception.Message
    }
    Assert-True ($null -eq $pkgAddError) "Add-DevboxManifestPackage adds package without constructor error in PS7"
    Assert-True ($testManifest["packages"] -contains "Zed.Zed") "Manifest packages collection contains added package"

    # Verify idempotency (duplicate prevention)
    Add-DevboxManifestPackage -Manifest $testManifest -PackageId "Zed.Zed"
    $zedCount = @($testManifest["packages"] | Where-Object { $_ -eq "Zed.Zed" }).Count
    Assert-True ($zedCount -eq 1) "Add-DevboxManifestPackage prevents duplicate package IDs"

    # Verify Add-DevboxManifestShortcut
    $scAddError = $null
    try {
        Add-DevboxManifestShortcut -Manifest $testManifest -Path "C:\Users\test\Desktop\new.lnk"
    } catch {
        $scAddError = $_.Exception.Message
    }
    Assert-True ($null -eq $scAddError) "Add-DevboxManifestShortcut adds shortcut without constructor error"
    Assert-True ($testManifest["shortcuts"] -contains "C:\Users\test\Desktop\new.lnk") "Manifest shortcuts collection contains added shortcut"

    # Verify Add-DevboxManifestShortcut idempotency
    Add-DevboxManifestShortcut -Manifest $testManifest -Path "C:\Users\test\Desktop\new.lnk"
    $scCount = @($testManifest["shortcuts"] | Where-Object { $_ -eq "C:\Users\test\Desktop\new.lnk" }).Count
    Assert-True ($scCount -eq 1) "Add-DevboxManifestShortcut prevents duplicate shortcut paths"

    # Verify Add-DevboxManifestEnvVar
    $envAddError = $null
    try {
        Add-DevboxManifestEnvVar -Manifest $testManifest -Name "DEVBOX_TEST_ENV" -PreviousValue "previous_val"
    } catch {
        $envAddError = $_.Exception.Message
    }
    Assert-True ($null -eq $envAddError) "Add-DevboxManifestEnvVar adds env var safely"
    $matchingEnv = @($testManifest["envvars"] | Where-Object { $_.name -eq "DEVBOX_TEST_ENV" })
    Assert-True ($matchingEnv.Count -eq 1) "Manifest envvars contains new environment variable"
    Assert-True ($matchingEnv[0].previousValue -eq "previous_val") "Manifest envvars records previousValue"

    # Verify Add-DevboxManifestEnvVar updates existing name without duplicating
    Add-DevboxManifestEnvVar -Manifest $testManifest -Name "DEVBOX_TEST_ENV" -PreviousValue "updated_val"
    $matchingEnvAfter = @($testManifest["envvars"] | Where-Object { $_.name -eq "DEVBOX_TEST_ENV" })
    Assert-True ($matchingEnvAfter.Count -eq 1) "Add-DevboxManifestEnvVar replaces existing envvar entry"
    Assert-True ($matchingEnvAfter[0].previousValue -eq "updated_val") "Updated envvar entry contains latest value"

    # Verify Add-DevboxManifestSymlink safe operations
    $symAddError = $null
    try {
        Add-DevboxManifestSymlink -Manifest $testManifest -Destination "C:\dst\file.txt" -Source "D:\src\file.txt" -BackupPath "C:\bak\file.txt"
    } catch {
        $symAddError = $_.Exception.Message
    }
    Assert-True ($null -eq $symAddError) "Add-DevboxManifestSymlink adds symlink entry safely"
    $matchingSym = @($testManifest["symlinks"] | Where-Object { $_.destination -eq "C:\dst\file.txt" })
    Assert-True ($matchingSym.Count -eq 1) "Manifest symlinks contains new symlink"
} finally {
    # Restore original manifest content if it existed
    if ($null -ne $originalManifestContent) {
        Set-Content -Path $realManifestPath -Value $originalManifestContent -Encoding utf8
    }
}

# Test 21: Bootstrap GUI Launch Decision Logic
Write-DevboxSection "Test: Bootstrap GUI Launch Decision Logic"

# Helper reproducing bootstrap.ps1 decision formula exactly:
function Test-BootstrapGuiCondition {
    param(
        [bool]$UserInteractive,
        [bool]$NonInteractive,
        [bool]$Silent,
        [bool]$GuiScriptExists,
        [bool]$IsCliMaintenance,
        [int]$EngineParamsCount,
        [bool]$Gui,
        [string]$Preset
    )
    $isInteractiveCLI = (-not $NonInteractive) -and (-not $Silent) -and $UserInteractive
    return [bool]($isInteractiveCLI -and $GuiScriptExists -and (-not $IsCliMaintenance) -and (($EngineParamsCount -eq 0) -or $Gui -or ($Preset -and -not $NonInteractive)))
}

# 1. Interactive session with -Preset launches GUI
$dec1 = Test-BootstrapGuiCondition -UserInteractive $true -NonInteractive $false -Silent $false -GuiScriptExists $true -IsCliMaintenance $false -EngineParamsCount 1 -Gui $false -Preset "minimal"
Assert-True ($dec1 -eq $true) "Interactive session with -Preset launches GUI"

# 2. Interactive session with -Preset and -NonInteractive bypasses GUI
$dec2 = Test-BootstrapGuiCondition -UserInteractive $true -NonInteractive $true -Silent $false -GuiScriptExists $true -IsCliMaintenance $false -EngineParamsCount 1 -Gui $false -Preset "minimal"
Assert-True ($dec2 -eq $false) "Session with -Preset and -NonInteractive bypasses GUI"

# 3. Interactive session with -Preset and -Silent bypasses GUI
$dec3 = Test-BootstrapGuiCondition -UserInteractive $true -NonInteractive $false -Silent $true -GuiScriptExists $true -IsCliMaintenance $false -EngineParamsCount 1 -Gui $false -Preset "minimal"
Assert-True ($dec3 -eq $false) "Session with -Preset and -Silent bypasses GUI"

# 4. Non-interactive console (UserInteractive = false) bypasses GUI
$dec4 = Test-BootstrapGuiCondition -UserInteractive $false -NonInteractive $false -Silent $false -GuiScriptExists $true -IsCliMaintenance $false -EngineParamsCount 1 -Gui $false -Preset "minimal"
Assert-True ($dec4 -eq $false) "Non-interactive host with -Preset bypasses GUI"

# 5. Interactive session with maintenance command (-Doctor) bypasses GUI
$dec5 = Test-BootstrapGuiCondition -UserInteractive $true -NonInteractive $false -Silent $false -GuiScriptExists $true -IsCliMaintenance $true -EngineParamsCount 1 -Gui $false -Preset "minimal"
Assert-True ($dec5 -eq $false) "Interactive session with CLI maintenance command bypasses GUI"

# 6. Interactive session with zero arguments launches GUI
$dec6 = Test-BootstrapGuiCondition -UserInteractive $true -NonInteractive $false -Silent $false -GuiScriptExists $true -IsCliMaintenance $false -EngineParamsCount 0 -Gui $false -Preset ""
Assert-True ($dec6 -eq $true) "Interactive session with zero arguments launches GUI"

# Test 22: PowerShell AST Syntax Validation
$allScripts = Get-ChildItem -Path $projectRoot -Filter "*.ps1" -Recurse
foreach ($s in $allScripts) {
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($s.FullName, [ref]$tokens, [ref]$parseErrors)
    $hasErrors = ($parseErrors -and $parseErrors.Count -gt 0)
    $relPath = $s.FullName.Substring($projectRoot.Length).TrimStart('\', '/')
    Assert-True (-not $hasErrors) "AST Syntax valid: $relPath"
}

# Final Test Report
Write-Host ""
Write-Host "=============================================================================="
Write-Host "  Test Suite Results: $passCount passed, $failCount failed"
Write-Host "=============================================================================="
if ($failCount -gt 0) {
    exit 1
} else {
    exit 0
}
