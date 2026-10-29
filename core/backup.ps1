# ==============================================================================
# devbox-win :: Secure Backup & Disaster Recovery System
# Path: core/backup.ps1
# Description: Creates encrypted/compressed workstation snapshots and restores them.
# Standard: Zero emojis. SHA256 verification, safe sandboxing, pre-restore backups.
# ==============================================================================

[CmdletBinding()]
param(
    [switch]$Backup,
    [switch]$Restore,
    [string]$BackupPath = "",
    [switch]$IncludeSSHKeys,
    [switch]$DryRun,
    [string]$RepoRoot = ""
)

Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

. (Join-Path $PSScriptRoot "logger.ps1")
. (Join-Path $PSScriptRoot "manifest.ps1")
. (Join-Path $PSScriptRoot "symlink.ps1")

function Get-FileSha256 {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path $Path)) { return "" }
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $hashBytes = $hasher.ComputeHash($stream)
        return [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLowerInvariant()
    } finally {
        $stream.Dispose()
        $hasher.Dispose()
    }
}

function Invoke-DevboxBackup {
    [CmdletBinding()]
    param(
        [string]$RepoRoot,
        [string]$BackupPath = "",
        [switch]$IncludeSSHKeys,
        [switch]$DryRun
    )

    Write-DevboxBanner -SubTitle "Secure Workstation Backup"

    $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $defaultBackupDir = Join-Path $HOME ".devbox-win\backups"

    if ([string]::IsNullOrWhiteSpace($BackupPath)) {
        if (-not (Test-Path $defaultBackupDir)) {
            New-Item -ItemType Directory -Path $defaultBackupDir -Force | Out-Null
        }
        $BackupPath = Join-Path $defaultBackupDir "devbox-backup-$timestamp.zip"
    } else {
        $parentDir = [System.IO.Path]::GetDirectoryName($BackupPath)
        if ($parentDir -and (-not (Test-Path $parentDir))) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
    }

    Write-DevboxBackup "Target Archive: $BackupPath"
    if ($DryRun) {
        Write-DevboxWarn "DRY RUN MODE ENABLED - No backup archive will be written"
    }

    if ($IncludeSSHKeys) {
        Write-DevboxWarn "SECURITY NOTICE: SSH keys will be included in this archive."
        Write-DevboxWarn "Store this backup file in an encrypted, secure location."
    }

    # Prepare staging sandbox
    $stageDir = Join-Path $env:TEMP "devbox_backup_stage_$([System.Guid]::NewGuid().ToString('N'))"
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $stageDir -Force | Out-Null
    }

    $includedFiles = [System.Collections.Generic.List[object]]::new()

    try {
        # 1. Active Config
        $activeConfig = Join-Path $RepoRoot "config.yaml"
        if (Test-Path $activeConfig) {
            $dest = Join-Path $stageDir "config.yaml"
            if (-not $DryRun) { Copy-Item -Path $activeConfig -Destination $dest -Force }
            $includedFiles.Add([PSCustomObject]@{
                Path   = "config.yaml"
                Source = $activeConfig
                Sha256 = (Get-FileSha256 -Path $activeConfig)
            })
            Write-DevboxOk "Included: config.yaml"
        }

        # 1b. Local Config overrides (if present)
        $localConfig = Join-Path $RepoRoot "config.local.yaml"
        if (Test-Path $localConfig) {
            $dest = Join-Path $stageDir "config.local.yaml"
            if (-not $DryRun) { Copy-Item -Path $localConfig -Destination $dest -Force }
            $includedFiles.Add([PSCustomObject]@{
                Path   = "config.local.yaml"
                Source = $localConfig
                Sha256 = (Get-FileSha256 -Path $localConfig)
            })
            Write-DevboxOk "Included: config.local.yaml"
        }

        # 2. Dotfiles directory
        $dotfilesDir = Join-Path $RepoRoot "dotfiles"
        if (Test-Path $dotfilesDir) {
            $stageDotfiles = Join-Path $stageDir "dotfiles"
            if (-not $DryRun) {
                Copy-Item -Path $dotfilesDir -Destination $stageDotfiles -Recurse -Force
            }
            $dotfileItems = Get-ChildItem -Path $dotfilesDir -Recurse -File
            foreach ($item in $dotfileItems) {
                $rel = $item.FullName.Substring($dotfilesDir.Length).TrimStart('\', '/')
                $archiveRel = "dotfiles/$($rel.Replace('\', '/'))"
                $includedFiles.Add([PSCustomObject]@{
                    Path   = $archiveRel
                    Source = $item.FullName
                    Sha256 = (Get-FileSha256 -Path $item.FullName)
                })
            }
            Write-DevboxOk "Included: dotfiles/ ($($dotfileItems.Count) files)"
        }

        # 3. State & Manifest
        $devboxStateDir = Join-Path $HOME ".devbox-win"
        $stateFile = Join-Path $devboxStateDir "state.json"
        if (Test-Path $stateFile) {
            $destState = Join-Path $stageDir "state.json"
            if (-not $DryRun) { Copy-Item -Path $stateFile -Destination $destState -Force }
            $includedFiles.Add([PSCustomObject]@{
                Path   = "state.json"
                Source = $stateFile
                Sha256 = (Get-FileSha256 -Path $stateFile)
            })
            Write-DevboxOk "Included: state.json"
        }

        $manifestFile = Join-Path $devboxStateDir "manifest.json"
        if (Test-Path $manifestFile) {
            $destManifest = Join-Path $stageDir "manifest.json"
            if (-not $DryRun) { Copy-Item -Path $manifestFile -Destination $destManifest -Force }
            $includedFiles.Add([PSCustomObject]@{
                Path   = "manifest.json"
                Source = $manifestFile
                Sha256 = (Get-FileSha256 -Path $manifestFile)
            })
            Write-DevboxOk "Included: manifest.json"
        }

        # 4. Optional SSH Keys
        if ($IncludeSSHKeys) {
            $sshDir = Join-Path $HOME ".ssh"
            if (Test-Path $sshDir) {
                $sshCandidates = @("id_ed25519", "id_ed25519.pub", "id_rsa", "id_rsa.pub", "known_hosts", "config")
                $stageSsh = Join-Path $stageDir "ssh"
                if (-not $DryRun) {
                    New-Item -ItemType Directory -Path $stageSsh -Force | Out-Null
                }
                $sshCount = 0
                foreach ($c in $sshCandidates) {
                    $srcKey = Join-Path $sshDir $c
                    if (Test-Path $srcKey) {
                        $destKey = Join-Path $stageSsh $c
                        if (-not $DryRun) { Copy-Item -Path $srcKey -Destination $destKey -Force }
                        $includedFiles.Add([PSCustomObject]@{
                            Path   = "ssh/$c"
                            Source = $srcKey
                            Sha256 = (Get-FileSha256 -Path $srcKey)
                        })
                        $sshCount++
                    }
                }
                Write-DevboxOk "Included: ssh/ ($sshCount key/config file(s))"
            }
        }

        # 5. Metadata Descriptor
        $metaObj = [ordered]@{
            schemaVersion   = "1.0.0"
            createdAt       = (Get-Date).ToString("o")
            devboxVersion   = "1.0.0-mvp"
            hostName        = $env:COMPUTERNAME
            userName        = $env:USERNAME
            osBuild         = [System.Environment]::OSVersion.Version.Build
            includeSSHKeys  = [bool]$IncludeSSHKeys
            fileCount       = $includedFiles.Count
            files           = @($includedFiles)
        }

        $metaJson = $metaObj | ConvertTo-Json -Depth 5
        $stageMetaPath = Join-Path $stageDir "backup-metadata.json"
        if (-not $DryRun) {
            Set-Content -Path $stageMetaPath -Value $metaJson -Encoding utf8
        }

        if ($DryRun) {
            Write-DevboxDryRun "Would compress $($includedFiles.Count) files into: $BackupPath"
            return [PSCustomObject]@{
                Status     = "OK"
                BackupPath = $BackupPath
                FileCount  = $includedFiles.Count
                Message    = "Dry run: backup simulated"
            }
        }

        # Compress to Zip
        Write-DevboxInfo "Compressing backup archive..."
        if (Test-Path $BackupPath) {
            Remove-Item -Path $BackupPath -Force
        }
        Compress-Archive -Path "$stageDir\*" -DestinationPath $BackupPath -CompressionLevel Optimal

        # Compute SHA256 of resulting zip
        $archiveHash = Get-FileSha256 -Path $BackupPath
        $hashFile = "$BackupPath.sha256"
        Set-Content -Path $hashFile -Value "$archiveHash  $([System.IO.Path]::GetFileName($BackupPath))" -Encoding utf8

        Write-DevboxOk "Backup completed successfully!"
        Write-Host "  Archive File : $($script:C.BrightCyan)$BackupPath$($script:C.Reset)"
        Write-Host "  SHA256 Hash  : $($script:C.Dim)$archiveHash$($script:C.Reset)"
        Write-Host "  Checksum File: $($script:C.Dim)$hashFile$($script:C.Reset)"
        Write-Host "  Files Saved  : $($includedFiles.Count)"

        return [PSCustomObject]@{
            Status      = "OK"
            BackupPath  = $BackupPath
            Sha256      = $archiveHash
            FileCount   = $includedFiles.Count
            Metadata    = $metaObj
        }
    } finally {
        if (Test-Path $stageDir) {
            Remove-Item -Path $stageDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-DevboxRestore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$BackupPath,
        [string]$RepoRoot = "",
        [switch]$DryRun
    )

    Write-DevboxBanner -SubTitle "Disaster Recovery & Workstation Restore"

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
    }

    if (-not (Test-Path $BackupPath)) {
        Write-DevboxFail "Backup archive not found at: $BackupPath"
        return [PSCustomObject]@{ Status = "FAIL"; Message = "Archive not found" }
    }

    Write-DevboxBackup "Source Archive: $BackupPath"
    if ($DryRun) {
        Write-DevboxWarn "DRY RUN MODE ENABLED - No files or symlinks will be overwritten"
    }

    # Verify Checksum if companion .sha256 file exists
    $shaFile = "$BackupPath.sha256"
    if (Test-Path $shaFile) {
        $expectedHash = ((Get-Content -Path $shaFile -Raw) -split '\s+')[0].Trim().ToLowerInvariant()
        $actualHash = (Get-FileSha256 -Path $BackupPath).ToLowerInvariant()
        if ($expectedHash -and $expectedHash -ne $actualHash) {
            Write-DevboxFail "Archive integrity check FAILED: Checksum mismatch."
            Write-Host "         Expected : $expectedHash"
            Write-Host "         Actual   : $actualHash"
            return [PSCustomObject]@{ Status = "FAIL"; Message = "Checksum mismatch" }
        }
        Write-DevboxOk "Integrity check: PASSED (SHA256 verified)"
    } else {
        Write-DevboxInfo "No companion .sha256 file found. Proceeding with zip extraction."
    }

    # Extract to sandbox
    $sandboxDir = Join-Path $env:TEMP "devbox_restore_sandbox_$([System.Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $sandboxDir -Force | Out-Null

    try {
        Write-DevboxInfo "Unpacking archive to sandbox..."
        try {
            Expand-Archive -Path $BackupPath -DestinationPath $sandboxDir -Force
        } catch {
            Write-DevboxFail "Failed to extract zip archive" $_.Exception.Message
            return [PSCustomObject]@{ Status = "FAIL"; Message = "Extraction failed" }
        }

        # Read and validate metadata
        $metaFile = Join-Path $sandboxDir "backup-metadata.json"
        if (-not (Test-Path $metaFile)) {
            Write-DevboxFail "Invalid devbox backup archive: Missing backup-metadata.json"
            return [PSCustomObject]@{ Status = "FAIL"; Message = "Missing metadata descriptor" }
        }

        $meta = Get-Content -Path $metaFile -Raw -Encoding utf8 | ConvertFrom-Json
        Write-DevboxOk "Validated backup metadata (Created: $($meta.createdAt) on Host: $($meta.hostName))"

        # Pre-restore snapshot of current machine state
        $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
        $preRestoreBackupDir = Join-Path $HOME ".devbox-win\backups\pre-restore-$timestamp"

        Write-DevboxSection "Restoration Plan"
        $restoredFiles = [System.Collections.Generic.List[string]]::new()

        # Check config.yaml
        $sandConfig = Join-Path $sandboxDir "config.yaml"
        if (Test-Path $sandConfig) {
            $destConfig = Join-Path $RepoRoot "config.yaml"
            Write-Host "  Restore : config.yaml -> $destConfig"
            $restoredFiles.Add("config.yaml")
        }

        # Check dotfiles
        $sandDotfiles = Join-Path $sandboxDir "dotfiles"
        if (Test-Path $sandDotfiles) {
            $dotfilesInZip = Get-ChildItem -Path $sandDotfiles -Recurse -File
            Write-Host "  Restore : dotfiles/ ($($dotfilesInZip.Count) file(s))"
            foreach ($df in $dotfilesInZip) {
                $restoredFiles.Add("dotfiles/$($df.Name)")
            }
        }

        # Check state.json & manifest.json
        $sandState = Join-Path $sandboxDir "state.json"
        if (Test-Path $sandState) {
            Write-Host "  Restore : state.json -> $(Join-Path $HOME '.devbox-win\state.json')"
            $restoredFiles.Add("state.json")
        }
        $sandManifest = Join-Path $sandboxDir "manifest.json"
        if (Test-Path $sandManifest) {
            Write-Host "  Restore : manifest.json -> $(Join-Path $HOME '.devbox-win\manifest.json')"
            $restoredFiles.Add("manifest.json")
        }

        # Check SSH keys
        $sandSsh = Join-Path $sandboxDir "ssh"
        if (Test-Path $sandSsh) {
            $sshFilesInZip = Get-ChildItem -Path $sandSsh -File
            Write-Host "  Restore : ssh/ ($($sshFilesInZip.Count) SSH key/config file(s))"
            foreach ($sk in $sshFilesInZip) {
                $restoredFiles.Add("ssh/$($sk.Name)")
            }
        }

        if ($DryRun) {
            Write-DevboxDryRun "Would create pre-restore snapshot at: $preRestoreBackupDir"
            Write-DevboxDryRun "Would overwrite $($restoredFiles.Count) workstation file(s) and re-link dotfile symlinks."
            return [PSCustomObject]@{
                Status        = "OK"
                RestoredFiles = @($restoredFiles)
                Message       = "Dry run: restore simulated"
            }
        }

        # Perform Pre-Restore Snapshot
        Write-DevboxInfo "Creating pre-restore safety snapshot at: $preRestoreBackupDir..."
        New-Item -ItemType Directory -Path $preRestoreBackupDir -Force | Out-Null
        $activeConfig = Join-Path $RepoRoot "config.yaml"
        if (Test-Path $activeConfig) {
            Copy-Item -Path $activeConfig -Destination (Join-Path $preRestoreBackupDir "config.yaml") -Force
        }
        $activeDotfiles = Join-Path $RepoRoot "dotfiles"
        if (Test-Path $activeDotfiles) {
            Copy-Item -Path $activeDotfiles -Destination (Join-Path $preRestoreBackupDir "dotfiles") -Recurse -Force
        }
        Write-DevboxOk "Safety snapshot created."

        # Apply Restores
        Write-DevboxInfo "Restoring files to repository..."
        if (Test-Path $sandConfig) {
            Copy-Item -Path $sandConfig -Destination (Join-Path $RepoRoot "config.yaml") -Force
            Write-DevboxOk "Restored: config.yaml"
        }

        $sandLocalConfig = Join-Path $sandboxDir "config.local.yaml"
        if (Test-Path $sandLocalConfig) {
            Copy-Item -Path $sandLocalConfig -Destination (Join-Path $RepoRoot "config.local.yaml") -Force
            Write-DevboxOk "Restored: config.local.yaml"
        }

        if (Test-Path $sandDotfiles) {
            Copy-Item -Path "$sandDotfiles\*" -Destination (Join-Path $RepoRoot "dotfiles") -Recurse -Force
            Write-DevboxOk "Restored: dotfiles/"
        }

        $devboxStateDir = Join-Path $HOME ".devbox-win"
        if (-not (Test-Path $devboxStateDir)) {
            New-Item -ItemType Directory -Path $devboxStateDir -Force | Out-Null
        }
        if (Test-Path $sandState) {
            Copy-Item -Path $sandState -Destination (Join-Path $devboxStateDir "state.json") -Force
            Write-DevboxOk "Restored: state.json"
        }
        if (Test-Path $sandManifest) {
            Copy-Item -Path $sandManifest -Destination (Join-Path $devboxStateDir "manifest.json") -Force
            Write-DevboxOk "Restored: manifest.json"
        }

        if (Test-Path $sandSsh) {
            $destSsh = Join-Path $HOME ".ssh"
            if (-not (Test-Path $destSsh)) {
                New-Item -ItemType Directory -Path $destSsh -Force | Out-Null
            }
            Copy-Item -Path "$sandSsh\*" -Destination $destSsh -Force
            Write-DevboxOk "Restored: SSH keys"
        }

        # Re-link dotfile symlinks
        Write-DevboxInfo "Re-applying dotfile symlinks..."
        $dotfilesScript = Join-Path $RepoRoot "modules\dotfiles.ps1"
        if (Test-Path $dotfilesScript) {
            $parsedConfig = Read-DevboxConfigFile -Path (Join-Path $RepoRoot "config.yaml") -SkipPresetResolution
            & $dotfilesScript -Config $parsedConfig
            Write-DevboxOk "Symlinks refreshed successfully."
        }

        Write-DevboxOk "Workstation restoration completed successfully!"
        return [PSCustomObject]@{
            Status        = "OK"
            RestoredFiles = @($restoredFiles)
            SnapshotPath  = $preRestoreBackupDir
        }
    } finally {
        if (Test-Path $sandboxDir) {
            Remove-Item -Path $sandboxDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Direct invocation handling
if ($MyInvocation.InvocationName -ne '.') {
    if ($Restore) {
        if ([string]::IsNullOrWhiteSpace($BackupPath)) {
            Write-DevboxFail "Restore requires -BackupPath <path-to-zip>"
            exit 1
        }
        $res = Invoke-DevboxRestore -BackupPath $BackupPath -RepoRoot $RepoRoot -DryRun:$DryRun
        if ($res.Status -eq "FAIL") { exit 1 } else { exit 0 }
    } elseif ($Backup) {
        $res = Invoke-DevboxBackup -BackupPath $BackupPath -IncludeSSHKeys:$IncludeSSHKeys -RepoRoot $RepoRoot -DryRun:$DryRun
        if ($res.Status -eq "FAIL") { exit 1 } else { exit 0 }
    } else {
        Write-DevboxBanner -SubTitle "Backup & Disaster Recovery"
        Write-Host "Usage:"
        Write-Host "  Create Backup:  pwsh -NoProfile -File core/engine.ps1 -Backup [-BackupPath <p>] [-IncludeSSHKeys]"
        Write-Host "  Restore Backup: pwsh -NoProfile -File core/engine.ps1 -Restore -BackupPath <p> [-DryRun]"
        exit 0
    }
}
