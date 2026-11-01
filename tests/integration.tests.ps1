# ==============================================================================
# devbox-win :: Subprocess & Lifecycle Integration Test Suite
# Path: tests/integration.tests.ps1
# Standard: Zero emojis. Real process execution verification.
# ==============================================================================

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ANSI Terminal Formatting
$C_Reset   = "`e[0m"
$C_Bold    = "`e[1m"
$C_Cyan    = "`e[36m"
$C_Green   = "`e[32m"
$C_Yellow  = "`e[33m"
$C_Red     = "`e[31m"
$C_Gray    = "`e[90m"

$script:passCount = 0
$script:failCount = 0

function Write-DevboxBanner {
    param([string]$SubTitle = "Subprocess & Lifecycle Integration Test Suite")
    Write-Host ""
    Write-Host "$C_Cyan$C_Bold==============================================================================$C_Reset"
    Write-Host "  $SubTitle"
    Write-Host "  Host: $env:COMPUTERNAME  |  User: $env:USERNAME  |  PowerShell: $($PSVersionTable.PSVersion)"
    Write-Host "$C_Cyan$C_Bold==============================================================================$C_Reset"
    Write-Host ""
}

function Write-DevboxSection([string]$title) {
    Write-Host ""
    Write-Host "$C_Cyan[== $title =====================================================]$C_Reset"
}

function Assert-True([bool]$condition, [string]$message) {
    if ($condition) {
        Write-Host "  $C_Green[OK] TEST PASS:$C_Reset $message"
        $script:passCount++
    } else {
        Write-Host "  $C_Red[FAIL] TEST FAIL:$C_Reset $message"
        $script:failCount++
    }
}

function Assert-Equal($actual, $expected, [string]$message) {
    if ($actual -eq $expected) {
        Write-Host "  $C_Green[OK] TEST PASS:$C_Reset $message (Value: '$actual')"
        $script:passCount++
    } else {
        Write-Host "  $C_Red[FAIL] TEST FAIL:$C_Reset $message (Expected: '$expected', Actual: '$actual')"
        $script:failCount++
    }
}

function Invoke-SubprocessCapture {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$true)][string[]]$ArgumentList,
        [hashtable]$EnvironmentVariables = @{},
        [int]$TimeoutSeconds = 120
    )

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FilePath
    foreach ($arg in $ArgumentList) {
        $psi.ArgumentList.Add($arg)
    }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    foreach ($kv in $EnvironmentVariables.GetEnumerator()) {
        $psi.EnvironmentVariables[$kv.Key] = [string]$kv.Value
    }

    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdOutTask = $proc.StandardOutput.ReadToEndAsync()
    $stdErrTask = $proc.StandardError.ReadToEndAsync()

    $finished = $proc.WaitForExit($TimeoutSeconds * 1000)
    if (-not $finished) {
        try { $proc.Kill() } catch {}
        throw "Process '$FilePath' timed out after $TimeoutSeconds seconds."
    }

    $proc.WaitForExit()

    $stdOut = $stdOutTask.GetAwaiter().GetResult()
    $stdErr = $stdErrTask.GetAwaiter().GetResult()

    return [PSCustomObject]@{
        ExitCode = $proc.ExitCode
        StdOut   = $stdOut
        StdErr   = $stdErr
        Crashed  = ($proc.ExitCode -ne 0 -and $null -ne $proc.ExitCode)
    }
}

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$bootstrapPath = Join-Path $repoRoot "bootstrap.ps1"
$lifecyclePath = Join-Path $repoRoot "core\lifecycle.ps1"

Write-DevboxBanner

# ------------------------------------------------------------------------------
# Test 1: Real Subprocess Execution (PowerShell 7)
# ------------------------------------------------------------------------------
Write-DevboxSection "Test 1: PowerShell 7 Subprocess Execution"
$cmd1 = "& '$bootstrapPath' -DryRun -NonInteractive"
$res1 = Invoke-SubprocessCapture -FilePath "pwsh.exe" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $cmd1)

Assert-Equal $res1.ExitCode 0 "pwsh subprocess exited with code 0"
Assert-True ($res1.StdOut -match "Planned Execution DAG") "stdout contains 'Planned Execution DAG'"
Assert-True ($res1.StdOut -match "All modules processed successfully") "stdout indicates all modules completed"
Assert-True (-not $res1.Crashed) "pwsh subprocess did not crash"

# ------------------------------------------------------------------------------
# Test 2: In-Memory Invoke-Expression Simulation
# ------------------------------------------------------------------------------
Write-DevboxSection "Test 2: In-Memory Invoke-Expression Simulation"
# Simulates pipeline execution (irm ... | iex) inside an interactive host.
# Proves that unhandled 'exit' calls do NOT kill the host process in-memory.
$cmd2 = @"
`$content = Get-Content '$bootstrapPath' -Raw
Invoke-Expression "& { `$content } -DryRun -NonInteractive"
"@
$res2 = Invoke-SubprocessCapture -FilePath "pwsh.exe" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $cmd2)

