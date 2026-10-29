# ==============================================================================
# devbox-win :: Core Config
# Path: core/config.ps1
# Description: YAML configuration parser, validator, and schema defaults.
# Zero dependencies: uses powershell-yaml if present, or robust built-in fallback.
# ==============================================================================

Set-StrictMode -Version Latest

function ConvertFrom-SimpleYaml {
    param([string]$YamlText)

    $lines = $YamlText -split "`r?`n"
    $cleaned = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) { continue }
        # Strip trailing comments outside quotes
        $content = $line
        if ($content -match '^(?<val>(?:[^''"#]|"[^"]*"|''[^'']*'')*)(#.*)$') {
            $content = $Matches['val']
        }
        $cleaned.Add($content.TrimEnd())
    }

    function Convert-Scalar {
        param([string]$val)
        $trimmed = $val.Trim()
        if ($trimmed -eq 'true' -or $trimmed -eq 'yes' -or $trimmed -eq 'True') { return $true }
        if ($trimmed -eq 'false' -or $trimmed -eq 'no' -or $trimmed -eq 'False') { return $false }
        if ($trimmed -eq 'null' -or $trimmed -eq '~' -or $trimmed -eq '') { return $null }
        if ($trimmed -match '^"(.*)"$' -or $trimmed -match "^'(.*)'$") { return $Matches[1] }
        if ($trimmed -match '^-?\d+$') { return [int64]$trimmed }
        if ($trimmed -match '^-?\d+\.\d+$') { return [double]$trimmed }
        if ($trimmed -match '^\[(.*)\]$') {
            $items = $Matches[1] -split ',' | ForEach-Object { Convert-Scalar $_.Trim() }
            return ,@($items)
        }
        return $trimmed
    }

    function Parse-Block {
        param(
            [System.Collections.Generic.List[string]]$Lines,
            [ref]$Index,
            [int]$CurrentIndent
        )
        $isList = $false
        if ($Index.Value -lt $Lines.Count) {
            $line = $Lines[$Index.Value]
            $trim = $line.TrimStart()
            if ($trim.StartsWith("- ")) {
                $isList = $true
            }
        }

        if ($isList) {
            $result = [System.Collections.Generic.List[object]]::new()
            while ($Index.Value -lt $Lines.Count) {
                $line = $Lines[$Index.Value]
                $indent = $line.Length - $line.TrimStart().Length
                if ($indent -lt $CurrentIndent) { break }
                $trim = $line.TrimStart()
                if (-not $trim.StartsWith("- ")) { break }

                $itemVal = $trim.Substring(2).Trim()
                $Index.Value++

                if ($itemVal.Length -eq 0) {
                    $subIndent = if ($Index.Value -lt $Lines.Count) { $Lines[$Index.Value].Length - $Lines[$Index.Value].TrimStart().Length } else { $indent + 2 }
                    $parsed = Parse-Block -Lines $Lines -Index $Index -CurrentIndent $subIndent
                    $result.Add($parsed)
                } elseif ($itemVal -match '^([a-zA-Z0-9_\.-]+):\s*(.*)$') {
                    $map = [ordered]@{}
                    $map[$Matches[1]] = Convert-Scalar $Matches[2].Trim()
                    while ($Index.Value -lt $Lines.Count) {
                        $nextLine = $Lines[$Index.Value]
                        $nextIndent = $nextLine.Length - $nextLine.TrimStart().Length
                        if ($nextIndent -le $indent) { break }
                        $nextTrim = $nextLine.TrimStart()
                        if ($nextTrim.StartsWith("- ")) { break }
                        if ($nextTrim -match '^([a-zA-Z0-9_\.-]+):\s*(.*)$') {
                            $Index.Value++
                            $map[$Matches[1]] = Convert-Scalar $Matches[2].Trim()
                        } else { break }
                    }
                    $result.Add($map)
                } else {
                    $result.Add((Convert-Scalar $itemVal))
                }
            }
            return ,$result
        } else {
            $result = [ordered]@{}
            while ($Index.Value -lt $Lines.Count) {
                $line = $Lines[$Index.Value]
                $indent = $line.Length - $line.TrimStart().Length
                if ($indent -lt $CurrentIndent) { break }
                $trim = $line.TrimStart()
                if ($trim -match '^([a-zA-Z0-9_\.-]+):\s*(.*)$') {
                    $key = $Matches[1]
                    $rawVal = $Matches[2].Trim()
                    $Index.Value++

                    if ($rawVal.Length -eq 0) {
                        if ($Index.Value -lt $Lines.Count) {
                            $nextLine = $Lines[$Index.Value]
                            $nextIndent = $nextLine.Length - $nextLine.TrimStart().Length
                            if ($nextIndent -gt $indent) {
                                $result[$key] = Parse-Block -Lines $Lines -Index $Index -CurrentIndent $nextIndent
                            } else {
                                $result[$key] = $null
                            }
                        } else {
                            $result[$key] = $null
                        }
                    } else {
                        $result[$key] = Convert-Scalar $rawVal
                    }
                } else {
                    $Index.Value++
                }
            }
            return $result
        }
    }

    $idx = [ref]0
    return Parse-Block -Lines $cleaned -Index $idx -CurrentIndent 0
}

