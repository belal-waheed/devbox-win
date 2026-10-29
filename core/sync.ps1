# ==============================================================================
# devbox-win :: Cross-Machine Synchronization Engine
# Path: core/sync.ps1
# Description: Evaluates fork state, pushes dotfile changes, pulls updates, re-applies DAG.
# Standard: Zero emojis. Pure ANSI status badges and conventional commits.
# ==============================================================================

[CmdletBinding()]
param(
    [switch]$Push,
    [switch]$Pull,
    [switch]$DryRun,
    [string]$RepoRoot = ""
)

Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

. (Join-Path $PSScriptRoot "logger.ps1")

function Get-DevboxSyncStatus {
    param([string]$RepoRoot)

    $gitCmd = Get-Command "git" -ErrorAction SilentlyContinue
    if (-not $gitCmd) {
        return [PSCustomObject]@{
            IsGitRepo     = $false
            HasRemote     = $false
            RemoteName    = ""
            RemoteUrl     = ""
            Branch        = ""
            CommitsAhead  = 0
            CommitsBehind = 0
            IsDirty       = $false
            ModifiedFiles = @()
            SyncStatus    = "NO_GIT"
            Message       = "git is not installed or available in PATH"
        }
    }

    # Verify git repository
    $isGit = & git -C $RepoRoot rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0 -or $isGit -ne "true") {
        return [PSCustomObject]@{
            IsGitRepo     = $false
            HasRemote     = $false
            RemoteName    = ""
            RemoteUrl     = ""
            Branch        = ""
            CommitsAhead  = 0
            CommitsBehind = 0
            IsDirty       = $false
            ModifiedFiles = @()
            SyncStatus    = "NOT_A_REPO"
            Message       = "Directory is not a Git repository"
        }
    }

    # Branch
    $branch = & git -C $RepoRoot branch --show-current 2>$null
    if ([string]::IsNullOrWhiteSpace($branch)) {
        $branch = & git -C $RepoRoot rev-parse --abbrev-ref HEAD 2>$null
    }
    if ([string]::IsNullOrWhiteSpace($branch) -or $branch -eq "HEAD") {
        $branch = "main"
    }

    # Remote detection
    $remotes = & git -C $RepoRoot remote 2>$null
    $remoteArr = if ($remotes -is [System.Array]) { $remotes } elseif ($remotes) { $remotes -split "`r?`n" } else { @() }
    $remoteList = @($remoteArr | Where-Object { $_ -match '\S' })
    $hasRemote = (@($remoteList).Count -gt 0)
    $remoteName = if ($remoteList -contains "origin") { "origin" } elseif (@($remoteList).Count -gt 0) { $remoteList[0] } else { "" }
    $remoteUrl = ""

    if ($hasRemote -and $remoteName) {
        $remoteUrl = (& git -C $RepoRoot remote get-url $remoteName 2>$null | Out-String).Trim()
    }

    # Check uncommitted modifications in workstation config files
    $statusLines = & git -C $RepoRoot status --porcelain 2>$null
    $statusArr = if ($statusLines -is [System.Array]) { $statusLines } elseif ($statusLines) { $statusLines -split "`r?`n" } else { @() }
    $modifiedList = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $statusArr) {
        if ($line.Length -ge 4) {
            $filePath = $line.Substring(3).Trim()
            if ($filePath -match '^(dotfiles|config.*\.yaml|presets|modules/community)') {
                $modifiedList.Add($filePath)
            }
        }
    }
    $isDirty = ($modifiedList.Count -gt 0)

    # Check commits ahead / behind if remote configured and valid commit exists
    $commitsAhead = 0
    $commitsBehind = 0
    $hasHead = $false

    $headRev = & git -C $RepoRoot rev-parse HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and (-not [string]::IsNullOrWhiteSpace($headRev))) {
        $hasHead = $true
    }

    if ($hasRemote -and $hasHead) {
        # Check if remote branch exists locally or can be queried
        $remoteBranchRef = "$remoteName/$branch"
        $refCheck = & git -C $RepoRoot rev-parse --verify $remoteBranchRef 2>$null
        if ($LASTEXITCODE -eq 0) {
            $aheadStr = & git -C $RepoRoot rev-list --count "$remoteBranchRef..HEAD" 2>$null
            if ($aheadStr -match '^\d+$') { $commitsAhead = [int]$aheadStr }

            $behindStr = & git -C $RepoRoot rev-list --count "HEAD..$remoteBranchRef" 2>$null
            if ($behindStr -match '^\d+$') { $commitsBehind = [int]$behindStr }
        }
    }

    # Determine overall status enum
    $statusEnum = "IN_SYNC"
    $msg = "Workstation is in sync with remote fork"

    if (-not $hasRemote) {
        $statusEnum = "NO_REMOTE"
        $msg = "No remote configured for repository"
    } elseif ($commitsAhead -gt 0 -and $commitsBehind -gt 0) {
        $statusEnum = "DIVERGED"
        $msg = "Local branch has diverged from remote ($commitsAhead ahead, $commitsBehind behind)"
    } elseif ($commitsBehind -gt 0) {
        $statusEnum = "BEHIND"
        $msg = "Remote fork has $commitsBehind incoming update(s)"
    } elseif ($commitsAhead -gt 0) {
        $statusEnum = "AHEAD"
        $msg = "Local repository has $commitsAhead unpushed commit(s)"
    } elseif ($isDirty) {
        $statusEnum = "DIRTY"
        $msg = "Local configurations have $($modifiedList.Count) uncommitted change(s)"
    }

    return [PSCustomObject]@{
        IsGitRepo     = $true
        HasRemote     = $hasRemote
        RemoteName    = $remoteName
        RemoteUrl     = $remoteUrl
        Branch        = $branch
        CommitsAhead  = $commitsAhead
        CommitsBehind = $commitsBehind
        IsDirty       = $isDirty
        ModifiedFiles = @($modifiedList.ToArray())
        SyncStatus    = $statusEnum
        Message       = $msg
    }
}