Assert-Equal $res2.ExitCode 0 "In-memory Invoke-Expression exited with code 0"
Assert-True ($res2.StdOut -match "Planned Execution DAG") "In-memory execution produces Planned Execution DAG"
Assert-True ($res2.StdOut -match "All modules processed successfully") "In-memory execution completed all modules"
Assert-True (-not $res2.Crashed) "Host shell did not terminate prematurely"

# ------------------------------------------------------------------------------
# Test 3: Windows PowerShell 5.1 Respawner Test
# ------------------------------------------------------------------------------
Write-DevboxSection "Test 3: Windows PowerShell 5.1 Respawner Test"
$cmd3 = "& '$bootstrapPath' -DryRun -NonInteractive"
$res3 = Invoke-SubprocessCapture -FilePath "powershell.exe" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $cmd3)

Assert-Equal $res3.ExitCode 0 "powershell.exe 5.1 respawner exited with code 0"
Assert-True ($res3.StdOut -match "Running in Windows PowerShell") "Detected Windows PowerShell 5.1 runtime"
Assert-True ($res3.StdOut -match "Respawning under PowerShell 7") "Successfully triggered PowerShell 7 respawn"
Assert-True ($res3.StdOut -match "Planned Execution DAG") "Respawned child executed Planned Execution DAG"
Assert-True ($res3.StdOut -match "All modules processed successfully") "Respawned child completed successfully"
Assert-True (-not $res3.Crashed) "Parent powershell.exe session remained stable without crashing"

# ------------------------------------------------------------------------------
# Test 4: Process Ownership & Headless Child Contract
# ------------------------------------------------------------------------------
Write-DevboxSection "Test 4: Process Ownership Contract"

# Contract 4a: In-memory execution without DEVBOX_HEADLESS_CHILD returns exit code without exiting
$cmd4a = @"
. '$lifecyclePath'
`$res0 = Complete-DevboxSession -ExitCode 0
`$res42 = Complete-DevboxSession -ExitCode 42
Write-Host "RES0:`$res0"
Write-Host "RES42:`$res42"
Write-Host "LASTEXIT:`$global:LASTEXITCODE"
"@
$res4a = Invoke-SubprocessCapture -FilePath "pwsh.exe" -ArgumentList @("-NoProfile", "-Command", $cmd4a)
Assert-Equal $res4a.ExitCode 0 "In-memory session returns exit code without exiting"
Assert-True ($res4a.StdOut -match "RES0:0") "Complete-DevboxSession returns 0"
Assert-True ($res4a.StdOut -match "RES42:42") "Complete-DevboxSession returns 42"
Assert-True ($res4a.StdOut -match "LASTEXIT:42") "global:LASTEXITCODE updated to 42"

