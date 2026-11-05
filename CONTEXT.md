# Ubiquitous Domain Language: devbox-win

> Purpose: Canonical glossary and bounded context vocabulary for `devbox-win`. Establishes strict domain modeling across code, AI agent instructions, and living documentation.

---

## Bounded Domain Terms

### Agentic Dotfiles Hub
- **Definition**: The declarative configuration repository and orchestration suite decoupling workstation dotfiles from brittle procedural scripts, delegating deployment to autonomous AI coding assistants.
- **_Avoid_**: "installer", "setup wizard", "batch installer", "bash script".

### Visual Web Studio
- **Definition**: The client-side, zero-CORS Bento Grid web application (`docs/index.html`) providing real-time inspection, interactive curation, and in-memory JSZip package generation.
- **_Avoid_**: "marketing page", "landing site", "docs portal".

### Universal Agent Prompt Manifest (`agent-prompt.md`)
- **Definition**: The deterministic 4-phase deployment instruction set provided to AI assistants (Antigravity, Cursor, Claude Code, Copilot) specifying pre-flight snapshots, symlink linking, extension verification, and health audit.
- **_Avoid_**: "README prompt", "setup guide", "cheatsheet".

### Pre-Flight Snapshot
- **Definition**: The non-destructive Phase 1 backup procedure creating an atomic `~/.devbox-backups/backup-<TIMESTAMP>.zip` bundle, companion `manifest.json`, and deterministic `restore.ps1`.
- **_Avoid_**: "manual copy", "ad-hoc backup".

### Unprivileged Symlink
- **Definition**: An NTFS symbolic link created without administrative rights using Windows 10/11 Developer Mode (`SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE`), connecting `configs/<module>` to target machine destinations.
- **_Avoid_**: "shortcut", "hard link", "duplicate file".

### Curated Module Suite
- **Definition**: A distinct configuration domain under `configs/` (e.g. `vscode`, `antigravity`, `tiling`, `terminal`, `shortcuts`, `git`, `obsidian`) containing validated JSON/YAML/TOML/Markdown specifications.
- **_Avoid_**: "folder", "sub-repo".