function Invoke-DevboxSyncPull {
    param(
        [string]$RepoRoot,
        [switch]$DryRun
    )

    Write-DevboxSync "Initiating workstation pull synchronization..."

    $status = Get-DevboxSyncStatus -RepoRoot $RepoRoot
    if (-not $status.IsGitRepo) {
        Write-DevboxFail "Cannot pull: $RepoRoot is not a Git repository."
        return [PSCustomObject]@{ Status = "FAIL"; Message = $status.Message }
    }

    if (-not $status.HasRemote) {
        Write-DevboxFail "Cannot pull: No Git remote configured."
        Write-DevboxInfo "Configure remote with: git remote add origin https://github.com/<your-user>/devbox-win.git"
        return [PSCustomObject]@{ Status = "FAIL"; Message = "No remote configured" }
    }

    Write-DevboxInfo "Fetching updates from $($status.RemoteName)/$($status.Branch)..."
    if ($DryRun) {
        Write-DevboxDryRun "Would execute: git fetch $($status.RemoteName) $($status.Branch)"
    } else {
        & git -C $RepoRoot fetch $status.RemoteName $status.Branch 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-DevboxFail "Failed to fetch from remote '$($status.RemoteName)'"
            return [PSCustomObject]@{ Status = "FAIL"; Message = "Git fetch failed" }
        }
    }

    # Refresh status after fetch
    $status = Get-DevboxSyncStatus -RepoRoot $RepoRoot

    if ($status.CommitsBehind -eq 0) {
        Write-DevboxOk "Workstation configuration is already up to date with remote fork."
        return [PSCustomObject]@{ Status = "OK"; Message = "Already up to date" }
    }

    # Check for conflict danger if working directory is dirty
    if ($status.IsDirty) {
        Write-DevboxWarn "Local configuration has uncommitted changes in: $($status.ModifiedFiles -join ', ')"
        Write-DevboxWarn "Pulling now may cause merge conflicts. Please commit local changes (-Sync -Push) or stash first."
        return [PSCustomObject]@{ Status = "FAIL"; Message = "Uncommitted local changes prevent clean pull" }
    }

    if ($DryRun) {
        Write-DevboxDryRun "Would merge $($status.CommitsBehind) commit(s) from $($status.RemoteName)/$($status.Branch)"
        $incomingCommits = & git -C $RepoRoot log "HEAD..$($status.RemoteName)/$($status.Branch)" --oneline 2>$null
        if ($incomingCommits) {
            $icArr = if ($incomingCommits -is [System.Array]) { $incomingCommits } else { $incomingCommits -split "`r?`n" }
            Write-Host "         Incoming commits:"
            foreach ($c in $icArr) {
                Write-Host "           $($script:C.Dim)$c$($script:C.Reset)"
            }
        }
        Write-DevboxDryRun "Would detect configuration changes and trigger idempotent DAG re-apply."
        return [PSCustomObject]@{ Status = "OK"; Message = "Dry run: pull simulated" }
    }

    # Perform clean pull
    Write-DevboxInfo "Merging $($status.CommitsBehind) incoming commit(s)..."
    $pullOutput = & git -C $RepoRoot pull --ff-only $status.RemoteName $status.Branch 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Write-DevboxFail "Fast-forward merge failed. Non-linear history detected."
        Write-DevboxInfo $pullOutput
        return [PSCustomObject]@{ Status = "FAIL"; Message = "Fast-forward pull failed" }
    }

    Write-DevboxOk "Merged remote updates successfully."

    # Inspect changes between ORIG_HEAD and HEAD to see if dotfiles or configs changed
    $changedFiles = & git -C $RepoRoot diff --name-only ORIG_HEAD HEAD 2>$null
    $hasConfigChanges = $false
    if ($changedFiles) {
        $cfArr = if ($changedFiles -is [System.Array]) { $changedFiles } else { $changedFiles -split "`r?`n" }
        foreach ($cf in $cfArr) {
            if ($cf -match '^(dotfiles|config.*\.yaml|presets|modules)') {
                $hasConfigChanges = $true
                break
            }
        }
    }

    if ($hasConfigChanges) {
        Write-DevboxSync "Configuration or dotfile modifications detected in pulled commits."
        Write-DevboxInfo "Triggering idempotent dotfile symlink re-apply..."
        $dotfilesScript = Join-Path $RepoRoot "modules\dotfiles.ps1"
        if (Test-Path $dotfilesScript) {
            $config = Read-DevboxConfigFile -Path (Join-Path $RepoRoot "config.yaml") -SkipPresetResolution
            & $dotfilesScript -Config $config
            Write-DevboxOk "Dotfile symlinks refreshed."
        }
    }

    return [PSCustomObject]@{ Status = "OK"; Message = "Pull and synchronization completed" }
}

