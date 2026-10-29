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
