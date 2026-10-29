# ==============================================================================
# devbox-win :: Core Interactive Setup Wizard
# Path: core/wizard.ps1
# Description: Modern ANSI cursor-driven first-time setup wizard for config.yaml.
# Standard: Zero emojis. Keyboard-navigable multi-select with fallback streams.
# ==============================================================================

[CmdletBinding()]
param(
    [string]$Name = "",
    [string]$Email = "",
    [string]$GithubUser = "",
    [string]$Preset = "",
    [switch]$EnableTilingWM,
    [switch]$DisableTilingWM,
    [switch]$NonInteractive,
    [string]$OutputPath = "",
    [switch]$RunNow
)

Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "logger.ps1")
. (Join-Path $PSScriptRoot "config.ps1")

function Test-DevboxConsoleInteractive {
    try {
        if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
            return $false
        }
        if (-not [Environment]::UserInteractive) {
            return $false
        }
        $null = [Console]::CursorLeft
        return $true
    } catch {
        return $false
    }
}

function Show-DevboxCursorMenu {
    param(
        [Parameter(Mandatory=$true)][string]$Title,
        [Parameter(Mandatory=$true)][System.Collections.Generic.List[PSCustomObject]]$Items,
        [switch]$SingleSelect
    )

    if (-not (Test-DevboxConsoleInteractive)) {
        # Fallback for non-interactive / redirected streams
        Write-Host ""
        Write-Host "=== $Title ==="
        for ($i = 0; $i -lt $Items.Count; $i++) {
            $check = if ($Items[$i].Selected) { "[*]" } else { "[ ]" }
            Write-Host "  $($i + 1)) $check $($Items[$i].Label)"
        }
        Write-Host "Press Enter to accept defaults, or enter comma-separated numbers to toggle:"
        $line = Read-Host "Choice"
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $parts = $line.Split(',') | ForEach-Object { $_.Trim() }
            if ($SingleSelect) {
                if ($parts.Count -gt 0 -and $parts[0] -match '^\d+$') {
                    $sel = [int]$parts[0] - 1
                    for ($j = 0; $j -lt $Items.Count; $j++) {
                        $Items[$j].Selected = ($j -eq $sel)
                    }
                }
            } else {
                foreach ($p in $parts) {
                    if ($p -match '^\d+$') {
                        $idx = [int]$p - 1
                        if ($idx -ge 0 -and $idx -lt $Items.Count) {
                            $Items[$idx].Selected = -not $Items[$idx].Selected
                        }
                    }
                }
            }
        }
        return
    }

    $cursorIndex = 0
    $itemCount = $Items.Count
    $headerLines = 3
    $totalLines = $headerLines + $itemCount + 1

    # ANSI Sequences
    $ESC = [char]27
    $C_Reset   = "$ESC[0m"
    $C_Bold    = "$ESC[1m"
    $C_Cyan    = "$ESC[36m"
    $C_Green   = "$ESC[32m"
    $C_Gray    = "$ESC[90m"
    $C_Yellow  = "$ESC[33m"

    # Hide console cursor
    Write-Host -NoNewline "$ESC[?25l"

    try {
        $firstRender = $true

        while ($true) {
            if (-not $firstRender) {
                # Move cursor back to menu top
                Write-Host -NoNewline "$ESC[${totalLines}A$ESC[0G"
            }
            $firstRender = $false

            # Render Category Header
            Write-Host "$ESC[2K$C_Cyan$C_Bold=== $Title ===$C_Reset"
            if ($SingleSelect) {
                Write-Host "$ESC[2K$C_Gray  Up/Down: Navigate | Space: Select | Enter: Confirm$C_Reset"
            } else {
                Write-Host "$ESC[2K$C_Gray  Up/Down: Navigate | Space: Toggle | A: All | N: None | Enter: Next$C_Reset"
            }
            Write-Host "$ESC[2K"

            # Render Items
            for ($i = 0; $i -lt $itemCount; $i++) {
                $item = $Items[$i]
                $isCurrent = ($i -eq $cursorIndex)

                $box = if ($item.Selected) {
                    "$C_Green[*]$C_Reset"
                } else {
                    "$C_Gray[ ]$C_Reset"
                }

                $indicator = if ($isCurrent) { "$C_Cyan>$C_Reset" } else { " " }
                $label = if ($isCurrent) {
                    "$C_Bold$C_Cyan$($item.Label)$C_Reset"
                } else {
                    $item.Label
                }

                $desc = if ($item.Description) { " $C_Gray($($item.Description))$C_Reset" } else { "" }
                Write-Host "$ESC[2K $indicator $box $label$desc"
            }

            Write-Host "$ESC[2K"

            # Capture key input
            $key = [Console]::ReadKey($true)

            switch ($key.Key) {
                ([ConsoleKey]::UpArrow) {
                    $cursorIndex = ($cursorIndex - 1 + $itemCount) % $itemCount
                }
                ([ConsoleKey]::DownArrow) {
                    $cursorIndex = ($cursorIndex + 1) % $itemCount
                }
                ([ConsoleKey]::Spacebar) {
                    if ($SingleSelect) {
                        for ($j = 0; $j -lt $itemCount; $j++) {
                            $Items[$j].Selected = ($j -eq $cursorIndex)
                        }
                    } else {
                        $Items[$cursorIndex].Selected = -not $Items[$cursorIndex].Selected
                    }
                }
                ([ConsoleKey]::A) {
                    if (-not $SingleSelect) {
                        for ($j = 0; $j -lt $itemCount; $j++) {
                            $Items[$j].Selected = $true
                        }
                    }
                }
                ([ConsoleKey]::N) {
                    if (-not $SingleSelect) {
                        for ($j = 0; $j -lt $itemCount; $j++) {
                            $Items[$j].Selected = $false
                        }
                    }
                }
                ([ConsoleKey]::Enter) {
                    return
                }
            }
        }
    } finally {
        # Restore console cursor
        Write-Host -NoNewline "$ESC[?25h"
    }
}

