## Description of Changes

Please provide a concise description of the changes introduced in this pull request and the rationale behind them.

---

## Type of Change

- [ ] New provisioning module (`modules/<name>.ps1`)
- [ ] New developer stack preset (`presets/<name>.yaml`)
- [ ] Core engine enhancement (`core/`)
- [ ] Bug fix / edge-case remediation
- [ ] Documentation / README update

---

## Mandatory Verification Checklist

Before submitting this pull request, ensure all the following verification gates pass:

- [ ] **PowerShell AST Syntax Validation**: All `.ps1` files parse without syntax errors.
- [ ] **Automated Test Suite**: `pwsh -NoProfile -File tests/engine.tests.ps1` passes with 0 failures.
- [ ] **Doctor Audit Verification**: `pwsh -NoProfile -File core/engine.ps1 -Doctor` executes cleanly.
- [ ] **Export Verification**: `pwsh -NoProfile -File core/engine.ps1 -Export` generates schema-valid YAML.
- [ ] **Dry-Run Validation**: `pwsh -NoProfile -File core/engine.ps1 -DryRun` succeeds with no disk mutations.
- [ ] **Idempotency**: Running modules a second time yields `[SKIP]` or safe state without unintended side-effects.
- [ ] **Zero Emojis Standard**: All code, terminal outputs, error messages, and documentation adhere strictly to the zero emojis standard (clean ANSI badges only: `[OK]`, `[SKIP]`, `[FAIL]`, `[WARN]`, `[INFO]`, `[FIX]`).
- [ ] **Non-Destructive Backups**: Overwritten user dotfiles are preserved in `~/.devbox-win/backups/`.

---

## Verification Evidence & Output

Paste relevant test execution logs or console output below:

```text
[Paste verification output here]
```
