# ==============================================================================
# devbox-win :: Module: Git
# Path: modules/git.ps1
# Description: Git global configuration and SSH ed25519 key generation.
# Standard: Zero emojis. Idempotent git config application and SSH key setup.
# ==============================================================================

param(
    [Parameter(Mandatory=$true)][System.Collections.IDictionary]$Config,
    [switch]$DryRun
)

Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "..\core\logger.ps1")
. (Join-Path $PSScriptRoot "..\core\manifest.ps1")

function Resolve-GitCommand {
    if (Get-Command "git" -ErrorAction SilentlyContinue) {
        return "git"
    }
    $candidates = @(
        "C:\Program Files\Git\cmd\git.exe",
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) {
            return $c
        }
    }
    return $null
}

function Set-GitGlobalConfigIfDifferent {
    param(
        [string]$GitCmd,
        [string]$Key,
        [string]$Value,
        [switch]$DryRun
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    $current = & $GitCmd config --global --get $Key 2>$null
    if ($LASTEXITCODE -eq 0 -and $current -eq $Value) {
        Write-DevboxSkip "$Key" "Already set to '$Value'"
        return
    }

    if ($DryRun) {
        Write-DevboxDryRun "Would set git config --global $Key '$Value'"
        return
    }

    & $GitCmd config --global $Key $Value
    if ($LASTEXITCODE -eq 0) {
        Write-DevboxOk "Configured git $Key = '$Value'"
    } else {
        Write-DevboxFail "Failed to set git config $Key"
    }
}

function Set-GitUserConfigFileIfDifferent {
    param(
        [string]$GitCmd,
        [string]$FilePath,
        [string]$Key,
        [string]$Value,
        [switch]$DryRun
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    $current = & $GitCmd config --file $FilePath --get $Key 2>$null
    if ($LASTEXITCODE -eq 0 -and $current -eq $Value) {
        Write-DevboxSkip "$Key" "Already set in $(Split-Path $FilePath -Leaf)"
        return
    }

    if ($DryRun) {
        Write-DevboxDryRun "Would set $(Split-Path $FilePath -Leaf) $Key = '$Value'"
        return
    }

    & $GitCmd config --file $FilePath $Key $Value
    if ($LASTEXITCODE -eq 0) {
        Write-DevboxOk "Configured $(Split-Path $FilePath -Leaf) $Key = '$Value'"
    } else {
        Write-DevboxFail "Failed to set git config $Key in $(Split-Path $FilePath -Leaf)"
    }
}

function Invoke-DevboxGitModule {
    param(
        [System.Collections.IDictionary]$Config,
        [switch]$DryRun
    )

    $gitCmd = Resolve-GitCommand
    if (-not $gitCmd) {
        Write-DevboxFail "Git executable not found in PATH or standard directories"
        return [PSCustomObject]@{
            Status  = "FAIL"
            Message = "Git executable not found"
        }
    }

    $userName = if ($Config.Contains("user") -and $Config["user"].Contains("name")) { $Config["user"]["name"] } else { $null }
    $userEmail = if ($Config.Contains("user") -and $Config["user"].Contains("email")) { $Config["user"]["email"] } else { $null }

    $gitSection = if ($Config.Contains("git") -and ($null -ne $Config["git"])) { $Config["git"] } else { @{} }
    $defaultBranch = if ($gitSection.Contains("default_branch")) { $gitSection["default_branch"] } else { "main" }
    $autocrlf = if ($gitSection.Contains("autocrlf")) { $gitSection["autocrlf"] } else { "input" }
    $genSsh = if ($gitSection.Contains("generate_ssh_key")) { [bool]$gitSection["generate_ssh_key"] } else { $true }
    $sshKeyType = if ($gitSection.Contains("ssh_key_type")) { $gitSection["ssh_key_type"] } else { "ed25519" }

    Write-DevboxInfo "Applying global Git configurations..."
    $userConfigFile = Join-Path $HOME ".gitconfig.user"
    if ($userName) {
        Set-GitUserConfigFileIfDifferent -GitCmd $gitCmd -FilePath $userConfigFile -Key "user.name" -Value $userName -DryRun:$DryRun
        Set-GitGlobalConfigIfDifferent -GitCmd $gitCmd -Key "user.name" -Value $userName -DryRun:$DryRun
    }
    if ($userEmail) {
        Set-GitUserConfigFileIfDifferent -GitCmd $gitCmd -FilePath $userConfigFile -Key "user.email" -Value $userEmail -DryRun:$DryRun
        Set-GitGlobalConfigIfDifferent -GitCmd $gitCmd -Key "user.email" -Value $userEmail -DryRun:$DryRun
    }
    Set-GitGlobalConfigIfDifferent -GitCmd $gitCmd -Key "init.defaultBranch" -Value $defaultBranch -DryRun:$DryRun
    Set-GitGlobalConfigIfDifferent -GitCmd $gitCmd -Key "core.autocrlf" -Value $autocrlf -DryRun:$DryRun

    # SSH key handling
    if ($genSsh) {
        $sshDir = Join-Path $HOME ".ssh"
        $keyName = "id_$sshKeyType"
        $keyPath = Join-Path $sshDir $keyName
        $pubKeyPath = "$keyPath.pub"

        if (Test-Path $keyPath) {
            Write-DevboxSkip "SSH Key" "Existing key found at $keyPath"
        } else {
            if ($DryRun) {
                Write-DevboxDryRun "Would generate $sshKeyType SSH key at $keyPath"
            } else {
                if (-not (Test-Path $sshDir)) {
                    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
                }

                $comment = if ($userEmail) { $userEmail } else { "$env:USERNAME@$env:COMPUTERNAME" }
                Write-DevboxInfo "Generating $sshKeyType key at $keyPath..."

                & ssh-keygen -t $sshKeyType -C $comment -f $keyPath -N ""
                if ($LASTEXITCODE -eq 0 -and (Test-Path $keyPath)) {
                    Write-DevboxOk "Generated SSH key: $pubKeyPath"
                } else {
                    Write-DevboxFail "Failed to generate SSH key"
                }
            }
        }
    }

    return [PSCustomObject]@{
        Status  = "OK"
        Message = "Git and SSH setup completed"
    }
}

Invoke-DevboxGitModule -Config $Config -DryRun:$DryRun
