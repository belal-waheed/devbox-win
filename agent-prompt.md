# devbox-win Agent Deployment Prompt

You are an AI coding assistant (Antigravity, Cursor, Claude Code, or GitHub Copilot) executing a deterministic, non-destructive deployment of the `devbox-win` configuration suite on this Windows workstation.

Follow the four phases sequentially. Do not skip phases or execute destructive commands without user confirmation.

---

## Workspace Context
- Root Directory: Current repository root (`devbox-win/`)
- Configurations Directory: `configs/`

---

## Phase 1: Pre-Flight Safety & Deterministic Snapshot

Before touching or overwriting any file on this machine, create a full atomic backup with an automated restore script.

### 1.1 Discover Existing Target Files
Check whether configuration files already exist at each target destination:

| Module | Target Path |
| :--- | :--- |
| VS Code Settings | `$env:APPDATA\Code\User\settings.json` |
| VS Code Keybindings | `$env:APPDATA\Code\User\keybindings.json` |
| VS Code Snippets | `$env:APPDATA\Code\User\snippets\` |
| GlazeWM | `$env:USERPROFILE\.glzr\glazewm\config.yaml` |
| Zebar | `$env:USERPROFILE\.glzr\zebar\` |
| Windows Terminal | `$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` |
| Starship | `$env:USERPROFILE\.config\starship.toml` |
| PowerShell 7 Profile | `$PROFILE.CurrentUserCurrentHost` (or `$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`) |
| AutoHotkey v2 | `$env:USERPROFILE\.config\ahk\hotkeys.ahk` |
| Git Config | `$env:USERPROFILE\.gitconfig` |
| Git Global Ignore | `$env:USERPROFILE\.gitignore_global` |
| Antigravity Global Rules | `$env:USERPROFILE\.gemini\GEMINI.md` |
| Antigravity MCP Config | `$env:USERPROFILE\.gemini\config\mcp_config.json` |
| Antigravity Skills | `$env:USERPROFILE\.gemini\config\skills\` |
| Obsidian Vault | `<VaultRoot>\.obsidian\` (Default: `$env:USERPROFILE\Documents\Vault\.obsidian`) |

### 1.2 Create Atomic Backup Bundle
Run the following PowerShell command to snapshot all existing files:

```powershell
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = Join-Path $env:USERPROFILE ".devbox-backups\backup-$timestamp"
$zipPath   = Join-Path $env:USERPROFILE ".devbox-backups\backup-$timestamp.zip"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

$manifest = @{}

