<#
.SYNOPSIS
    Compiles an AutoHotkey v2 script to an executable using Ahk2Exe.
.DESCRIPTION
    Validates AutoHotkey v2 compiler tools, compiles script with specified base and optional icon,
    and reports output binary size.
.PARAMETER In
    Path to input .ahk script file.
.PARAMETER Out
    Path to output .exe file. Defaults to input script path with .exe extension.
.PARAMETER Icon
    Optional path to .ico file for executable icon.
.PARAMETER Silent
    Compile silently without GUI popups.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$In,

    [Parameter(Position = 1)]
    [string]$Out,

    [Parameter()]
    [string]$Icon,

    [switch]$Silent = $true,

    [switch]$Help
)

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path
    exit 0
}

if ([string]::IsNullOrWhiteSpace($In)) {
    Write-Error "Parameter -In is required. Specify path to an AutoHotkey script or use -Help."
    exit 1
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ahk2exePath = 'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe'
$baseExePath = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'

# 1. Validate compiler tools
if (-not (Test-Path -Path $ahk2exePath)) {
    Write-Error "Ahk2Exe compiler not found at '$ahk2exePath'."
    exit 1
}

if (-not (Test-Path -Path $baseExePath)) {
    Write-Error "AutoHotkey v2 64-bit base binary not found at '$baseExePath'."
    exit 1
}

# 2. Resolve input file
if (-not (Test-Path -Path $In)) {
    Write-Error "Input script '$In' does not exist."
    exit 1
}
$resolvedIn = (Resolve-Path -Path $In).Path

# 3. Resolve output file
if ([string]::IsNullOrWhiteSpace($Out)) {
    $Out = [System.IO.Path]::ChangeExtension($resolvedIn, ".exe")
}
$resolvedOut = [System.IO.Path]::GetFullPath($Out)

# 4. Build argument list
$arguments = @(
    "/in", "`"$resolvedIn`"",
    "/out", "`"$resolvedOut`"",
    "/base", "`"$baseExePath`""
)

if (-not [string]::IsNullOrWhiteSpace($Icon)) {
    if (-not (Test-Path -Path $Icon)) {
        Write-Error "Icon file '$Icon' does not exist."
        exit 1
    }
    $resolvedIcon = (Resolve-Path -Path $Icon).Path
    $arguments += @("/icon", "`"$resolvedIcon`"")
}

if ($Silent) {
    $arguments += "/silent"
}

Write-Host "=========================================="
Write-Host "AutoHotkey v2 Build Automation"
Write-Host "Input:  $resolvedIn"
Write-Host "Output: $resolvedOut"
if (-not [string]::IsNullOrWhiteSpace($Icon)) {
    Write-Host "Icon:   $resolvedIcon"
}
Write-Host "=========================================="

# 5. Run compilation
$argString = $arguments -join ' '
$process = Start-Process -FilePath $ahk2exePath -ArgumentList $argString -Wait -PassThru -NoNewWindow

if ($process.ExitCode -ne 0) {
    Write-Error "Ahk2Exe compilation failed with exit code $($process.ExitCode)."
    exit $process.ExitCode
}

# 6. Verify output binary
if (-not (Test-Path -Path $resolvedOut)) {
    Write-Error "Output executable was not created at '$resolvedOut'."
    exit 1
}

$outputItem = Get-Item -Path $resolvedOut
$sizeKb = [Math]::Round($outputItem.Length / 1KB, 2)
$sizeMb = [Math]::Round($outputItem.Length / 1MB, 2)

Write-Host "[SUCCESS] Compilation completed successfully."
Write-Host "Binary: $($outputItem.FullName)"
Write-Host "Size:   $($outputItem.Length) bytes ($sizeKb KB / $sizeMb MB)"
Write-Host "Timestamp: $($outputItem.LastWriteTime)"
exit 0
