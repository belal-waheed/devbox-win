# Ubiquitous Domain Language: devbox-win

> Purpose: Canonical glossary and bounded context vocabulary for `devbox-win`. Prevents ambiguous terminology across code, issues, and documentation.

---

## Bounded Domain Terms

### Provisioner
- **Definition**: The complete engine subsystem responsible for bringing a Windows 11 machine into the desired declarative state defined by `config.yaml`.
- **_Avoid_**: "installer", "setup wizard", "batch script".

### Module
- **Definition**: An isolated PowerShell unit under `modules/` with a defined contract, declarative schema, and explicit dependencies evaluated in topological order.
- **_Avoid_**: "step", "task", "job", "action".

### Topological DAG (Directed Acyclic Graph)
- **Definition**: The mathematical ordering model computed via Kahn's algorithm that guarantees prerequisite modules (e.g. `packages`, `fonts`) execute before dependents (e.g. `editor`, `shell`, `dotfiles`).
- **_Avoid_**: "execution list", "run queue", "pipeline".

### Unprivileged Symlink
- **Definition**: An NTFS symbolic link created without administrative rights using Windows 10/11 Developer Mode (`SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE`).
- **_Avoid_**: "shortcut", "hard link", "file copy".

### Signature Rice
- **Definition**: The author's personal workstation configuration pairing GlazeWM (DWM hardware cloaking + `#cba6f7` Catppuccin lavender borders) with the Nord Zebar widget status bar, Zed editor, and custom AutoHotkey v2 shortcuts.
- **_Avoid_**: "theme", "skin", "wallpaper".

### Circuit Breaker
- **Definition**: The 180-second timeout guard wrapping external WinGet package processes that terminates deadlocked installers and logs a non-blocking warning.
- **_Avoid_**: "retry loop", "sleep timer".

### Mutation Manifest
- **Definition**: The persistent JSON file at `~/.devbox-win/manifest.json` recording every symlink replacement, real file backup path, and installed package for deterministic `-Uninstall` rollback.
- **_Avoid_**: "history", "changelog", "audit trail".