# Map and copy existing files
$targets = @(
    @{ Key = "vscode_settings"; Path = "$env:APPDATA\Code\User\settings.json" },
    @{ Key = "vscode_keybindings"; Path = "$env:APPDATA\Code\User\keybindings.json" },
    @{ Key = "glazewm_config"; Path = "$env:USERPROFILE\.glzr\glazewm\config.yaml" },
    @{ Key = "starship_config"; Path = "$env:USERPROFILE\.config\starship.toml" },
    @{ Key = "pwsh_profile"; Path = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" },
    @{ Key = "git_config"; Path = "$env:USERPROFILE\.gitconfig" },
    @{ Key = "git_ignore"; Path = "$env:USERPROFILE\.gitignore_global" },
    @{ Key = "antigravity_rules"; Path = "$env:USERPROFILE\.gemini\GEMINI.md" }
)

foreach ($t in $targets) {
    if (Test-Path $t.Path) {
        $subDir = Join-Path $backupDir $t.Key
        New-Item -ItemType Directory -Path $subDir -Force | Out-Null
        Copy-Item -Path $t.Path -Destination $subDir -Force
        $manifest[$t.Key] = @{
            OriginalPath = $t.Path
            BackupFile   = Join-Path $subDir (Split-Path $t.Path -Leaf)
        }
    }
}

# Save manifest.json
$manifestPath = Join-Path $backupDir "manifest.json"
$manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestPath -Encoding UTF8

# Generate deterministic restore script
$restoreScript = @'
[CmdletBinding()]
param()
$manifestFile = Join-Path $PSScriptRoot "manifest.json"
if (-not (Test-Path $manifestFile)) {
    Write-Error "manifest.json not found in $PSScriptRoot"
    exit 1
}
$manifest = Get-Content $manifestFile -Raw | ConvertFrom-Json
foreach ($prop in $manifest.PSObject.Properties) {
    $entry = $prop.Value
    if (Test-Path $entry.BackupFile) {
        $targetDir = Split-Path $entry.OriginalPath -Parent
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        Copy-Item -Path $entry.BackupFile -Destination $entry.OriginalPath -Force
        Write-Host "Restored: $($entry.OriginalPath)" -ForegroundColor Green
    }
}
'@
Set-Content -Path (Join-Path $backupDir "restore.ps1") -Value $restoreScript -Encoding UTF8

# Compress backup
Compress-Archive -Path "$backupDir\*" -DestinationPath $zipPath -Force
Write-Host "Pre-flight snapshot verified: $zipPath" -ForegroundColor Cyan
```

---

## Phase 2: Configuration Linking & Deployment

### 2.1 Developer Mode & Symlink Capability Check
Check if unprivileged symbolic link creation is enabled on this machine:

```powershell
$testSource = [System.IO.Path]::GetTempFileName()
$testLink   = "$testSource.link"
$symlinkSupported = $false

try {
    New-Item -ItemType SymbolicLink -Path $testLink -Target $testSource -ErrorAction Stop | Out-Null
    $symlinkSupported = $true
    Remove-Item $testLink -Force -ErrorAction SilentlyContinue
} catch {
    $symlinkSupported = $false
} finally {
    Remove-Item $testSource -Force -ErrorAction SilentlyContinue
}

if ($symlinkSupported) {
    Write-Host "Symbolic link support detected (Developer Mode enabled)." -ForegroundColor Green
} else {
    Write-Host "Notice: Developer Mode disabled. Deploying via direct file copy." -ForegroundColor Yellow
}
```

### 2.2 Deploy Configurations
Execute the deployment mapping according to the table below. If `$symlinkSupported` is `$true`, use `New-Item -ItemType SymbolicLink -Force`. Otherwise, use `Copy-Item -Recurse -Force`.

```powershell
function Deploy-ConfigItem {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [bool]$UseSymlink
    )
    $parent = Split-Path $DestinationPath -Parent
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if (Test-Path $DestinationPath) {
        Remove-Item $DestinationPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($UseSymlink) {
        New-Item -ItemType SymbolicLink -Path $DestinationPath -Target (Resolve-Path $SourcePath).Path -Force | Out-Null
    } else {
        Copy-Item -Path $SourcePath -Destination $DestinationPath -Recurse -Force
    }
}

$repoRoot = (Resolve-Path .).Path
$configsRoot = Join-Path $repoRoot "configs"

# 1. VS Code
Deploy-ConfigItem "$configsRoot\vscode\settings.json" "$env:APPDATA\Code\User\settings.json" $symlinkSupported
Deploy-ConfigItem "$configsRoot\vscode\keybindings.json" "$env:APPDATA\Code\User\keybindings.json" $symlinkSupported
Deploy-ConfigItem "$configsRoot\vscode\snippets" "$env:APPDATA\Code\User\snippets" $symlinkSupported

# 2. GlazeWM & Zebar
Deploy-ConfigItem "$configsRoot\tiling\glazewm\config.yaml" "$env:USERPROFILE\.glzr\glazewm\config.yaml" $symlinkSupported
Deploy-ConfigItem "$configsRoot\tiling\glazewm\Launch-GPU.vbs" "$env:USERPROFILE\.glzr\Launch-GPU.vbs" $symlinkSupported
Deploy-ConfigItem "$configsRoot\tiling\glazewm\Restart-Zebar.vbs" "$env:USERPROFILE\.glzr\Restart-Zebar.vbs" $symlinkSupported
Deploy-ConfigItem "$configsRoot\tiling\glazewm\Update-GPU.ps1" "$env:USERPROFILE\.glzr\Update-GPU.ps1" $symlinkSupported
Deploy-ConfigItem "$configsRoot\tiling\zebar\config.yaml" "$env:USERPROFILE\.glzr\zebar\config.yaml" $symlinkSupported
Deploy-ConfigItem "$configsRoot\tiling\zebar\settings.json" "$env:USERPROFILE\.glzr\zebar\settings.json" $symlinkSupported
Deploy-ConfigItem "$configsRoot\tiling\zebar\packs" "$env:USERPROFILE\.glzr\zebar\packs" $symlinkSupported

# 3. Terminal & Shell
$wtPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path (Split-Path $wtPath -Parent)) {
    Deploy-ConfigItem "$configsRoot\terminal\windows-terminal.json" $wtPath $symlinkSupported
}
Deploy-ConfigItem "$configsRoot\terminal\starship.toml" "$env:USERPROFILE\.config\starship.toml" $symlinkSupported
Deploy-ConfigItem "$configsRoot\terminal\Microsoft.PowerShell_profile.ps1" "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" $symlinkSupported

# 4. Shortcuts
Deploy-ConfigItem "$configsRoot\shortcuts\hotkeys.ahk" "$env:USERPROFILE\.config\ahk\hotkeys.ahk" $symlinkSupported

