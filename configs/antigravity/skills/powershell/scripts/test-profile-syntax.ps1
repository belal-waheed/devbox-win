<#
.SYNOPSIS
    Validates PowerShell script syntax, encoding, and -NoProfile compliance.
.DESCRIPTION
    Uses AST Parser ([System.Management.Automation.Language.Parser]) to parse PowerShell scripts,
    verifies UTF-8 encoding compliance without invalid byte sequences, and flags any powershell/pwsh
    invocations missing the mandatory -NoProfile switch.
.PARAMETER Path
    Path to .ps1 or .psm1 file to validate.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -Path $Path)) {
    Write-Error "Target file '$Path' does not exist."
    exit 1
}

$resolvedPath = (Resolve-Path -Path $Path).Path
Write-Host "=========================================="
Write-Host "PowerShell Syntax & Compliance Auditor"
Write-Host "Target: $resolvedPath"
Write-Host "=========================================="

$issues = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

# 1. AST Syntax Parsing
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($resolvedPath, [ref]$tokens, [ref]$parseErrors)

if ($parseErrors.Count -gt 0) {
    foreach ($err in $parseErrors) {
        $issues.Add("Syntax Error at line $($err.Extent.StartLineNumber): $($err.Message)")
    }
} else {
    Write-Host "[PASS] AST Parser reported 0 syntax errors."
}

# 2. UTF-8 Encoding Check
try {
    $bytes = [System.IO.File]::ReadAllBytes($resolvedPath)
    $utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)
    $content = $utf8Strict.GetString($bytes)

    # Check for BOM
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $warnings.Add("File has UTF-8 BOM. UTF-8 without BOM is preferred for cross-platform PowerShell.")
    } else {
        Write-Host "[PASS] File encoded in valid UTF-8."
    }
} catch [System.Text.DecoderFallbackException] {
    $issues.Add("File contains byte sequences invalid in UTF-8 encoding.")
}

# 3. -NoProfile Compliance Check
$commandAsts = $ast.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.CommandAst]
}, $true)

foreach ($cmd in $commandAsts) {
    $commandName = $cmd.GetCommandName()
    if ($commandName -in @('pwsh', 'pwsh.exe', 'powershell', 'powershell.exe')) {
        $cmdText = $cmd.Extent.Text
        if ($cmdText -notmatch '(?i)-NoProfile\b') {
            $issues.Add("Shell invocation missing -NoProfile at line $($cmd.Extent.StartLineNumber): $cmdText")
        }
    }
}

# 4. Output Summary
if ($issues.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "[SUCCESS] All checks passed. Zero issues detected."
    exit 0
}

if ($issues.Count -gt 0) {
    Write-Host "[FAIL] Found $($issues.Count) critical issues:"
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