function Invoke-DevboxWizard {
    param(
        [string]$Name = "",
        [string]$Email = "",
        [string]$GithubUser = "",
        [string]$Preset = "",
        [switch]$EnableTilingWM,
        [switch]$DisableTilingWM,
        [switch]$NonInteractive,
        [string]$OutputPath = "",
        [switch]$RunNow
    )

    $repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = Join-Path $repoRoot "config.yaml"
    }

    Write-DevboxBanner -SubTitle "First-Time Setup Wizard"

    # Baseline User Identity
    $defaultName   = if ($Name) { $Name } elseif ($env:USERNAME) { $env:USERNAME } else { "Developer" }
    $defaultEmail  = if ($Email) { $Email } else { "$defaultName@users.noreply.github.com" }
    $defaultGithub = if ($GithubUser) { $GithubUser } else { "" }

    $finalName     = $defaultName
    $finalEmail    = $defaultEmail
    $finalGithub   = $defaultGithub

    # Define Selection Items for Categories
    # Category 2: Author Signature Rice
    $riceItems = [System.Collections.Generic.List[PSCustomObject]]::new()
    $riceItems.Add([PSCustomObject]@{
        Id          = "belal-rice"
        Label       = "Belal's Curated Desktop (GlazeWM DWM Cloaking + Nord Zebar + AHK Hotkeys) [Recommended]"
        Description = "Author signature tiling setup with Catppuccin lavender border"
        Selected    = $true
    })
    $riceItems.Add([PSCustomObject]@{
        Id          = "standard-desktop"
        Label       = "Standard Windows Desktop"
        Description = "Native Windows 11 taskbar, floating windows, no tiling manager"
        Selected    = $false
    })

    # Category 3: IDEs & Editors
    $editorItems = [System.Collections.Generic.List[PSCustomObject]]::new()
    $editorItems.Add([PSCustomObject]@{ Id = "vscode";  Label = "Visual Studio Code"; Description = "Microsoft.VisualStudioCode"; Selected = $true })
    $editorItems.Add([PSCustomObject]@{ Id = "zed";     Label = "Zed Editor";         Description = "Zed.Zed";                 Selected = $true })
    $editorItems.Add([PSCustomObject]@{ Id = "cursor";  Label = "Cursor";             Description = "Anysphere.Cursor";        Selected = $false })
    $editorItems.Add([PSCustomObject]@{ Id = "neovim";  Label = "Neovim";             Description = "Neovim.Neovim";           Selected = $false })

    # Category 4: Languages & Runtimes
    $runtimeItems = [System.Collections.Generic.List[PSCustomObject]]::new()
    $runtimeItems.Add([PSCustomObject]@{ Id = "node";   Label = "Node.js (fnm / LTS)";        Description = "Fast Node Manager"; Selected = $true })
    $runtimeItems.Add([PSCustomObject]@{ Id = "python"; Label = "Python (pyenv-win / 3.12)";   Description = "Python version manager"; Selected = $true })
    $runtimeItems.Add([PSCustomObject]@{ Id = "rust";   Label = "Rust (cargo / rustup)";      Description = "Official Rust toolchain"; Selected = $true })
    $runtimeItems.Add([PSCustomObject]@{ Id = "dotnet"; Label = ".NET SDK (8.0 / 9.0)";       Description = "Microsoft .NET SDK"; Selected = $true })
    $runtimeItems.Add([PSCustomObject]@{ Id = "go";     Label = "Go (winget)";                Description = "GoLang.Go"; Selected = $false })

    # Category 5: Terminal & Fonts
    $terminalItems = [System.Collections.Generic.List[PSCustomObject]]::new()
    $terminalItems.Add([PSCustomObject]@{ Id = "terminal"; Label = "Windows Terminal";        Description = "Microsoft.WindowsTerminal"; Selected = $true })
    $terminalItems.Add([PSCustomObject]@{ Id = "starship"; Label = "Starship Prompt";         Description = "Cross-shell prompt"; Selected = $true })
    $terminalItems.Add([PSCustomObject]@{ Id = "jb-font";  Label = "JetBrainsMono Nerd Font"; Description = "DEVCOM.JetBrainsMonoNerdFont"; Selected = $true })
    $terminalItems.Add([PSCustomObject]@{ Id = "cascadia"; Label = "CascadiaCode Nerd Font";  Description = "Microsoft.CascadiaCode"; Selected = $false })

    # Category 6: Containers & Databases
    $dbItems = [System.Collections.Generic.List[PSCustomObject]]::new()
    $dbItems.Add([PSCustomObject]@{ Id = "postgres"; Label = "PostgreSQL Client & Tools"; Description = "PostgreSQL.PostgreSQL"; Selected = $true })
    $dbItems.Add([PSCustomObject]@{ Id = "docker";   Label = "Docker Desktop";            Description = "Docker.DockerDesktop"; Selected = $true })
    $dbItems.Add([PSCustomObject]@{ Id = "redis";    Label = "Redis";                     Description = "Redis.Redis"; Selected = $false })
    $dbItems.Add([PSCustomObject]@{ Id = "mongodb";  Label = "MongoDB Compass";           Description = "MongoDB.Compass"; Selected = $false })

    if (-not $NonInteractive) {
        Write-Host "Welcome to devbox-win! Navigate options using Arrow keys, Space to toggle, and Enter to proceed.`n"

        # 1. User Identity
        $promptName = Read-Host "Developer Name [$defaultName]"
        if (-not [string]::IsNullOrWhiteSpace($promptName)) { $finalName = $promptName.Trim() }

        $promptEmail = Read-Host "Git Email [$defaultEmail]"
        if (-not [string]::IsNullOrWhiteSpace($promptEmail)) { $finalEmail = $promptEmail.Trim() }

        $promptGh = Read-Host "GitHub Username (for SSH/CLI) [$defaultGithub]"
        if (-not [string]::IsNullOrWhiteSpace($promptGh)) { $finalGithub = $promptGh.Trim() }

        # 2. Author Signature Rice
        Show-DevboxCursorMenu -Title "Category 1 of 5: Desktop Environment" -Items $riceItems -SingleSelect

        # 3. IDEs & Editors
        Show-DevboxCursorMenu -Title "Category 2 of 5: IDEs & Code Editors" -Items $editorItems

        # 4. Languages & Runtimes
        Show-DevboxCursorMenu -Title "Category 3 of 5: Languages & Runtimes" -Items $runtimeItems

        # 5. Terminal & Fonts
        Show-DevboxCursorMenu -Title "Category 4 of 5: Terminal & Fonts" -Items $terminalItems

        # 6. Containers & Databases
        Show-DevboxCursorMenu -Title "Category 5 of 5: Containers & Databases" -Items $dbItems
    }

    # Evaluate Final Selections
    $riceSelected = ($riceItems | Where-Object { $_.Id -eq "belal-rice" }).Selected
    $finalTiling = if ($DisableTilingWM) {
        $false
    } elseif ($EnableTilingWM) {
        $true
    } elseif ($Preset -eq "minimal" -or $Preset -eq "backend" -or $Preset -eq "devops") {
        $false
    } else {
        $riceSelected
    }

    # Preset determination
    $finalPreset = if ($Preset) {
        $Preset.ToLower()
    } elseif ($riceSelected) {
        "belal-catppuccin"
    } else {
        "fullstack"
    }

    # Collect Winget Packages
    $selectedPackages = [System.Collections.Generic.List[string]]::new()

    # Core Git & Archive
    $selectedPackages.Add("Git.Git")
    $selectedPackages.Add("GitHub.cli")
    $selectedPackages.Add("7zip.7zip")

    # Editors
    if (($editorItems | Where-Object { $_.Id -eq "vscode" }).Selected) { $selectedPackages.Add("Microsoft.VisualStudioCode") }
    if (($editorItems | Where-Object { $_.Id -eq "zed" }).Selected)    { $selectedPackages.Add("Zed.Zed") }
    if (($editorItems | Where-Object { $_.Id -eq "cursor" }).Selected) { $selectedPackages.Add("Anysphere.Cursor") }
    if (($editorItems | Where-Object { $_.Id -eq "neovim" }).Selected) { $selectedPackages.Add("Neovim.Neovim") }

    # Terminal & Fonts
    if (($terminalItems | Where-Object { $_.Id -eq "terminal" }).Selected) { $selectedPackages.Add("Microsoft.WindowsTerminal") }
    if (($terminalItems | Where-Object { $_.Id -eq "starship" }).Selected) { $selectedPackages.Add("Starship.Starship") }
    if (($terminalItems | Where-Object { $_.Id -eq "jb-font" }).Selected)  { $selectedPackages.Add("DEVCOM.JetBrainsMonoNerdFont") }
    if (($terminalItems | Where-Object { $_.Id -eq "cascadia" }).Selected) { $selectedPackages.Add("Microsoft.CascadiaCode") }

    # Tiling Desktop
    if ($finalTiling) {
        $selectedPackages.Add("glzr-io.glazewm")
        $selectedPackages.Add("glzr-io.zebar")
        $selectedPackages.Add("AutoHotkey.AutoHotkey")
        $selectedPackages.Add("Microsoft.PowerToys")
    }

    # Databases & Containers
    if (($dbItems | Where-Object { $_.Id -eq "postgres" }).Selected) { $selectedPackages.Add("PostgreSQL.PostgreSQL") }
    if (($dbItems | Where-Object { $_.Id -eq "docker" }).Selected)   { $selectedPackages.Add("Docker.DockerDesktop") }
    if (($dbItems | Where-Object { $_.Id -eq "redis" }).Selected)    { $selectedPackages.Add("Redis.Redis") }
    if (($dbItems | Where-Object { $_.Id -eq "mongodb" }).Selected)  { $selectedPackages.Add("MongoDB.Compass") }

    # Go
    if (($runtimeItems | Where-Object { $_.Id -eq "go" }).Selected) { $selectedPackages.Add("GoLang.Go") }

    # Construct Synthesized YAML Content
    $packagesYaml = ($selectedPackages | ForEach-Object { "  - $_" }) -join "`n"

    $hasNode   = ($runtimeItems | Where-Object { $_.Id -eq "node" }).Selected
    $hasPython = ($runtimeItems | Where-Object { $_.Id -eq "python" }).Selected
    $hasRust   = ($runtimeItems | Where-Object { $_.Id -eq "rust" }).Selected
    $hasDotnet = ($runtimeItems | Where-Object { $_.Id -eq "dotnet" }).Selected
    $hasDb     = (($dbItems | Where-Object { $_.Selected }).Count -gt 0)

    $primaryEditor = if (($editorItems | Where-Object { $_.Id -eq "zed" }).Selected -and (-not ($editorItems | Where-Object { $_.Id -eq "vscode" }).Selected)) {
        "zed"
    } elseif ($finalPreset -eq "belal-catppuccin") {
        "zed"
    } else {
        "vscode"
    }

    $tilingModulesYaml = if ($finalTiling) {
@"
  glazewm: true
  zebar: true
  keybindings: true
"@
    } else {
@"
  glazewm: false
  zebar: false
  keybindings: false
"@
    }

    $yamlContent = @"
