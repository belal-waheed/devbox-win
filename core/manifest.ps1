# ==============================================================================
# devbox-win :: Core Manifest Manager
# Path: core/manifest.ps1
# Description: Tracking of modifications for idempotent reverts and uninstalls.
# Standard: Zero emojis. Pure, safe restoration of original machine state.
# ==============================================================================

Set-StrictMode -Version Latest

function Get-DevboxManifestPath {
    $stateDir = Join-Path $HOME ".devbox-win"
    if (-not (Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }
    return (Join-Path $stateDir "manifest.json")
}

function New-DevboxManifestTemplate {
    return [ordered]@{
        schemaVersion = "1.0.0"
        createdAt     = (Get-Date -Format "o")
        updatedAt     = (Get-Date -Format "o")
        symlinks      = @()
        packages      = @()
        envvars       = @()
        shortcuts     = @()
        gitConfig     = @()
    }
}

function Load-DevboxManifest {
    $path = Get-DevboxManifestPath
    if (Test-Path $path) {
        try {
            $raw = Get-Content -Path $path -Raw -Encoding utf8
            $manifest = $raw | ConvertFrom-Json -AsHashtable
            if ($null -ne $manifest) {
                return $manifest
            }
        } catch {
            # Fall through to new manifest
        }
    }
    return New-DevboxManifestTemplate
}

function Save-DevboxManifest {
    param([System.Collections.IDictionary]$Manifest)

    $Manifest["updatedAt"] = (Get-Date -Format "o")
    $path = Get-DevboxManifestPath
    $json = $Manifest | ConvertTo-Json -Depth 10
    Set-Content -Path $path -Value $json -Encoding utf8
}

function Add-DevboxManifestSymlink {
    param(
        [System.Collections.IDictionary]$Manifest,
        [string]$Destination,
        [string]$Source,
        [string]$BackupPath = $null
    )

    $symlinks = [System.Collections.Generic.List[object]]::new(@($Manifest["symlinks"]))
    $filtered = @($symlinks | Where-Object { $_.destination -ne $Destination })
    $symlinks = [System.Collections.Generic.List[object]]::new($filtered)

    $symlinks.Add([ordered]@{
        destination = $Destination
        source      = $Source
        backupPath  = $BackupPath
        timestamp   = (Get-Date -Format "o")
    })

    $Manifest["symlinks"] = @($symlinks)
    Save-DevboxManifest -Manifest $Manifest
}

function Add-DevboxManifestPackage {
    param(
        [System.Collections.IDictionary]$Manifest,
        [string]$PackageId
    )

    $pkgs = [System.Collections.Generic.List[string]]::new(@($Manifest["packages"]))
    if (-not $pkgs.Contains($PackageId)) {
        $pkgs.Add($PackageId)
        $Manifest["packages"] = @($pkgs)
        Save-DevboxManifest -Manifest $Manifest
    }
}

function Add-DevboxManifestEnvVar {
    param(
        [System.Collections.IDictionary]$Manifest,
        [string]$Name,
        [string]$PreviousValue = $null
    )

    $vars = [System.Collections.Generic.List[object]]::new(@($Manifest["envvars"]))
    $filtered = @($vars | Where-Object { $_.name -ne $Name })
    $vars = [System.Collections.Generic.List[object]]::new($filtered)

    $vars.Add([ordered]@{
        name          = $Name
        previousValue = $PreviousValue
        timestamp     = (Get-Date -Format "o")
    })

    $Manifest["envvars"] = @($vars)
    Save-DevboxManifest -Manifest $Manifest
}

function Add-DevboxManifestShortcut {
    param(
        [System.Collections.IDictionary]$Manifest,
        [string]$Path
    )

    $shortcuts = [System.Collections.Generic.List[string]]::new(@(if ($Manifest.Contains("shortcuts")) { $Manifest["shortcuts"] } else { @() }))
    if (-not $shortcuts.Contains($Path)) {
        $shortcuts.Add($Path)
        $Manifest["shortcuts"] = @($shortcuts)
        Save-DevboxManifest -Manifest $Manifest
    }
}

function Invoke-DevboxRevert {
    param(
        [switch]$UninstallPackages,
        [switch]$DryRun
    )

    . (Join-Path $PSScriptRoot "logger.ps1")
    $manifest = Load-DevboxManifest

    Write-DevboxSection "Uninstall / Revert devbox-win"

    # 1. Revert symlinks
    $symlinks = @($manifest["symlinks"])
    Write-DevboxInfo "Reverting $($symlinks.Count) registered symlinks..."
    foreach ($entry in $symlinks) {
        $dest = $entry["destination"]
        $backup = $entry["backupPath"]

        if (Test-Path -LiteralPath $dest) {
            $item = Get-Item -LiteralPath $dest -Force
            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                if ($DryRun) {
                    Write-DevboxDryRun "Would remove symlink: $dest"
                } else {
                    Remove-Item -LiteralPath $dest -Force
                    Write-DevboxOk "Removed symlink: $dest"
                }
            }
        }

        # Restore backup if available
        if ($backup -and (Test-Path -LiteralPath $backup)) {
            if ($DryRun) {
                Write-DevboxDryRun "Would restore backup from '$backup' to '$dest'"
            } else {
                Move-Item -LiteralPath $backup -Destination $dest -Force
                Write-DevboxOk "Restored original backup to: $dest"
            }
        }
    }

    # 2. Revert environment variables
    $envvars = @($manifest["envvars"])
    foreach ($v in $envvars) {
        $name = $v["name"]
        $prev = $v["previousValue"]
        if ($DryRun) {
            Write-DevboxDryRun "Would reset env var: $name"
        } else {
            [System.Environment]::SetEnvironmentVariable($name, $prev, [System.EnvironmentVariableTarget]::User)
            Write-DevboxOk "Reset environment variable: $name"
        }
    }

    # 3. Revert startup shortcuts
    $shortcuts = if ($manifest.Contains("shortcuts")) { @($manifest["shortcuts"]) } else { @() }
    $wsh = New-Object -ComObject WScript.Shell
    $startupDir = $wsh.SpecialFolders.Item("Startup")
    $defaultShortcuts = @(
        (Join-Path $startupDir "devbox-hotkeys.lnk"),
        (Join-Path $startupDir "GlazeWM.lnk"),
        (Join-Path $startupDir "Zebar.lnk")
    )
    $allShortcuts = @($shortcuts + $defaultShortcuts) | Select-Object -Unique
    foreach ($sc in $allShortcuts) {
        if (Test-Path -LiteralPath $sc) {
            if ($DryRun) {
                Write-DevboxDryRun "Would remove shortcut: $sc"
            } else {
                Remove-Item -LiteralPath $sc -Force
                Write-DevboxOk "Removed shortcut: $sc"
            }
        }
    }

    # 4. Optional package uninstallation
    if ($UninstallPackages) {
        $packages = @($manifest["packages"])
        foreach ($pkg in $packages) {
            if ($DryRun) {
                Write-DevboxDryRun "Would uninstall package: $pkg"
            } else {
                Write-DevboxInfo "Uninstalling $pkg via winget..."
                & winget uninstall --id $pkg --silent --accept-source-agreements
                Write-DevboxOk "Uninstalled: $pkg"
            }
        }
    }

    Write-DevboxOk "Revert completed."
}