# Contract 4b: Headless child (DEVBOX_HEADLESS_CHILD=1) terminates process immediately
$cmd4b = @"
`$env:DEVBOX_HEADLESS_CHILD = '1'
. '$lifecyclePath'
Complete-DevboxSession -ExitCode 7
Write-Host 'SHOULD_NOT_EXECUTE'
"@
$res4b = Invoke-SubprocessCapture -FilePath "pwsh.exe" -ArgumentList @("-NoProfile", "-Command", $cmd4b)
Assert-Equal $res4b.ExitCode 7 "Headless child process terminated with requested ExitCode 7"
Assert-True ($res4b.StdOut -notmatch "SHOULD_NOT_EXECUTE") "Code after Complete-DevboxSession was unreachable"

# ------------------------------------------------------------------------------
# Test 5: Parameter Forwarding & Preset Override
# ------------------------------------------------------------------------------
Write-DevboxSection "Test 5: Parameter Forwarding & Preset Override"
$cmd5 = "& '$bootstrapPath' -Preset minimal -DryRun -NonInteractive"
$res5 = Invoke-SubprocessCapture -FilePath "pwsh.exe" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $cmd5)

Assert-Equal $res5.ExitCode 0 "pwsh execution with -Preset minimal exited with code 0"
Assert-True ($res5.StdOut -match "Active preset override: minimal") "Output confirms active preset override: minimal"
Assert-True ($res5.StdOut -match "Planned Execution DAG") "Preset execution generated execution DAG"
Assert-True (-not $res5.Crashed) "Preset execution completed without crashing"

# ------------------------------------------------------------------------------
# Test 6: Bootstrap GUI Launch Decision & Headless Override Verification
# ------------------------------------------------------------------------------
Write-DevboxSection "Test 6: Bootstrap GUI Launch Decision & Headless Override Verification"
$cmd6 = "& '$bootstrapPath' -Preset minimal -DryRun -NonInteractive"
$res6 = Invoke-SubprocessCapture -FilePath "pwsh.exe" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $cmd6)

Assert-Equal $res6.ExitCode 0 "Bootstrap with -Preset and -NonInteractive exited with code 0"
Assert-True ($res6.StdOut -match "Transferring execution to core engine") "StdOut confirms transfer to core engine headlessly"
Assert-True ($res6.StdOut -notmatch "Launching devbox-win Windows Developer Utility \(GUI\)") "StdOut confirms GUI was bypassed under -NonInteractive"

# ------------------------------------------------------------------------------
# Test 7: Real End-to-End Single-Item GUI Blueprint Execution
# ------------------------------------------------------------------------------
Write-DevboxSection "Test 7: Real End-to-End Single-Item GUI Blueprint Execution"

$tmpYaml = Join-Path $env:TEMP ("devbox_single_item_blueprint_" + [System.Guid]::NewGuid().ToString("N") + ".yaml")
$singleItemConfig = @"
modules:
  fonts: false
  envvars: false
  git: false
  shell: false
  editor: false
  packages: false
  runtimes: false
  databases: true
  keybindings: false
  glazewm: false
  zebar: false
  dotfiles: true
databases:
  - SQLite.SQLite
"@
Set-Content -Path $tmpYaml -Value $singleItemConfig -Encoding utf8

try {
    $engineScriptPath = Join-Path $repoRoot "core\engine.ps1"
    $res7 = Invoke-SubprocessCapture -FilePath "pwsh.exe" -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $engineScriptPath,
        "-ConfigFile", $tmpYaml,
        "-DryRun"
    )

    Assert-Equal $res7.ExitCode 0 "Engine exited with code 0 on single-item database configuration"
    Assert-True ($res7.StdOut -match "Execution Order: databases -> dotfiles") "Execution order generated correctly"
    Assert-True ($res7.StdOut -match "Evaluating 1 database client\(s\) and toolchain\(s\)") "Evaluates exactly 1 database client"
    Assert-True ($res7.StdOut -match "SQLite\.SQLite.*(Already installed|CLI tool present|Would install)") "Processes SQLite.SQLite safely without pipeline unrolling crash"
    Assert-True ($res7.StdOut -match "\[FAIL\] Failed\s+:\s+0") "Execution summary reports 0 failures"
    Assert-True ($res7.StdOut -match "All modules processed successfully") "All modules completed successfully"
    Assert-True ($res7.StdOut -notmatch "PropertyNotFoundException") "Zero PropertyNotFoundException in stdout"
    Assert-True ($res7.StdOut -notmatch "Module execution failed") "Zero module execution failures in stdout"
} finally {
    if (Test-Path $tmpYaml) {
        Remove-Item -Path $tmpYaml -Force -ErrorAction SilentlyContinue
    }
}

# ------------------------------------------------------------------------------
# Test 8: Real End-to-End GUI Runtimes Blueprint Execution
# ------------------------------------------------------------------------------
Write-DevboxSection "Test 8: Real End-to-End GUI Runtimes Blueprint Execution"

$tmpGuiYaml = Join-Path $env:TEMP ("devbox_gui_runtimes_blueprint_" + [System.Guid]::NewGuid().ToString("N") + ".yaml")
$guiRuntimesConfig = @"
modules:
  fonts: false
  envvars: false
  git: false
  shell: false
  editor: false
  packages: false
  runtimes: true
  databases: false
  keybindings: false
  glazewm: false
  zebar: false
  dotfiles: false
runtimes:
  git: false
  node: true
  python: false
  rust: false
  dotnet: false
"@
Set-Content -Path $tmpGuiYaml -Value $guiRuntimesConfig -Encoding utf8

try {
    $engineScriptPath = Join-Path $repoRoot "core\engine.ps1"
    $res8 = Invoke-SubprocessCapture -FilePath "pwsh.exe" -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $engineScriptPath,
        "-ConfigFile", $tmpGuiYaml,
        "-DryRun"
    )

    Assert-Equal $res8.ExitCode 0 "Engine exited with code 0 on GUI runtimes boolean blueprint"
    Assert-True ($res8.StdOut -match "Execution Order: runtimes") "Execution order generated correctly"
    Assert-True ($res8.StdOut -match "\[FAIL\] Failed\s+:\s+0") "Execution summary reports 0 failures"
    Assert-True ($res8.StdOut -match "All modules processed successfully") "All modules completed successfully"
    Assert-True ($res8.StdOut -notmatch "PropertyNotFoundException") "Zero PropertyNotFoundException in stdout"
    Assert-True ($res8.StdOut -notmatch "MethodInvocationException") "Zero MethodInvocationException in stdout"
    Assert-True ($res8.StdOut -notmatch "does not contain a method named 'Contains'") "Zero Contains method errors in stdout"
    Assert-True ($res8.StdOut -notmatch "Module execution failed") "Zero module execution failures in stdout"
} finally {
    if (Test-Path $tmpGuiYaml) {
        Remove-Item -Path $tmpGuiYaml -Force -ErrorAction SilentlyContinue
    }
}

# ------------------------------------------------------------------------------
# Final Test Summary
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "=============================================================================="
Write-Host "  Integration Test Suite Results: $passCount passed, $failCount failed"
Write-Host "=============================================================================="

if ($failCount -gt 0) {
    exit 1
} else {
    exit 0
}