# ==============================================================================
# devbox-win :: Active Configuration
# Path: config.yaml
# Generated by: devbox-win ANSI Cursor-Driven Setup Wizard
# ==============================================================================

# User Identity
user:
  name: "$finalName"
  email: "$finalEmail"
  github_username: "$finalGithub"

# Selected Preset
preset: $finalPreset

# Module Execution Toggles
modules:
  packages: true
  fonts: true
  git: true
  shell: true
  editor: true
  runtimes: $(if ($hasNode -or $hasPython -or $hasRust -or $hasDotnet) { 'true' } else { 'false' })
  databases: $(if ($hasDb) { 'true' } else { 'false' })
  envvars: true
  dotfiles: true
$tilingModulesYaml

# Selected Winget Packages
packages:
$packagesYaml

# Editor Settings
editor:
  primary: $primaryEditor
  sync_settings: true
  install_extensions: true

# Shell Settings
shell:
  prompt: starship
  theme: custom

# Git Settings
git:
  default_branch: main
  autocrlf: input
  generate_ssh_key: true
  ssh_key_type: ed25519
  gpg_signing: false

# Language Runtimes
runtimes:
  node:
    manager: fnm
    default_version: lts
  python:
    manager: pyenv-win
    default_version: "3.12"
  rust:
    install: $(if ($hasRust) { 'true' } else { 'false' })
  dotnet:
    versions:
      - "8.0"
      - "9.0"

