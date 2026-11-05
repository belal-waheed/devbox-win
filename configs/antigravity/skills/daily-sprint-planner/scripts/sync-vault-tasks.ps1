<#
.SYNOPSIS
    Reads and summarizes tasks from Obsidian Today.md note.
.DESCRIPTION
    Inspects ~\Documents\Vault\inbox\Today.md (or custom path), parses markdown task checkboxes,
    and reports counts and lists of open and completed tasks.
.PARAMETER Path
    Path to Today.md. Defaults to ~\Documents\Vault\inbox\Today.md.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path = '~\Documents\Vault\inbox\Today.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "=========================================="
Write-Host "Obsidian Vault Task Synchronizer"
Write-Host "Target: $Path"
Write-Host "=========================================="

if (-not (Test-Path -Path $Path)) {
    Write-Warning "Target file does not exist: $Path"
    Write-Host "Task file not found. Ensure vault is initialized at ~\Documents\Vault"
    exit 0
}

$lines = Get-Content -Path $Path -Encoding utf8

$openTasks = [System.Collections.Generic.List[string]]::new()
$completedTasks = [System.Collections.Generic.List[string]]::new()

foreach ($line in $lines) {
    if ($line -match '^\s*-\s+\[ \]\s+(.*)$') {
        $openTasks.Add($matches[1].Trim())
    } elseif ($line -match '^\s*-\s+\[x\]\s+(.*)$') {
        $completedTasks.Add($matches[1].Trim())
    }
}

Write-Host "Task Summary:"
Write-Host "  - Open Tasks:      $($openTasks.Count)"
Write-Host "  - Completed Tasks: $($completedTasks.Count)"
Write-Host ""

if ($openTasks.Count -gt 0) {
    Write-Host "Open Tasks:"
    foreach ($task in $openTasks) {
        Write-Host "  [ ] $task"
    }
    Write-Host ""
}

if ($completedTasks.Count -gt 0) {
    Write-Host "Completed Tasks:"
    foreach ($task in $completedTasks) {
        Write-Host "  [x] $task"
    }
    Write-Host ""
}

exit 0
