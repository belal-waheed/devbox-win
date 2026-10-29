# ==============================================================================
# devbox-win :: Module: Editor (VS Code & Zed)
# Path: modules/editor.ps1
# Description: Synchronizes VS Code and Zed editor settings, keybindings, and extensions.
# Standard: Zero emojis. Idempotent extension check and dotfile linking.
# ==============================================================================

param(
    [Parameter(Mandatory=$true)][System.Collections.IDictionary]$Config,
    [switch]$DryRun
)

Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "..\core\logger.ps1")
. (Join-Path $PSScriptRoot "..\core\symlink.ps1")
. (Join-Path $PSScriptRoot "..\core\manifest.ps1")

function Resolve-CodeCommand {
    if (Get-Command "code" -ErrorAction SilentlyContinue) {
        return "code"
    }
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "C:\Program Files\Microsoft VS Code\bin\code.cmd"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) {
            return $c
        }
    }
    return $null
}

function Invoke-DevboxEditorModule {
    param(
        [System.Collections.IDictionary]$Config,
        [switch]$DryRun
    )

    $editorConfig = if ($Config.Contains("editor") -and ($null -ne $Config["editor"])) { $Config["editor"] } else { @{} }
    $syncSettings = if ($editorConfig.Contains("sync_settings")) { [bool]$editorConfig["sync_settings"] } else { $true }
    $installExts  = if ($editorConfig.Contains("install_extensions")) { [bool]$editorConfig["install_extensions"] } else { $true }

    $repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
    $manifest = Load-DevboxManifest
    $codeUserDir = Join-Path $env:APPDATA "Code\User"

    $configuredCount = 0
    $skippedCount    = 0
    $failedCount     = 0

    # 1. Sync VS Code settings and keybindings
    if ($syncSettings) {
        $settingsSrc = Join-Path $repoRoot "dotfiles\vscode\settings.json"
        $settingsDst = Join-Path $codeUserDir "settings.json"
        $keysSrc     = Join-Path $repoRoot "dotfiles\vscode\keybindings.json"
        $keysDst     = Join-Path $codeUserDir "keybindings.json"

        if (Test-Path $settingsSrc) {
            Write-DevboxInfo "Configuring VS Code settings.json..."
            $res = New-DevboxSymlink -Source $settingsSrc -Destination $settingsDst -DryRun:$DryRun
            switch ($res.Status) {
                "OK"   { Write-DevboxOk $res.Message; if (-not $DryRun) { Add-DevboxManifestSymlink -Manifest $manifest -Destination $settingsDst -Source $settingsSrc -BackupPath $res.BackupPath }; $configuredCount++ }
                "SKIP" { Write-DevboxSkip "VS Code Settings" $res.Message; $skippedCount++ }
                "FAIL" { Write-DevboxFail "VS Code Settings link failed" $res.Message; $failedCount++ }
            }
        }

        if (Test-Path $keysSrc) {
            Write-DevboxInfo "Configuring VS Code keybindings.json..."
            $res = New-DevboxSymlink -Source $keysSrc -Destination $keysDst -DryRun:$DryRun
            switch ($res.Status) {
                "OK"   { Write-DevboxOk $res.Message; if (-not $DryRun) { Add-DevboxManifestSymlink -Manifest $manifest -Destination $keysDst -Source $keysSrc -BackupPath $res.BackupPath }; $configuredCount++ }
                "SKIP" { Write-DevboxSkip "VS Code Keybindings" $res.Message; $skippedCount++ }
                "FAIL" { Write-DevboxFail "VS Code Keybindings link failed" $res.Message; $failedCount++ }
            }
        }
    }

    # 2. Sync Zed Editor settings (~/.config/zed/settings.json and %APPDATA%\Zed\settings.json)
    if ($syncSettings) {
        $zedSettingsSrc = Join-Path $repoRoot "dotfiles\zed\settings.json"
        if (Test-Path $zedSettingsSrc) {
            $zedDestinations = @(
                @{
                    Name = "Zed Settings (~/.config/zed)"
                    Path = Join-Path (Join-Path $HOME ".config\zed") "settings.json"
                },
                @{
                    Name = "Zed Settings (%APPDATA%\Zed)"
                    Path = Join-Path (Join-Path $env:APPDATA "Zed") "settings.json"
                }
            )

            foreach ($zd in $zedDestinations) {
                Write-DevboxInfo "Configuring $($zd.Name)..."
                $res = New-DevboxSymlink -Source $zedSettingsSrc -Destination $zd.Path -DryRun:$DryRun
                switch ($res.Status) {
                    "OK"   { Write-DevboxOk $res.Message; if (-not $DryRun) { Add-DevboxManifestSymlink -Manifest $manifest -Destination $zd.Path -Source $zedSettingsSrc -BackupPath $res.BackupPath }; $configuredCount++ }
                    "SKIP" { Write-DevboxSkip $zd.Name $res.Message; $skippedCount++ }
                    "FAIL" { Write-DevboxFail "$($zd.Name) link failed" $res.Message; $failedCount++ }
                }
            }
        }
    }

    # 3. Install VS Code extensions from extensions.txt
    if ($installExts) {
        $extFile = Join-Path $repoRoot "dotfiles\vscode\extensions.txt"
        if (Test-Path $extFile) {
            $codeCmd = Resolve-CodeCommand
            if (-not $codeCmd) {
                Write-DevboxWarn "VS Code command 'code' not found in PATH; skipping extensions installation."
            } else {
                Write-DevboxInfo "Querying installed VS Code extensions..."
                $installed = @(& $codeCmd --list-extensions 2>$null)
                $installedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($item in $installed) {
                    if (-not [string]::IsNullOrWhiteSpace($item)) {
                        [void]$installedSet.Add($item.Trim())
                    }
                }

                $lines = Get-Content -Path $extFile -Encoding utf8
                $extToInstall = @()
                foreach ($line in $lines) {
                    $trimmed = $line.Trim()
                    if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) { continue }
                    $extToInstall += $trimmed
                }

                Write-DevboxInfo "Evaluating $($extToInstall.Count) extensions..."
                foreach ($extId in $extToInstall) {
                    if ($installedSet.Contains($extId)) {
                        Write-DevboxSkip $extId "Already installed"
                        $skippedCount++
                        continue
                    }

                    if ($DryRun) {
                        Write-DevboxDryRun "Would install VS Code extension: $extId"
                        $configuredCount++
                        continue
                    }

                    Write-DevboxInfo "Installing VS Code extension: $extId..."
                    & $codeCmd --install-extension $extId --force | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-DevboxOk "Installed extension: $extId"
                        $configuredCount++
                    } else {
                        Write-DevboxFail "Failed to install extension: $extId"
                        $failedCount++
                    }
                }
            }
        }
    }

    if ($failedCount -gt 0) {
        return [PSCustomObject]@{
            Status  = "FAIL"
            Message = "$failedCount editor configuration step(s) failed"
        }
    }

    return [PSCustomObject]@{
        Status  = "OK"
        Message = "Editor environments configured successfully ($configuredCount updated, $skippedCount skipped)"
    }
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -notmatch '^\.') {
    Invoke-DevboxEditorModule -Config $Config -DryRun:$DryRun
}
