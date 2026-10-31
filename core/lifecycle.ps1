# ==============================================================================
# devbox-win :: Process Lifecycle & Session Termination Manager
# Path: core/lifecycle.ps1
# Standard: Zero emojis. Clean termination contracts for interactive vs headless.
# ==============================================================================

Set-StrictMode -Version Latest

function Test-DevboxOwnsFileProcess {
    <#
    .SYNOPSIS
        Determines whether the current PowerShell host process was launched directly
        via CLI (-File) to run a script file, as opposed to an interactive or in-memory session (iex/irm).
    .OUTPUTS
        [bool] True if the host process was started with -File and owns the execution lifecycle;
               False if invoked in-memory (Invoke-Expression), interactive console, or -Command.
    #>
    [CmdletBinding()]
    param()

    # In-memory execution (iex, irm | iex, scriptblock invocation) has no PSCommandPath
    if ([string]::IsNullOrWhiteSpace($PSCommandPath)) {
        return $false
    }

    try {
        $cmdArgs = [System.Environment]::GetCommandLineArgs()
        if ($null -eq $cmdArgs -or $cmdArgs.Count -eq 0) {
            return $false
        }

        # Check if the process was launched with -File / -f
        for ($i = 0; $i -lt $cmdArgs.Count; $i++) {
            $arg = $cmdArgs[$i]
            if ($arg -match '^[-/](f|file)$') {
                return $true
            }
        }

        return $false
    } catch {
        return $false
    }
}

function Complete-DevboxSession {
    <#
    .SYNOPSIS
        Safely completes a devbox-win execution session with the given exit code.
    .DESCRIPTION
        In headless subprocesses or CLI file processes (pwsh -File ...), terminates the process
        with the requested exit code. In interactive terminal sessions or in-memory invocations
        (irm ... | iex), returns the exit code without closing the host console window.
    .PARAMETER ExitCode
        Process exit code (default: 0).
    .OUTPUTS
        [int] The ExitCode value when returning to caller.
    #>
    param([int]$ExitCode = 0)
    $global:LASTEXITCODE = $ExitCode
    if ($env:DEVBOX_HEADLESS_CHILD -eq "1" -or (Test-DevboxOwnsFileProcess)) {
        exit $ExitCode
    }
    return $ExitCode
}