# 5. Git
Deploy-ConfigItem "$configsRoot\git\.gitconfig" "$env:USERPROFILE\.gitconfig" $symlinkSupported
Deploy-ConfigItem "$configsRoot\git\.gitignore_global" "$env:USERPROFILE\.gitignore_global" $symlinkSupported
git config --global core.excludesfile "$env:USERPROFILE\.gitignore_global"

# 6. Antigravity AI
Deploy-ConfigItem "$configsRoot\antigravity\rules\user_global.md" "$env:USERPROFILE\.gemini\GEMINI.md" $symlinkSupported
Deploy-ConfigItem "$configsRoot\antigravity\skills" "$env:USERPROFILE\.gemini\config\skills" $symlinkSupported

# 7. Obsidian Vault
$vaultRoot = if ($env:OBSIDIAN_VAULT_ROOT) { $env:OBSIDIAN_VAULT_ROOT } else { "$env:USERPROFILE\Documents\Vault" }
if (-not (Test-Path $vaultRoot)) {
    New-Item -ItemType Directory -Path $vaultRoot -Force | Out-Null
}
Deploy-ConfigItem "$configsRoot\obsidian\app.json" "$vaultRoot\.obsidian\app.json" $symlinkSupported
Deploy-ConfigItem "$configsRoot\obsidian\appearance.json" "$vaultRoot\.obsidian\appearance.json" $symlinkSupported
Deploy-ConfigItem "$configsRoot\obsidian\community-plugins.json" "$vaultRoot\.obsidian\community-plugins.json" $symlinkSupported
Deploy-ConfigItem "$configsRoot\obsidian\core-plugins.json" "$vaultRoot\.obsidian\core-plugins.json" $symlinkSupported
Deploy-ConfigItem "$configsRoot\obsidian\hotkeys.json" "$vaultRoot\.obsidian\hotkeys.json" $symlinkSupported
Deploy-ConfigItem "$configsRoot\obsidian\snippets" "$vaultRoot\.obsidian\snippets" $symlinkSupported
Deploy-ConfigItem "$configsRoot\obsidian\plugins" "$vaultRoot\.obsidian\plugins" $symlinkSupported
```

---

## Phase 3: Toolchain & Extension Verification

Install curated VS Code extensions listed in `configs/vscode/extensions.txt`:

```powershell
if (Get-Command "code" -ErrorAction SilentlyContinue) {
    $extensionsFile = "$configsRoot\vscode\extensions.txt"
    if (Test-Path $extensionsFile) {
        $extensions = Get-Content $extensionsFile | Where-Object { $_ -match '^\w+' -and $_ -notmatch '^#' }
        foreach ($ext in $extensions) {
            Write-Host "Installing VS Code extension: $ext"
            code --install-extension $ext --force
        }
    }
}
```

---

## Phase 4: Verification & Health Check

Inspect the deployed state and print a clean verification table:

```powershell
$statusList = @(
    @{ Name = "VS Code Settings"; Path = "$env:APPDATA\Code\User\settings.json" },
    @{ Name = "VS Code Keybindings"; Path = "$env:APPDATA\Code\User\keybindings.json" },
    @{ Name = "GlazeWM Config"; Path = "$env:USERPROFILE\.glzr\glazewm\config.yaml" },
    @{ Name = "Zebar Config"; Path = "$env:USERPROFILE\.glzr\zebar\config.yaml" },
    @{ Name = "Windows Terminal"; Path = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" },
    @{ Name = "Starship Prompt"; Path = "$env:USERPROFILE\.config\starship.toml" },
    @{ Name = "PowerShell 7 Profile"; Path = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" },
    @{ Name = "AutoHotkey v2 Hotkeys"; Path = "$env:USERPROFILE\.config\ahk\hotkeys.ahk" },
    @{ Name = "Global Git Config"; Path = "$env:USERPROFILE\.gitconfig" },
    @{ Name = "Global Git Ignore"; Path = "$env:USERPROFILE\.gitignore_global" },
    @{ Name = "Antigravity Global Rules"; Path = "$env:USERPROFILE\.gemini\GEMINI.md" },
    @{ Name = "Obsidian Base Config"; Path = "$vaultRoot\.obsidian\app.json" }
)

Write-Host "`n=== devbox-win Deployment Health Check ===" -ForegroundColor Cyan
foreach ($item in $statusList) {
    $exists = Test-Path $item.Path
    $isLink = if ($exists) { (Get-Item $item.Path).LinkType -ne $null } else { $false }
    $typeStr = if ($isLink) { "Symlink" } elseif ($exists) { "Direct File" } else { "Missing" }
    $color   = if ($exists) { "Green" } else { "Red" }
    Write-Host ("[{0,-7}] {1,-26} -> {2}" -f $typeStr, $item.Name, $item.Path) -ForegroundColor $color
}
Write-Host "=========================================`n" -ForegroundColor Cyan
```
