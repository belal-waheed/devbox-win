---
name: gitops-release-automation
description: GitOps release engineering standards covering Conventional Commits parsing, automated SemVer calculation, structured changelog synthesis, and GitHub CLI release publishing with REST API fallbacks.
---

# GitOps & Automated Release Engineering Guide

Comprehensive guide for GitOps workflows, automated semantic versioning, Conventional Commits enforcement, changelog synthesis, and GitHub release automation.

---

## When to Use This Skill

Trigger whenever preparing, tagging, or publishing software releases:
- Formatting and linting Git commit messages to conform with the Conventional Commits specification.
- Calculating the next Semantic Version (`MAJOR.MINOR.PATCH`) by analyzing commit ranges since the last tag.
- Generating categorized release notes and changelogs (`CHANGELOG.md`).
- Publishing releases and uploading release binaries using the GitHub CLI (`gh release create`).
- Scripting fallback release automations via PowerShell (`Invoke-RestMethod`) and the GitHub REST API.

---

## 1. Conventional Commits 1.0.0 Specification

Every commit subject line must follow this structural format:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Commit Types & Semantic Impact

| Type | SemVer Impact | Description |
|---|---|---|
| `feat` | **MINOR** | Introduces a new feature or user-facing capability. |
| `fix` | **PATCH** | Patches a bug or fixes unexpected behavior. |
| `perf` | **PATCH** | Code change that improves performance without changing semantics. |
| `refactor` | None (or PATCH) | Code restructuring that neither fixes a bug nor adds a feature. |
| `docs` | None | Documentation updates, README changes, or docstrings. |
| `test` | None | Adding missing tests or correcting existing tests. |
| `build` / `ci` | None | Build system, packaging, Dockerfile, or CI/CD workflow changes. |
| `chore` | None | Routine maintenance, dependencies, or formatting tweaks. |
| **`!` or `BREAKING CHANGE:`** | **MAJOR** | Any type with `!` (e.g., `feat!:`) or a footer starting with `BREAKING CHANGE:`. |

### Formatting Examples
```bash
# Minor release (New feature)
git commit -m "feat(auth): support passkey authentication via WebAuthn"

# Patch release (Bug fix)
git commit -m "fix(db): resolve connection pool leak during transaction rollback"

# Major release (Breaking change using '!')
git commit -m "feat(api)!: migrate customer endpoint from v1 to v2 schema"

# Major release (Breaking change using footer)
git commit -m "refactor(config): update environment variable names

BREAKING CHANGE: DB_URI has been renamed to DATABASE_URL."
```

---

## 2. Automated SemVer Bumping Algorithm

To determine the next version number given current version `vX.Y.Z`:

```
1. Fetch latest git tag:
   latest_tag = $(git describe --tags --abbrev=0 2>/dev/null) || "v0.0.0"

2. Inspect commits since tag:
   git log "$latest_tag..HEAD" --oneline

3. Evaluate SemVer precedence:
   IF commits contain "BREAKING CHANGE:" OR regex "^[a-z]+(\([^\)]+\))?!:"
       -> Increment MAJOR (X + 1), set Y = 0, Z = 0
   ELSE IF commits contain regex "^feat(\([^\)]+\))?:"
       -> Increment MINOR (Y + 1), set Z = 0
   ELSE IF commits contain regex "^(fix|perf)(\([^\)]+\))?:"
       -> Increment PATCH (Z + 1)
   ELSE
       -> No version bump required (or PATCH increment if release forced)
```

---

## 3. Changelog Synthesis Standard

When assembling release notes or updating `CHANGELOG.md`, group commits logically into Markdown sections:

```markdown
# Release v1.4.0 (2026-10-23)

### Features
- **auth:** Support passkey authentication via WebAuthn ([`a1b2c3d`](commit_url))
- **storage:** Implement IndexedDB version 2 migration ([`e4f5a6b`](commit_url))

### Bug Fixes
- **sync:** Prevent duplicate mutation dispatch during offline reconnect ([`7c8d9e0`](commit_url))

### Performance Improvements
- **cache:** Reduce JSON deserialization overhead in pipeline behavior ([`3f2e1d0`](commit_url))

### Maintenance & Chores
- **deps:** Bump @playwright/test from 1.48.0 to 1.50.0 ([`9b8a7c6`](commit_url))
```

---

## 4. GitHub CLI (`gh`) Release Automation

Publish releases, tag the repository, and attach distribution assets in a single atomic command.

```bash
# Create a release draft with auto-generated notes
gh release create v1.4.0 \
  --title "v1.4.0 - Passkey Support & Offline Resilience" \
  --generate-notes \
  --draft

# Create a published release with a custom notes file and asset binaries
gh release create v1.4.0 \
  --title "v1.4.0" \
  --notes-file ./RELEASE_NOTES.md \
  ./dist/app-x64-setup.exe \
  ./dist/checksums.txt

# Create a pre-release
gh release create v2.0.0-beta.1 \
  --title "v2.0.0-beta.1 Preview" \
  --prerelease \
  --notes "Public testing preview for v2 core engine."
```

---

## 5. Fallback Release Scripting via PowerShell & GitHub REST API

When the GitHub CLI is unavailable or running in environments where MCP endpoints are restricted, interact directly with the GitHub Releases API using PowerShell:

```powershell
# Publish release via GitHub REST API with environment variable authentication
$repo = "owner/repo-name"
$tag = "v1.4.0"
$token = $env:GITHUB_TOKEN

if (-not $token) {
    $token = $env:GITHUB_PERSONAL_ACCESS_TOKEN
}

if (-not $token) {
    throw "Authentication token not found in `$env:GITHUB_TOKEN or `$env:GITHUB_PERSONAL_ACCESS_TOKEN."
}

$headers = @{
    "Authorization" = "Bearer $token"
    "Accept"        = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

$releaseBody = @{
    tag_name         = $tag
    target_commitish = "main"
    name             = "Release $tag"
    body             = "Automated release deployment for $tag."
    draft            = $false
    prerelease       = $false
} | ConvertTo-Json

$response = Invoke-RestMethod `
    -Uri "https://api.github.com/repos/$repo/releases" `
    -Method Post `
    -Headers $headers `
    -Body $releaseBody `
    -ContentType "application/json"

Write-Output "Release published successfully: $($response.html_url)"
```
