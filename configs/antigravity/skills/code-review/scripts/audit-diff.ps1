<#
.SYNOPSIS
    Local git diff auditor for code review compliance.
.DESCRIPTION
    Audits staged and unstaged git diffs against Antigravity guardrails:
    - Flags forbidden emojis (Unicode emoji blocks)
    - Flags destructive commands (rmdir /s, rm -rf, git reset --hard, git clean -fd)
    - Warns when source changes lack corresponding test coverage
.PARAMETER Path
    Repository directory to inspect. Defaults to current directory.
.PARAMETER StagedOnly
    Only inspect staged git diff.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path = (Get-Location).Path,

    [switch]$StagedOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -Path (Join-Path $Path ".git"))) {
    Write-Error "Not a git repository: $Path"
    exit 1
}

$diffArgs = @("diff")
if ($StagedOnly) {
    $diffArgs += "--cached"
}

$diffOutput = & git -C $Path @diffArgs
$statusOutput = & git -C $Path status --porcelain

$issues = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

# 1. Emoji Detection (Unicode regex without emojis in pattern)
$emojiPattern = '[\uD83C-\uDBFF\uDC00-\uDFFF\u2600-\u26FF\u2700-\u27BF]'
$addedLines = $diffOutput -split "`r?`n" | Where-Object { $_ -match '^\+[^+]' }

foreach ($line in $addedLines) {
    if ($line -match $emojiPattern) {
        $cleanLine = $line.TrimStart('+').Trim()
        if ($cleanLine.Length -gt 60) { $cleanLine = $cleanLine.Substring(0, 57) + "..." }
        $issues.Add("Forbidden emoji detected in added line: $cleanLine")
    }
}

# 2. Destructive Command Detection
$destructivePatterns = @(
    'rmdir\s+/[sS]',
    'rm\s+-rf',
    'git\s+reset\s+--hard',
    'git\s+push\s+.*--force',
    'git\s+clean\s+-[a-zA-Z]*f'
)

foreach ($line in $addedLines) {
    foreach ($pat in $destructivePatterns) {
        if ($line -match $pat) {
            $cleanLine = $line.TrimStart('+').Trim()
            $issues.Add("Destructive command detected: $cleanLine")
        }
    }
}

# 3. Missing Test Coverage Check
$changedFiles = $statusOutput -split "`r?`n" | ForEach-Object {
    if ($_ -match '^[ MADRCU?!]{2}\s+(.*)$') { $matches[1] }
}

$sourceFiles = $changedFiles | Where-Object {
    $_ -match '\.(ts|tsx|js|jsx|cs|py|go|rs)$' -and $_ -notmatch '(\.test\.|\.spec\.|Tests?\.|\/tests?\/)'
}

$testFiles = $changedFiles | Where-Object {
    $_ -match '(\.test\.|\.spec\.|Tests?\.|\/tests?\/)'
}

if ($sourceFiles.Count -gt 0 -and $testFiles.Count -eq 0) {
    $warnings.Add("Source files modified ($($sourceFiles.Count) files) without corresponding test files.")
}

# Output report
Write-Host "=========================================="
Write-Host "Antigravity Code Review Diff Audit"
Write-Host "Repository: $Path"
Write-Host "=========================================="

if ($issues.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "[PASS] Zero guardrail violations detected."
    exit 0
}

if ($issues.Count -gt 0) {
    Write-Host "[FAIL] Found $($issues.Count) critical violations:"
    foreach ($iss in $issues) {
        Write-Host "  - ERROR: $iss"
    }
}

if ($warnings.Count -gt 0) {
    Write-Host "[WARN] Found $($warnings.Count) warnings:"
    foreach ($warn in $warnings) {
        Write-Host "  - WARNING: $warn"
    }
}

if ($issues.Count -gt 0) {
    exit 1
}
exit 0