# Fonts
fonts:
  - JetBrainsMono

# Tiling Window Manager
glazewm:
  install: $(if ($finalTiling) { 'true' } else { 'false' })
  autostart: $(if ($finalTiling) { 'true' } else { 'false' })
  hide_method: cloak
  border_color: "#cba6f7"

# Status Bar
zebar:
  install: $(if ($finalTiling) { 'true' } else { 'false' })
  autostart: $(if ($finalTiling) { 'true' } else { 'false' })
  pack: nord

# Shortcuts & Window Rules
keybindings:
  powertoys: $(if ($finalTiling) { 'true' } else { 'false' })
  autohotkey: $(if ($finalTiling) { 'true' } else { 'false' })
  startup_script: $(if ($finalTiling) { 'true' } else { 'false' })

# Custom Environment Variables
envvars:
  EDITOR: $primaryEditor
  DEVBOX_WIN: "true"
"@

    # Write Config File
    try {
        $parentDir = Split-Path -Parent $OutputPath
        if ($parentDir -and -not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        Set-Content -Path $OutputPath -Value $yamlContent -Encoding utf8
        Write-DevboxOk "Configuration successfully generated at: $OutputPath"
    } catch {
        Write-DevboxFail "Failed to write configuration file to $OutputPath" $_.Exception.Message
        exit 1
    }

    # Optional immediate execution
    if ($RunNow) {
        Write-DevboxInfo "Launching core engine with new configuration..."
        $enginePath = Join-Path $repoRoot "core\engine.ps1"
        & $enginePath -ConfigFile $OutputPath
    } elseif (-not $NonInteractive -and (Test-DevboxConsoleInteractive)) {
        $execNow = Read-Host "`nReady to apply configuration now? (y/n) [y]"
        if ($execNow.Trim().ToLower() -ne "n") {
            $enginePath = Join-Path $repoRoot "core\engine.ps1"
            & $enginePath -ConfigFile $OutputPath
        } else {
            Write-DevboxInfo "Setup complete. You can run 'pwsh -NoProfile -File core/engine.ps1' whenever you are ready."
        }
    }

    return [PSCustomObject]@{
        OutputPath = $OutputPath
        Preset     = $finalPreset
        Name       = $finalName
        Email      = $finalEmail
        TilingWM   = $finalTiling
    }
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -notmatch '^\.') {
    Invoke-DevboxWizard `
        -Name $Name `
        -Email $Email `
        -GithubUser $GithubUser `
        -Preset $Preset `
        -EnableTilingWM:$EnableTilingWM `
        -DisableTilingWM:$DisableTilingWM `
        -NonInteractive:$NonInteractive `
        -OutputPath $OutputPath `
        -RunNow:$RunNow
}
