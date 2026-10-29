# ==============================================================================
# devbox-win :: Machine State Exporter
# Path: core/export.ps1
# Description: Reverse-engineers active machine toolchains and configurations into YAML.
# Standard: Zero emojis. Pure ANSI badges and reproducible declarative exports.
# ==============================================================================

[CmdletBinding()]
param(
    [string]$OutputPath = "",
    [switch]$AsObject,
    [switch]$Quiet
)

Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))

. (Join-Path $PSScriptRoot "logger.ps1")
. (Join-Path $PSScriptRoot "config.ps1")

function Invoke-DevboxExport {
    [CmdletBinding()]
    param(
        [string]$OutputPath = "",
        [switch]$AsObject,
        [switch]$Quiet
    )

    $root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = Join-Path $root "config.exported.yaml"
    }

    if (-not $Quiet) {
        Write-DevboxBanner -SubTitle "Workstation State Reverse-Engineering Exporter"
        Write-DevboxInfo "Auditing machine state and installed toolchains..."
    }

    # --------------------------------------------------------------------------
    # 1. User Identity & Git Credentials
    # --------------------------------------------------------------------------
    $detectedName = (& git config --get user.name 2>$null)
    $detectedEmail = (& git config --get user.email 2>$null)
    $detectedGhUser = (& git config --get github.user 2>$null)

    if ([string]::IsNullOrWhiteSpace($detectedGhUser)) {
        $ghCmd = Get-Command "gh" -ErrorAction SilentlyContinue
        if ($ghCmd) {
            $ghUserOutput = & gh api user --jq .login 2>$null
            if ($LASTEXITCODE -eq 0 -and (-not [string]::IsNullOrWhiteSpace($ghUserOutput))) {
                $detectedGhUser = $ghUserOutput.Trim()
            }
        }
    }

    $userName = if (-not [string]::IsNullOrWhiteSpace($detectedName)) { $detectedName.Trim() } elseif ($env:USERNAME) { $env:USERNAME } else { "Developer" }
    $userEmail = if (-not [string]::IsNullOrWhiteSpace($detectedEmail)) { $detectedEmail.Trim() } else { "$userName@localhost" }
    $ghUser = if (-not [string]::IsNullOrWhiteSpace($detectedGhUser)) { $detectedGhUser.Trim() } else { "" }

    # --------------------------------------------------------------------------
    # 2. Installed Winget Package Catalog Audit
    # --------------------------------------------------------------------------
    $knownCatalog = @(
        # Developer Core
        "Microsoft.VisualStudioCode",
        "Zed.Zed",
        "Git.Git",
        "GitHub.cli",
        "Microsoft.WindowsTerminal",
        "Starship.Starship",
        "JanDeDobbeleer.OhMyPosh",
        "7zip.7zip",
        "DEVCOM.JetBrainsMonoNerdFont",
        "sharkdp.bat",
        "BurntSushi.ripgrep.MSVC",
        "Neovim.Neovim",
        "AutoHotkey.AutoHotkey",
        "Microsoft.PowerToys",
        # Browsers
        "Google.Chrome",
        "Mozilla.Firefox",
        "Brave.Brave",
        # Containers & DevOps
        "Docker.DockerDesktop",
        "Kubernetes.kubectl",
        "Helm.Helm",
        # Databases & Clients
        "PostgreSQL.PostgreSQL",
        "Redis.Redis",
        "MongoDB.Server",
        "MongoDB.Compass",
        # Productivity
        "Discord.Discord",
        "Notion.Notion",
        "Obsidian.Obsidian",
        "Postman.Postman",
        "VideoLAN.VLC",
        # Window Managers
        "glzr-io.glazewm",
        "glzr-io.zebar"
    )

    $installedPackages = [System.Collections.Generic.List[string]]::new()
    $installedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $wingetCmd = Get-Command "winget" -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        $lines = & winget list 2>$null
        if ($lines -and $lines.Count -gt 1) {
            $header = $lines[0]
            $idIdx = $header.IndexOf("Id")
            $verIdx = $header.IndexOf("Version")

            if ($idIdx -ge 0 -and $verIdx -gt $idIdx) {
                foreach ($line in $lines | Select-Object -Skip 2) {
                    if ($line.Length -gt $verIdx) {
                        $rawId = $line.Substring($idIdx, ($verIdx - $idIdx)).Trim()
                        if ($rawId) {
                            [void]$installedSet.Add($rawId)
                        }
                    }
                }
            }
        }
    }

    foreach ($catPkg in $knownCatalog) {
        if ($installedSet.Contains($catPkg)) {
            $installedPackages.Add($catPkg)
        }
    }

    # Ensure baseline tools are present if detected in PATH
    if ((Get-Command "git" -ErrorAction SilentlyContinue) -and (-not $installedPackages.Contains("Git.Git"))) {
        $installedPackages.Add("Git.Git")
    }
    if ((Get-Command "code" -ErrorAction SilentlyContinue) -and (-not $installedPackages.Contains("Microsoft.VisualStudioCode"))) {
        $installedPackages.Add("Microsoft.VisualStudioCode")
    }
    if ((Get-Command "wt.exe" -ErrorAction SilentlyContinue) -and (-not $installedPackages.Contains("Microsoft.WindowsTerminal"))) {
        $installedPackages.Add("Microsoft.WindowsTerminal")
    }

    # --------------------------------------------------------------------------
    # 3. Language Runtimes & Compilers
    # --------------------------------------------------------------------------
    # Node.js
    $hasNode = $false
    $nodeVersion = "lts"
    $nodeManager = "nvm"
    if (Get-Command "node" -ErrorAction SilentlyContinue) {
        $hasNode = $true
        $rawNodeVer = & node -v 2>$null
        if ($rawNodeVer) {
            $nodeVersion = ($rawNodeVer.Trim() -replace '^v', '')
        }
    }
    if (Get-Command "fnm" -ErrorAction SilentlyContinue) {
        $nodeManager = "fnm"
    }

    # Python
    $hasPython = $false
    $pythonVersion = "3.12"
    if (Get-Command "python" -ErrorAction SilentlyContinue) {
        $hasPython = $true
        $rawPyVer = & python --version 2>$null
        if ($rawPyVer -match '(\d+\.\d+)') {
            $pythonVersion = $Matches[1]
        }
    }

    # Rust
    $hasRust = [bool]((Get-Command "rustc" -ErrorAction SilentlyContinue) -or (Get-Command "rustup" -ErrorAction SilentlyContinue))

    # .NET SDKs
    $dotnetVersions = [System.Collections.Generic.List[string]]::new()
    if (Get-Command "dotnet" -ErrorAction SilentlyContinue) {
        $sdkList = & dotnet --list-sdks 2>$null
        if ($sdkList) {
            foreach ($line in $sdkList) {
                if ($line -match '^(\d+\.\d+)') {
                    $v = $Matches[1]
                    if (-not $dotnetVersions.Contains($v)) {
                        $dotnetVersions.Add($v)
                    }
                }
            }
        }
        if ($dotnetVersions.Count -eq 0) {
            $dotnetVer = & dotnet --version 2>$null
            if ($dotnetVer -match '^(\d+\.\d+)') {
                $dotnetVersions.Add($Matches[1])
            }
        }
    }
    if ($dotnetVersions.Count -eq 0) {
        $dotnetVersions.Add("8.0")
    }

    # --------------------------------------------------------------------------
    # 4. Nerd Fonts Inventory
    # --------------------------------------------------------------------------
    $detectedFonts = [System.Collections.Generic.List[string]]::new()
    $fontKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
        "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    )

    foreach ($k in $fontKeys) {
        if (Test-Path $k) {
            $props = (Get-ItemProperty -Path $k -ErrorAction SilentlyContinue).PSObject.Properties
            foreach ($p in $props) {
                $name = $p.Name
                if ($name -match 'JetBrains' -and -not $detectedFonts.Contains("JetBrainsMono")) {
                    $detectedFonts.Add("JetBrainsMono")
                }
                if ($name -match 'Cascadia' -and -not $detectedFonts.Contains("CascadiaCode")) {
                    $detectedFonts.Add("CascadiaCode")
                }
                if ($name -match 'Fira' -and -not $detectedFonts.Contains("FiraCode")) {
                    $detectedFonts.Add("FiraCode")
                }
                if ($name -match 'Meslo' -and -not $detectedFonts.Contains("Meslo")) {
                    $detectedFonts.Add("Meslo")
                }
                if ($name -match 'Hack' -and -not $detectedFonts.Contains("Hack")) {
                    $detectedFonts.Add("Hack")
                }
            }
        }
    }
    if ($detectedFonts.Count -eq 0) {
        $detectedFonts.Add("JetBrainsMono")
    }

    # --------------------------------------------------------------------------
    # 5. Window Management & Desktop Enhancements
    # --------------------------------------------------------------------------
    $hasGlazewm = [bool]((Get-Command "glazewm" -ErrorAction SilentlyContinue) -or (Get-Process "glazewm" -ErrorAction SilentlyContinue) -or (Test-Path "$HOME\.glzr\glazewm"))
    $hasZebar    = [bool]((Get-Command "zebar" -ErrorAction SilentlyContinue) -or (Get-Process "zebar" -ErrorAction SilentlyContinue) -or (Test-Path "$HOME\.glzr\zebar"))
    $hasStarship = [bool](Get-Command "starship" -ErrorAction SilentlyContinue)
    $hasPowerToys = [bool]((Get-Command "PowerToys" -ErrorAction SilentlyContinue) -or (Test-Path "HKLM:\SOFTWARE\Microsoft\PowerToys"))
    $hasAhk       = [bool]((Get-Command "AutoHotkey.exe" -ErrorAction SilentlyContinue) -or (Test-Path "HKLM:\SOFTWARE\AutoHotkey"))

    # --------------------------------------------------------------------------
    # 6. Synthesize Declarative YAML Configuration
    # --------------------------------------------------------------------------
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# ==============================================================================")
    [void]$sb.AppendLine("# devbox-win :: Exported Configuration")
    [void]$sb.AppendLine("# Generated on : $(Get-Date -Format 'o')")
    [void]$sb.AppendLine("# Host Machine : $env:COMPUTERNAME | Active User : $env:USERNAME")
    [void]$sb.AppendLine("# Usage:")
    [void]$sb.AppendLine("#   Rename or copy this file to config.yaml in your personal devbox-win fork.")
    [void]$sb.AppendLine("# ==============================================================================")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("# ─── User Identity ──────────────────────────────────────────────────────────")
    [void]$sb.AppendLine("user:")
    [void]$sb.AppendLine("  name: `"$userName`"")
    [void]$sb.AppendLine("  email: `"$userEmail`"")
    [void]$sb.AppendLine("  github_username: `"$ghUser`"")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("# ─── Preset ─────────────────────────────────────────────────────────────────")
    [void]$sb.AppendLine("preset: custom")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("# ─── Module Toggles ─────────────────────────────────────────────────────────")
    [void]$sb.AppendLine("modules:")
    [void]$sb.AppendLine("  packages: true")
    [void]$sb.AppendLine("  fonts: true")
    [void]$sb.AppendLine("  envvars: true")
    [void]$sb.AppendLine("  git: true")
    [void]$sb.AppendLine("  shell: true")
    [void]$sb.AppendLine("  editor: true")
    [void]$sb.AppendLine("  runtimes: true")
    [void]$sb.AppendLine("  databases: true")
    [void]$sb.AppendLine("  keybindings: $(if ($hasPowerToys -or $hasAhk) { 'true' } else { 'false' })")
    [void]$sb.AppendLine("  glazewm: $(if ($hasGlazewm) { 'true' } else { 'false' })")
    [void]$sb.AppendLine("  zebar: $(if ($hasZebar) { 'true' } else { 'false' })")
    [void]$sb.AppendLine("  dotfiles: true")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("# ─── Packages (Detected Winget Toolchains) ─────────────────────────────────")
    [void]$sb.AppendLine("packages:")
    foreach ($pkg in $installedPackages) {
        [void]$sb.AppendLine("  - $pkg")
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("# ─── Shell ────────────────────────────────────────────────────────────────")
    [void]$sb.AppendLine("shell:")
    [void]$sb.AppendLine("  prompt: $(if ($hasStarship) { 'starship' } else { 'ohmyposh' })")
    [void]$sb.AppendLine("  theme: custom")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("# ─── Git ──────────────────────────────────────────────────────────────────")
    [void]$sb.AppendLine("git:")
    [void]$sb.AppendLine("  default_branch: main")
    [void]$sb.AppendLine("  autocrlf: input")
    [void]$sb.AppendLine("  generate_ssh_key: true")
    [void]$sb.AppendLine("  ssh_key_type: ed25519")
    [void]$sb.AppendLine("  gpg_signing: false")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("# ─── Editor ───────────────────────────────────────────────────────────────")
    [void]$sb.AppendLine("editor:")
    [void]$sb.AppendLine("  primary: vscode")
    [void]$sb.AppendLine("  sync_settings: true")
    [void]$sb.AppendLine("  install_extensions: true")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("# ─── Fonts ────────────────────────────────────────────────────────────────")
    [void]$sb.AppendLine("fonts:")
    foreach ($f in $detectedFonts) {
        [void]$sb.AppendLine("  - $f")
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("# ─── Runtimes ─────────────────────────────────────────────────────────────")
    [void]$sb.AppendLine("runtimes:")
    [void]$sb.AppendLine("  node:")
    [void]$sb.AppendLine("    manager: $nodeManager")
    [void]$sb.AppendLine("    default_version: `"$nodeVersion`"")
    [void]$sb.AppendLine("  python:")
    [void]$sb.AppendLine("    manager: pyenv-win")
    [void]$sb.AppendLine("    default_version: `"$pythonVersion`"")
    [void]$sb.AppendLine("  rust:")
    [void]$sb.AppendLine("    install: $(if ($hasRust) { 'true' } else { 'false' })")
    [void]$sb.AppendLine("  dotnet:")
    [void]$sb.AppendLine("    versions:")
    foreach ($dv in $dotnetVersions) {
        [void]$sb.AppendLine("      - `"$dv`"")
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("# ─── Databases ────────────────────────────────────────────────────────────")
    [void]$sb.AppendLine("databases:")
    $hasDb = $false
    if ($installedPackages.Contains("PostgreSQL.PostgreSQL")) {
        [void]$sb.AppendLine("  - PostgreSQL.PostgreSQL")
        $hasDb = $true
    }
    if ($installedPackages.Contains("Redis.Redis")) {
        [void]$sb.AppendLine("  - Redis.Redis")
        $hasDb = $true
    }
    if ($installedPackages.Contains("MongoDB.Server")) {
        [void]$sb.AppendLine("  - MongoDB.Server")
        $hasDb = $true
    }
    if (-not $hasDb) {
        [void]$sb.AppendLine("  # - PostgreSQL.PostgreSQL")
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("# ─── Keybindings ──────────────────────────────────────────────────────────")
    [void]$sb.AppendLine("keybindings:")
    [void]$sb.AppendLine("  powertoys: $(if ($hasPowerToys) { 'true' } else { 'false' })")
    [void]$sb.AppendLine("  autohotkey: $(if ($hasAhk) { 'true' } else { 'false' })")
    [void]$sb.AppendLine("  startup_script: true")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("# ─── Window Management ───────────────────────────────────────────────────")
    [void]$sb.AppendLine("glazewm:")
    [void]$sb.AppendLine("  install: $(if ($hasGlazewm) { 'true' } else { 'false' })")
    [void]$sb.AppendLine("  autostart: $(if ($hasGlazewm) { 'true' } else { 'false' })")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("zebar:")
    [void]$sb.AppendLine("  install: $(if ($hasZebar) { 'true' } else { 'false' })")
    [void]$sb.AppendLine("  autostart: $(if ($hasZebar) { 'true' } else { 'false' })")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("# ─── Environment Variables ────────────────────────────────────────────────")
    [void]$sb.AppendLine("envvars:")
    [void]$sb.AppendLine("  EDITOR: code")
    [void]$sb.AppendLine("  DEVBOX_WIN: `"true`"")

    $generatedYaml = $sb.ToString()

    # --------------------------------------------------------------------------
    # 7. Validate Generated YAML Output
    # --------------------------------------------------------------------------
    $parsedCheck = ConvertFrom-SimpleYaml -YamlText $generatedYaml
    $val = Test-DevboxConfig -Config $parsedCheck
    if (-not $val.Valid) {
        throw "Export generation created invalid YAML configuration: $($val.Errors -join '; ')"
    }

    # Write output to disk
    $parentDir = Split-Path -Parent $OutputPath
    if ($parentDir -and (-not (Test-Path $parentDir))) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    Set-Content -Path $OutputPath -Value $generatedYaml -Encoding utf8

    if (-not $Quiet) {
        Write-DevboxOk "Workstation configuration successfully exported to: $OutputPath"
        Write-DevboxInfo "Summary of detected state:"
        Write-Host "    - User Identity      : $userName <$userEmail>"
        Write-Host "    - Winget Packages    : $($installedPackages.Count) catalog packages identified"
        Write-Host "    - Detected Fonts     : $($detectedFonts -join ', ')"
        Write-Host "    - Node.js Runtime    : $nodeVersion (manager: $nodeManager)"
        Write-Host "    - Python Runtime     : $pythonVersion"
        Write-Host "    - Rust Toolchain     : $(if ($hasRust) { 'Detected' } else { 'Not installed' })"
        Write-Host "    - .NET SDK Versions  : $($dotnetVersions -join ', ')"
        Write-Host "    - GlazeWM / Zebar    : GlazeWM=$(if ($hasGlazewm){'Yes'}else{'No'}), Zebar=$(if ($hasZebar){'Yes'}else{'No'})"
    }

    if ($AsObject) {
        return [PSCustomObject]@{
            OutputPath = $OutputPath
            Config     = $parsedCheck
            YamlText   = $generatedYaml
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-DevboxExport -OutputPath $OutputPath -AsObject:$AsObject -Quiet:$Quiet
}