function Invoke-DevboxSyncPush {
    param(
        [string]$RepoRoot,
        [switch]$DryRun
    )

    Write-DevboxSync "Initiating workstation push synchronization..."

    $status = Get-DevboxSyncStatus -RepoRoot $RepoRoot
    if (-not $status.IsGitRepo) {
        Write-DevboxFail "Cannot push: $RepoRoot is not a Git repository."
        return [PSCustomObject]@{ Status = "FAIL"; Message = $status.Message }
    }

    if (-not $status.HasRemote) {
        Write-DevboxFail "Cannot push: No Git remote configured."
        Write-DevboxInfo "Configure remote with: git remote add origin https://github.com/<your-user>/devbox-win.git"
        return [PSCustomObject]@{ Status = "FAIL"; Message = "No remote configured" }
    }

    if (-not $status.IsDirty -and $status.CommitsAhead -eq 0) {
        Write-DevboxOk "Workstation configuration is already in sync with remote fork (no local changes to push)."
        return [PSCustomObject]@{ Status = "OK"; Message = "No changes to push" }
    }

    if ($DryRun) {
        if ($status.IsDirty) {
            Write-DevboxDryRun "Would stage $($status.ModifiedFiles.Count) changed workstation file(s):"
            foreach ($f in $status.ModifiedFiles) {
                Write-Host "           $($script:C.Dim)$f$($script:C.Reset)"
            }
            Write-DevboxDryRun "Would commit changes with message: 'chore(sync): update workstation configs [timestamp]'"
        }
        Write-DevboxDryRun "Would push to $($status.RemoteName)/$($status.Branch)"
        return [PSCustomObject]@{ Status = "OK"; Message = "Dry run: push simulated" }
    }

    # Stage files if dirty
    if ($status.IsDirty) {
        Write-DevboxInfo "Staging workstation configurations and dotfiles..."
        foreach ($target in @("config.yaml", "dotfiles", "presets", "modules/community")) {
            $targetPath = Join-Path $RepoRoot $target
            if (Test-Path $targetPath) {
                & git -C $RepoRoot add $target 2>$null
            }
        }

        # Check if anything was actually staged
        $staged = & git -C $RepoRoot diff --cached --name-only 2>$null
        if ($staged) {
            $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            $commitMsg = "chore(sync): update workstation configs $timestamp"
            Write-DevboxInfo "Committing changes: '$commitMsg'..."
            & git -C $RepoRoot commit -m $commitMsg 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-DevboxOk "Committed local configuration updates."
            } else {
                Write-DevboxFail "Failed to create commit."
                return [PSCustomObject]@{ Status = "FAIL"; Message = "Commit failed" }
            }
        }
    }

    # Push commits to remote
    Write-DevboxInfo "Pushing commits to $($status.RemoteName)/$($status.Branch)..."
    $pushOut = & git -C $RepoRoot push $status.RemoteName $status.Branch 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        Write-DevboxOk "Workstation configuration successfully pushed to remote fork."
        return [PSCustomObject]@{ Status = "OK"; Message = "Push completed" }
    } else {
        Write-DevboxFail "Git push failed:"
        Write-DevboxInfo $pushOut
        return [PSCustomObject]@{ Status = "FAIL"; Message = "Push failed" }
    }
}