function Get-DevboxDefaultConfig {
    return [ordered]@{
        user = [ordered]@{
            name            = $env:USERNAME
            email           = "$($env:USERNAME)@localhost"
            github_username = ""
        }
        preset = "fullstack"
        modules = [ordered]@{
            packages    = $true
            fonts       = $true
            git         = $true
            shell       = $true
            editor      = $true
            runtimes    = $true
            databases   = $true
            envvars     = $true
            keybindings = $true
            glazewm     = $true
            zebar       = $true
            dotfiles    = $true
        }
        packages = @(
            "Microsoft.VisualStudioCode",
            "Git.Git",
            "GitHub.cli",
            "Microsoft.WindowsTerminal",
            "Starship.Starship",
            "7zip.7zip"
        )
        shell = [ordered]@{
            prompt = "starship"
            theme  = "custom"
        }
        git = [ordered]@{
            default_branch   = "main"
            autocrlf         = "input"
            generate_ssh_key = $true
            ssh_key_type     = "ed25519"
            gpg_signing      = $false
        }
        editor = [ordered]@{
            primary            = "vscode"
            sync_settings      = $true
            install_extensions = $true
        }
        fonts = @(
            "JetBrainsMono"
        )
        envvars = [ordered]@{
            DEVBOX_WIN = "true"
        }
    }
}

function Merge-DevboxConfig {
    param(
        [System.Collections.IDictionary]$Base,
        [System.Collections.IDictionary]$Override
    )

    if ($null -eq $Base) { return $Override }
    if ($null -eq $Override) { return $Base }

    $result = [ordered]@{}
    foreach ($k in $Base.Keys) {
        $result[$k] = $Base[$k]
    }

    foreach ($k in $Override.Keys) {
        $overrideVal = $Override[$k]
        if ($result.Contains($k) -and ($result[$k] -is [System.Collections.IDictionary]) -and ($overrideVal -is [System.Collections.IDictionary])) {
            $result[$k] = Merge-DevboxConfig -Base $result[$k] -Override $overrideVal
        } else {
            $result[$k] = $overrideVal
        }
    }

    return $result
}

function Get-DevboxPreset {
    param(
        [string]$PresetName,
        [string]$RepoRoot = ""
    )

    if ([string]::IsNullOrWhiteSpace($PresetName)) {
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
    }

    $presetFile = Join-Path $RepoRoot "presets\$PresetName.yaml"
    if (-not (Test-Path $presetFile)) {
        $presetFile = Join-Path $RepoRoot "presets\$PresetName.yml"
    }

    if (Test-Path $presetFile) {
        return Read-DevboxConfigFile -Path $presetFile -SkipPresetResolution
    }

    return $null
}

function Read-DevboxConfigFile {
    param(
        [string]$Path,
        [switch]$SkipPresetResolution,
        [string]$PresetOverride = ""
    )

    if (-not (Test-Path $Path)) {
        throw "Config file not found: $Path"
    }

    $rawContent = Get-Content -Path $Path -Raw -Encoding utf8
    $parsed = $null

    # Attempt powershell-yaml first if module is present
    if (Get-Module -ListAvailable -Name "powershell-yaml") {
        try {
            Import-Module powershell-yaml -ErrorAction Stop
            $parsed = ConvertFrom-Yaml $rawContent
        } catch {
            # Fall back to built-in parser
        }
    }

    if ($null -eq $parsed) {
        $parsed = ConvertFrom-SimpleYaml -YamlText $rawContent
    }

    if ($SkipPresetResolution) {
        return $parsed
    }

    # Resolve preset
    $presetName = if ($PresetOverride) {
        $PresetOverride
    } elseif ($parsed.Contains("preset") -and ($null -ne $parsed["preset"])) {
        $parsed["preset"].ToString().Trim()
    } else {
        ""
    }

    if ($presetName -and $presetName -ne "custom" -and $presetName -ne "none") {
        $repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
        $presetData = Get-DevboxPreset -PresetName $presetName -RepoRoot $repoRoot
        if ($null -ne $presetData) {
            $parsed = Merge-DevboxConfig -Base $presetData -Override $parsed
        }
    }

    return $parsed
}

