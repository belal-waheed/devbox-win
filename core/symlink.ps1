# ==============================================================================
# devbox-win :: Core Symlink Manager
# Path: core/symlink.ps1
# Description: Idempotent symbolic link creation, backup existing files, validation.
# Standard: Zero emojis. Clean, defensive filesystem operations.
# ==============================================================================

Set-StrictMode -Version Latest

function Get-DevboxBackupDir {
    $backupDir = Join-Path (Join-Path $HOME ".devbox-win") "backups"
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }
    return $backupDir
}

function Test-DevboxSymlinkTarget {
    param(
        [string]$LinkPath,
        [string]$ExpectedSource
    )

    if (-not (Test-Path -LiteralPath $LinkPath)) {
        return $false
    }

    $item = Get-Item -LiteralPath $LinkPath -Force
    if (-not ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        return $false
    }

    $actualTarget = $item.Target
    if ($actualTarget -is [array]) {
        $actualTarget = $actualTarget[0]
    }

    $normActual   = [System.IO.Path]::GetFullPath($actualTarget).TrimEnd('\', '/')
    $normExpected = [System.IO.Path]::GetFullPath($ExpectedSource).TrimEnd('\', '/')

    return ($normActual -eq $normExpected)
}

function Backup-DevboxPath {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $timestamp = (Get-Date -Format "yyyyMMdd-HHmmss")
    $backupRoot = Join-Path (Get-DevboxBackupDir) $timestamp
    if (-not (Test-Path $backupRoot)) {
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    }

    $leafName = Split-Path $Path -Leaf
    $parentLeaf = Split-Path (Split-Path $Path -Parent) -Leaf
    $prefix = if ($parentLeaf) { "${parentLeaf}_" } else { "" }
    $destination = Join-Path $backupRoot "$prefix$leafName"

    if (Test-Path -LiteralPath $destination) {
        $uniqueSuffix = [System.Guid]::NewGuid().ToString('N').Substring(0, 6)
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($leafName)
        $ext = [System.IO.Path]::GetExtension($leafName)
        $destination = Join-Path $backupRoot "$prefix${baseName}_${uniqueSuffix}${ext}"
    }

    # Move existing path safely
    Move-Item -LiteralPath $Path -Destination $destination -Force
    return $destination
}

function New-DevboxSymlink {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Destination,
        [switch]$DryRun
    )

    $resolvedSource = [System.IO.Path]::GetFullPath($Source)
    $resolvedDest   = [System.IO.Path]::GetFullPath($Destination)
    $backupLoc      = $null

    if (-not (Test-Path -LiteralPath $resolvedSource)) {
        return [PSCustomObject]@{
            Status  = "FAIL"
            Message = "Source does not exist: $resolvedSource"
        }
    }

    $destParent = Split-Path -Parent $resolvedDest
    if (-not (Test-Path -LiteralPath $destParent)) {
        if ($DryRun) {
            # Would create parent directory
        } else {
            New-Item -ItemType Directory -Path $destParent -Force | Out-Null
        }
    }

    # Check if destination already exists
    if (Test-Path -LiteralPath $resolvedDest) {
        $destItem = Get-Item -LiteralPath $resolvedDest -Force
        $isReparse = ($destItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)

        if ($isReparse) {
            if (Test-DevboxSymlinkTarget -LinkPath $resolvedDest -ExpectedSource $resolvedSource) {
                return [PSCustomObject]@{
                    Status  = "SKIP"
                    Message = "Symlink already points to source: $resolvedDest"
                }
            } else {
                # Stale or pointing elsewhere - remove old link
                if ($DryRun) {
                    return [PSCustomObject]@{
                        Status  = "OK"
                        Message = "[DRY-RUN] Would re-point symlink to $resolvedSource"
                    }
                }
                Remove-Item -LiteralPath $resolvedDest -Force
            }
        } else {
            # Real file or directory exists - backup first!
            if ($DryRun) {
                return [PSCustomObject]@{
                    Status  = "OK"
                    Message = "[DRY-RUN] Would backup existing '$resolvedDest' and create symlink to '$resolvedSource'"
                }
            }
            $backupLoc = Backup-DevboxPath -Path $resolvedDest
            # Logged backup location
        }
    }

    if ($DryRun) {
        return [PSCustomObject]@{
            Status  = "OK"
            Message = "[DRY-RUN] Would create symlink '$resolvedDest' -> '$resolvedSource'"
        }
    }

    try {
        New-Item -ItemType SymbolicLink -Path $resolvedDest -Target $resolvedSource -Force | Out-Null
        return [PSCustomObject]@{
            Status     = "OK"
            Message    = "Symlinked '$resolvedDest' -> '$resolvedSource'"
            BackupPath = $backupLoc
        }
    } catch {
        # Fallback to copy if developer mode or permissions block symlink
        try {
            Copy-Item -Path $resolvedSource -Destination $resolvedDest -Recurse -Force
            return [PSCustomObject]@{
                Status     = "OK"
                Message    = "Fallback: Copied '$resolvedSource' to '$resolvedDest' (Symlink denied)"
                BackupPath = $backupLoc
            }
        } catch {
            return [PSCustomObject]@{
                Status     = "FAIL"
                Message    = "Failed to link or copy: $($_.Exception.Message)"
                BackupPath = $backupLoc
            }
        }
    }
}