function Invoke-DevboxSync {
    param(
        [string]$RepoRoot,
        [switch]$Push,
        [switch]$Pull,
        [switch]$DryRun
    )

    Write-DevboxBanner -SubTitle "Cross-Machine Synchronization"

    if ($DryRun) {
        Write-DevboxWarn "DRY RUN MODE ENABLED - No Git commits or pushes will be executed"
    }

    if ($Pull) {
        $res = Invoke-DevboxSyncPull -RepoRoot $RepoRoot -DryRun:$DryRun
        return $res
    }

    if ($Push) {
        $res = Invoke-DevboxSyncPush -RepoRoot $RepoRoot -DryRun:$DryRun
        return $res
    }

    # If neither -Push nor -Pull, report status
    $status = Get-DevboxSyncStatus -RepoRoot $RepoRoot
    Write-DevboxSection "Workstation Git Synchronization Status"

    Write-Host "  Repository Path : $($script:C.White)$RepoRoot$($script:C.Reset)"
    Write-Host "  Current Branch  : $($script:C.BrightCyan)$($status.Branch)$($script:C.Reset)"
    Write-Host "  Git Remote      : $($script:C.White)$(if ($status.HasRemote) { "$($status.RemoteName) ($($status.RemoteUrl))" } else { "None configured" })$($script:C.Reset)"
    Write-Host "  Commits Behind  : $(if ($status.CommitsBehind -gt 0) { "$($script:C.BrightYellow)$($status.CommitsBehind)$($script:C.Reset)" } else { "$($script:C.Dim)0$($script:C.Reset)" })"
    Write-Host "  Commits Ahead   : $(if ($status.CommitsAhead -gt 0) { "$($script:C.BrightCyan)$($status.CommitsAhead)$($script:C.Reset)" } else { "$($script:C.Dim)0$($script:C.Reset)" })"
    Write-Host "  Modified Files  : $(if ($status.IsDirty) { "$($script:C.BrightYellow)$($status.ModifiedFiles.Count)$($script:C.Reset)" } else { "$($script:C.Dim)0$($script:C.Reset)" })"

    if ($status.IsDirty) {
        Write-Host ""
        Write-Host "  Modified configuration files:"
        foreach ($f in $status.ModifiedFiles) {
            Write-Host "    $($script:C.Yellow)[MODIFIED]$($script:C.Reset) $f"
        }
    }

    Write-Host ""
    Write-Host "$($script:C.Gray)------------------------------------------------------------------------------$($script:C.Reset)"
    switch ($status.SyncStatus) {
        "IN_SYNC" {
            Write-DevboxOk "Status: IN SYNC - Workstation configuration matches remote repository."
        }
        "BEHIND" {
            Write-DevboxWarn "Status: BEHIND - Remote repository has $($status.CommitsBehind) update(s)."
            Write-Host "  To pull updates and re-apply configs: pwsh -NoProfile -File core/engine.ps1 -Sync -Pull"
        }
        "AHEAD" {
            Write-DevboxInfo "Status: AHEAD - You have $($status.CommitsAhead) local commit(s) ready to push."
            Write-Host "  To push changes to your fork: pwsh -NoProfile -File core/engine.ps1 -Sync -Push"
        }
        "DIRTY" {
            Write-DevboxWarn "Status: LOCAL CHANGES DETECTED - $($status.ModifiedFiles.Count) configuration file(s) modified."
            Write-Host "  To stage, commit, and push changes: pwsh -NoProfile -File core/engine.ps1 -Sync -Push"
        }
        "DIVERGED" {
            Write-DevboxFail "Status: DIVERGED - Local and remote branches have diverged."
            Write-Host "  Manual git reconciliation (rebase or merge) recommended."
        }
        "NO_REMOTE" {
            Write-DevboxWarn "Status: NO REMOTE - Remote fork URL is not yet configured."
            Write-Host "  To link your fork: git remote add origin https://github.com/<user>/devbox-win.git"
        }
        default {
            Write-DevboxInfo "Status: $($status.SyncStatus)"
        }
    }
    Write-Host "$($script:C.Gray)==============================================================================$($script:C.Reset)"
    Write-Host ""

    return [PSCustomObject]@{ Status = "OK"; SyncStatus = $status }
}

# Direct invocation handling
if ($MyInvocation.InvocationName -ne '.') {
    $res = Invoke-DevboxSync -RepoRoot $RepoRoot -Push:$Push -Pull:$Pull -DryRun:$DryRun
    if ($res.Status -eq "FAIL") { exit 1 } else { exit 0 }
}