function Test-DevboxConfig {
    param([System.Collections.IDictionary]$Config)

    $errors = [System.Collections.Generic.List[string]]::new()

    if ($null -eq $Config) {
        $errors.Add("Configuration object is null.")
        return [PSCustomObject]@{ Valid = $false; Errors = $errors }
    }

    # Validate modules table if specified
    if ($Config.Contains("modules") -and ($null -ne $Config["modules"])) {
        $knownModules = @("packages", "shell", "git", "editor", "fonts", "dotfiles", "envvars", "runtimes", "databases", "keybindings", "glazewm", "zebar")
        foreach ($modKey in $Config["modules"].Keys) {
            if ($knownModules -notcontains $modKey) {
                # Ignored or extended
            }
        }
    }

    # Validate git settings if git module enabled
    if ($Config.Contains("git") -and ($null -ne $Config["git"])) {
        if ($Config["git"].Contains("ssh_key_type")) {
            $validTypes = @("ed25519", "rsa", "ecdsa")
            if ($validTypes -notcontains $Config["git"]["ssh_key_type"]) {
                $errors.Add("Invalid git.ssh_key_type '$($Config["git"]["ssh_key_type"])'. Expected one of: ed25519, rsa, ecdsa.")
            }
        }
    }

    return [PSCustomObject]@{
        Valid  = ($errors.Count -eq 0)
        Errors = $errors
    }
}

function Export-DevboxConfigToYamlFile {
    param(
        [System.Collections.IDictionary]$Config,
        [string]$Path
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# ==============================================================================")
    [void]$sb.AppendLine("# devbox-win :: Active Workstation Configuration")
    [void]$sb.AppendLine("# Generated by: devbox-win Windows 11 Developer Utility")
    [void]$sb.AppendLine("# ==============================================================================")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("user:")
    [void]$sb.AppendLine("  name: `"$($Config.user.name)`"")
    [void]$sb.AppendLine("  email: `"$($Config.user.email)`"")
    [void]$sb.AppendLine("  github_username: `"$($Config.user.github_username)`"")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("preset: $($Config.preset)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("modules:")
    foreach ($m in $Config.modules.Keys) {
        [void]$sb.AppendLine("  ${m}: $(if ($Config.modules[$m]) { 'true' } else { 'false' })")
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("packages:")
    foreach ($p in $Config.packages) {
        [void]$sb.AppendLine("  - $p")
    }
    [void]$sb.AppendLine("")
    if ($Config.Contains("databases") -and ($null -ne $Config.databases) -and ($Config.databases.Count -gt 0)) {
        [void]$sb.AppendLine("databases:")
        foreach ($d in $Config.databases) {
            [void]$sb.AppendLine("  - $d")
        }
        [void]$sb.AppendLine("")
    }
    if ($Config.Contains("community_modules") -and ($null -ne $Config.community_modules) -and ($Config.community_modules.Count -gt 0)) {
        [void]$sb.AppendLine("community_modules:")
        foreach ($c in $Config.community_modules) {
            [void]$sb.AppendLine("  - $c")
        }
        [void]$sb.AppendLine("")
    }
    [void]$sb.AppendLine("editor:")
    [void]$sb.AppendLine("  primary: $($Config.editor.primary)")
    [void]$sb.AppendLine("  sync_settings: true")
    [void]$sb.AppendLine("  install_extensions: true")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("shell:")
    [void]$sb.AppendLine("  prompt: starship")
    [void]$sb.AppendLine("  theme: custom")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("git:")
    [void]$sb.AppendLine("  default_branch: $($Config.git.default_branch)")
    [void]$sb.AppendLine("  autocrlf: $($Config.git.autocrlf)")
    [void]$sb.AppendLine("  generate_ssh_key: $(if ($Config.git.generate_ssh_key) { 'true' } else { 'false' })")
    [void]$sb.AppendLine("  ssh_key_type: $($Config.git.ssh_key_type)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("runtimes:")
    [void]$sb.AppendLine("  node: $(if ($Config.runtimes.node) { 'true' } else { 'false' })")
    [void]$sb.AppendLine("  python: $(if ($Config.runtimes.python) { 'true' } else { 'false' })")
    [void]$sb.AppendLine("  rust: $(if ($Config.runtimes.rust) { 'true' } else { 'false' })")
    [void]$sb.AppendLine("  dotnet: $(if ($Config.runtimes.dotnet) { 'true' } else { 'false' })")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("glazewm:")
    [void]$sb.AppendLine("  install: $(if ($Config.glazewm.install) { 'true' } else { 'false' })")
    [void]$sb.AppendLine("  autostart: $(if ($Config.glazewm.autostart) { 'true' } else { 'false' })")
    [void]$sb.AppendLine("  hide_method: `"$($Config.glazewm.hide_method)`"")
    [void]$sb.AppendLine("  border_color: `"$($Config.glazewm.border_color)`"")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("zebar:")
    [void]$sb.AppendLine("  install: $(if ($Config.zebar.install) { 'true' } else { 'false' })")
    [void]$sb.AppendLine("  autostart: $(if ($Config.zebar.autostart) { 'true' } else { 'false' })")
    [void]$sb.AppendLine("  pack: `"$($Config.zebar.pack)`"")

    $dir = Split-Path -Parent $Path
    if ($dir -and (-not (Test-Path $dir))) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Set-Content -Path $Path -Value ($sb.ToString()) -Encoding utf8
}

function Export-GuiConfigToYamlFile {
    param([System.Collections.IDictionary]$Config, [string]$Path)
    Export-DevboxConfigToYamlFile -Config $Config -Path $Path
}
