# ==============================================================================
# devbox-win :: Module: Dotfiles
# Path: modules/dotfiles.ps1
# Description: Idempotent dotfile symlink manager with backup preservation.
# Standard: Zero emojis. Pure symlink mapping to standard system paths.
# ==============================================================================

param(
    [Parameter(Mandatory=$true)][System.Collections.IDictionary]$Config,
    [switch]$DryRun
)

Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "..\core\logger.ps1")
. (Join-Path $PSScriptRoot "..\core\symlink.ps1")
. (Join-Path $PSScriptRoot "..\core\manifest.ps1")

function Invoke-DevboxDotfilesModule {
    param(
        [System.Collections.IDictionary]$Config,
        [switch]$DryRun
    )

    $repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
    $manifest = Load-DevboxManifest

    # Define standard dotfile target mapping
    $dotfileMappings = @(
        @{
            Name        = "Git Config"
            Source      = Join-Path $repoRoot "dotfiles\.gitconfig"
            Destination = Join-Path $HOME ".gitconfig"
        },
        @{
            Name        = "GlazeWM Config"
            Source      = Join-Path $repoRoot "dotfiles\glazewm\config.yaml"
            Destination = Join-Path $HOME ".glzr\glazewm\config.yaml"
        },
        @{
            Name        = "Zebar Settings"
            Source      = Join-Path $repoRoot "dotfiles\zebar\settings.json"
            Destination = Join-Path $HOME ".glzr\zebar\settings.json"
        },
        @{
            Name        = "Zebar Config"
            Source      = Join-Path $repoRoot "dotfiles\zebar\config.yaml"
            Destination = Join-Path $HOME ".glzr\zebar\config.yaml"
        },
        @{
            Name        = "Starship Config"
            Source      = Join-Path $repoRoot "dotfiles\starship\starship.toml"
            Destination = Join-Path (Join-Path $HOME ".config") "starship.toml"
        },
        @{
            Name        = "AutoHotkey Config"
            Source      = Join-Path $repoRoot "dotfiles\ahk\hotkeys.ahk"
            Destination = Join-Path (Join-Path $HOME ".config\ahk") "hotkeys.ahk"
        }
    )

    Write-DevboxInfo "Processing $($dotfileMappings.Count) dotfile symlink definitions..."
    $linkedCount  = 0
    $skippedCount = 0
    $failedCount  = 0

    foreach ($entry in $dotfileMappings) {
        $name = $entry["Name"]
        $src  = $entry["Source"]
        $dst  = $entry["Destination"]

        if (-not (Test-Path $src)) {
            Write-DevboxSkip $name "Source file does not exist: $src"
            $skippedCount++
            continue
        }

        $res = New-DevboxSymlink -Source $src -Destination $dst -DryRun:$DryRun
        switch ($res.Status) {
            "OK" {
                Write-DevboxOk "$name -> $dst"
                if (-not $DryRun) {
                    Add-DevboxManifestSymlink -Manifest $manifest -Destination $dst -Source $src -BackupPath $res.BackupPath
                }
                $linkedCount++
            }
            "SKIP" {
                Write-DevboxSkip $name $res.Message
                $skippedCount++
            }
            "FAIL" {
                Write-DevboxFail "$name failed" $res.Message
                $failedCount++
            }
        }
    }

    if ($failedCount -gt 0) {
        return [PSCustomObject]@{
            Status  = "FAIL"
            Message = "$failedCount dotfile(s) failed to link"
        }
    }

    $summaryStatus = if ($linkedCount -gt 0) { "OK" } else { "SKIP" }
    return [PSCustomObject]@{
        Status  = $summaryStatus
        Message = "$linkedCount linked, $skippedCount skipped"
    }
}

Invoke-DevboxDotfilesModule -Config $Config -DryRun:$DryRun
