<p align="center">
  <img src="docs/assets/logo.svg" alt="devbox-win logo" width="96" height="96">
</p>

<h1 align="center">devbox-win</h1>

<p align="center">
  <strong>Agentic Dotfiles Hub &amp; Visual Web Studio for Windows 11</strong><br>
  Curated dotfiles &bull; Bento Grid Web Studio &bull; Universal Agent Manifest (`agent-prompt.md`) &bull; Unprivileged native symlinks &bull; Zero bloat
</p>

<p align="center">
  <a href="https://github.com/belal-waheed/devbox-win/actions"><img src="https://github.com/belal-waheed/devbox-win/actions/workflows/ci.yml/badge.svg" alt="CI/CD"></a>
  <a href="https://belal-waheed.github.io/devbox-win/"><img src="https://img.shields.io/badge/Web%20Studio-Live-38bdf8?style=flat" alt="Web Studio Live"></a>
  <img src="https://img.shields.io/badge/windows-11%20Build%2022000+-0078d4" alt="Windows 11">
  <img src="https://img.shields.io/badge/agents-Antigravity%20%7C%20Cursor%20%7C%20Claude%20Code-2563eb" alt="Supported Agents">
  <a href="#license"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
</p>

---

## Overview

`devbox-win` is an **Agentic Dotfiles Hub & Visual Web Studio** designed for modern Windows 11 workstations. Rather than relying on fragile procedural scripts or monolithic installers, `devbox-win` decouples declarative configuration files from execution, turning your environment setup into a deterministic, AI-orchestrated deployment.

Pairing an interactive **Bento Grid Web Studio** with a battle-tested **Universal Agent Prompt Manifest** (`agent-prompt.md`), you can curate, inspect, and bundle your developer environment in seconds, then delegate atomic snapshotting and symlink deployment to any autonomous AI coding assistant—such as **Google Antigravity**, **Cursor**, **Claude Code**, or **GitHub Copilot**.

---

## Architecture & Core Components

```
devbox-win/
├── configs/                   # Curated, sanitized configuration modules
│   ├── antigravity/           # Universal rules, MCP examples, and 38 domain skills
│   ├── git/                   # .gitconfig and cross-platform .gitignore_global
│   ├── obsidian/              # Vault configuration, hotkeys, snippets, and plugins
│   ├── shortcuts/             # AutoHotkey v2 productivity navigation
│   ├── terminal/              # Windows Terminal profile, Starship, and PowerShell 7 profile
│   ├── tiling/                # GlazeWM layout configuration and Zebar Nord status bar
│   └── vscode/                # Settings, keybindings, snippets, and extensions
├── docs/                      # Bento Grid Web Studio (GitHub Pages)
│   ├── assets/                # Configs bundle (pre-indexed window.DEVBOX_CONFIGS)
│   ├── vendor/                # In-memory JSZip v3.10.1
│   └── index.html             # High-contrast OKLCH dark studio interface
├── agent-prompt.md            # Universal 4-phase AI agent deployment manifest
└── README.md
```

---

## The Curated Configuration Suite

| Module | Description | Target Workstation Destination |
| :--- | :--- | :--- |
| **Visual Studio Code** | Font ligatures, bracket colorization, format-on-save, snippets, and extensions | `%APPDATA%\Code\User` |
| **Antigravity AI** | Global guardrails, layered architecture standards, and 38 domain skills | `%USERPROFILE%\.gemini` |
| **GlazeWM** | Dynamic tiling window manager with workspace bindings and GPU telemetry | `%USERPROFILE%\.glzr\glazewm` |
| **Zebar & Nord** | Hardware-accelerated desktop status bar with Nord theme and system meters | `%USERPROFILE%\.glzr\zebar` |
| **Obsidian Vault** | Second-brain suite with Dataview, Templater, QuickAdd, and Folder Notes | `<VaultRoot>\.obsidian` |
| **Windows Terminal & PowerShell 7** | GPU-accelerated terminal profile with acrylic blur and UTF-8 PowerShell profile | Terminal LocalState & Documents |
| **Starship Prompt** | Ultra-fast cross-shell prompt with git status and execution timing | `%USERPROFILE%\.config\starship.toml` |
| **AutoHotkey v2** | Productive window navigation and application launcher hotkeys | `%USERPROFILE%\.config\ahk\hotkeys.ahk` |
| **Git & Global Ignore** | Input line endings, log graphing, auto-remote push, and global ignore | `%USERPROFILE%\.gitconfig` |

---

## Deployment Workflows

### Method 1: The Visual Web Studio (Zero CLI Required)
1. Navigate to the [devbox-win Web Studio](https://belal-waheed.github.io/devbox-win/).
2. Select your desired configurations using the interactive Bento Grid.
3. Click **Inspect Config** to review syntax-highlighted files directly in your browser.
4. Click **Download Tailored Bundle (.zip)** to generate an in-memory archive containing only your selected modules and customized `agent-prompt.md`.
5. Unzip and execute with your preferred AI coding agent.

### Method 2: Autonomous AI Agent Execution (Antigravity / Cursor / Claude Code)
Clone this repository and provide `agent-prompt.md` to your coding assistant:

```powershell
git clone https://github.com/belal-waheed/devbox-win.git
cd devbox-win
```

Prompt your AI assistant:
> "Read `agent-prompt.md` and execute the 4-phase deployment."

Your AI assistant will execute the 4 deterministic phases:
- **Phase 1: Pre-Flight Snapshot:** Inspects target locations, generates `~/.devbox-backups/backup-<TIMESTAMP>/manifest.json`, archives existing configs to a `.zip`, and creates an automated `restore.ps1`.
- **Phase 2: Configuration Linking:** Detects Windows Developer Mode capability and establishes unprivileged native symlinks (or direct copies if Developer Mode is inactive).
- **Phase 3: Toolchain Verification:** Installs curated VS Code extensions from `extensions.txt`.
- **Phase 4: Health Check:** Validates symlinks and prints a formatted status report.

---

## Rollback & Disaster Recovery

If you ever need to restore your machine's previous configuration state, every deployment generates a deterministic restore script:

```powershell
# Restore from the latest automated snapshot
pwsh -NoProfile -File "$env:USERPROFILE\.devbox-backups\backup-<TIMESTAMP>\restore.ps1"
```

---

## Security & Sanitization Standard

- **Zero Secrets / Zero Leaks:** No personal directories, tokens, or email addresses are hardcoded in any configuration file.
- **Environment Variables First:** Sensitive integrations (MCP servers, GitHub, Resend, Vercel) dynamically inherit credentials via Windows Environment Variables (e.g. `$env:GITHUB_PERSONAL_ACCESS_TOKEN`).
- **Non-Destructive Guarantee:** Existing configurations are never overwritten without first creating a restorable snapshot in `~/.devbox-backups/`.

---

## License

Distributed under the MIT License. See `LICENSE` for details.
