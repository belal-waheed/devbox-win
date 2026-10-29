# ==============================================================================
# devbox-win :: Module: Shell
# Path: modules/shell.ps1
# Description: Configures Windows Terminal, PowerShell profile, prompt theme.
# Standard: Zero emojis. Idempotent configuration and backup protection.
# ==============================================================================

param(
    [Parameter(Mandatory=$true)][System.Collections.IDictionary]$Config,
    [switch]$DryRun
)

Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "..\core\logger.ps1")
. (Join-Path $PSScriptRoot "..\core\symlink.ps1")
. (Join-Path $PSScriptRoot "..\core\manifest.ps1")

function Resolve-TerminalSettingsPath {
    $standard = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    $preview  = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"

    if (Test-Path (Split-Path $standard -Parent)) {
        return $standard
    }
    if (Test-Path (Split-Path $preview -Parent)) {
        return $preview
    }
    return $standard
}

function Invoke-DevboxShellModule {
    param(
        [System.Collections.IDictionary]$Config,
        [switch]$DryRun
    )

    $repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
    $manifest = Load-DevboxManifest

    # 1. Windows Terminal configuration
    $wtSource = Join-Path $repoRoot "dotfiles\terminal\settings.json"
    $wtDest   = Resolve-TerminalSettingsPath

    if (Test-Path $wtSource) {
        Write-DevboxInfo "Configuring Windows Terminal settings..."
        $linkRes = New-DevboxSymlink -Source $wtSource -Destination $wtDest -DryRun:$DryRun
        switch ($linkRes.Status) {
            "OK"   { Write-DevboxOk $linkRes.Message; if (-not $DryRun) { Add-DevboxManifestSymlink -Manifest $manifest -Destination $wtDest -Source $wtSource -BackupPath $linkRes.BackupPath } }
            "SKIP" { Write-DevboxSkip "Windows Terminal" $linkRes.Message }
            "FAIL" { Write-DevboxFail "Windows Terminal link failed" $linkRes.Message }
        }
    }

    # 2. PowerShell Profile configuration
    $profileSource = Join-Path $repoRoot "dotfiles\pwsh\Microsoft.PowerShell_profile.ps1"
    $profileDest   = $PROFILE

    if (Test-Path $profileSource) {
        Write-DevboxInfo "Configuring PowerShell 7 profile..."
        $linkRes = New-DevboxSymlink -Source $profileSource -Destination $profileDest -DryRun:$DryRun
        switch ($linkRes.Status) {
            "OK"   { Write-DevboxOk $linkRes.Message; if (-not $DryRun) { Add-DevboxManifestSymlink -Manifest $manifest -Destination $profileDest -Source $profileSource -BackupPath $linkRes.BackupPath } }
            "SKIP" { Write-DevboxSkip "PowerShell Profile" $linkRes.Message }
            "FAIL" { Write-DevboxFail "PowerShell Profile link failed" $linkRes.Message }
        }
    }

    # 3. Prompt Configuration (Starship / Oh My Posh)
    $shellConfig = if ($Config.Contains("shell") -and ($null -ne $Config["shell"])) { $Config["shell"] } else { @{} }
    $promptType  = if ($shellConfig.Contains("prompt")) { $shellConfig["prompt"] } else { "starship" }

    if ($promptType -eq "starship") {
        $starshipSource = Join-Path $repoRoot "dotfiles\starship\starship.toml"
        $starshipDestDir = Join-Path $HOME ".config"
        $starshipDest = Join-Path $starshipDestDir "starship.toml"

        if (Test-Path $starshipSource) {
            Write-DevboxInfo "Configuring Starship prompt theme..."
            $linkRes = New-DevboxSymlink -Source $starshipSource -Destination $starshipDest -DryRun:$DryRun
            switch ($linkRes.Status) {
                "OK"   { Write-DevboxOk $linkRes.Message; if (-not $DryRun) { Add-DevboxManifestSymlink -Manifest $manifest -Destination $starshipDest -Source $starshipSource -BackupPath $linkRes.BackupPath } }
                "SKIP" { Write-DevboxSkip "Starship Config" $linkRes.Message }
                "FAIL" { Write-DevboxFail "Starship Config link failed" $linkRes.Message }
            }
        }
    }

    return [PSCustomObject]@{
        Status  = "OK"
        Message = "Shell environment configured"
    }
}

Invoke-DevboxShellModule -Config $Config -DryRun:$DryRun
