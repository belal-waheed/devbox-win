# ==============================================================================
# devbox-win :: Community Module Marketplace
# Path: core/marketplace.ps1
# Description: Discovers, validates, and installs community extensions.
# Standard: Zero emojis. Strict contract enforcement and clean ANSI tables.
# ==============================================================================

[CmdletBinding()]
param(
    [string]$InstallModule = "",
    [switch]$ListModules,
    [string]$RepoRoot = "",
    [switch]$DryRun
)

Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

. (Join-Path $PSScriptRoot "logger.ps1")
. (Join-Path $PSScriptRoot "config.ps1")

# Curated Community Catalog
$script:CuratedCatalog = @(
    @{
        Name         = "gaming"
        Description  = "Gaming & streaming toolchain (Steam, OBS Studio, Discord)"
        Author       = "devbox-win"
        Version      = "1.0.0"
        Dependencies = @("packages")
        Url          = "https://raw.githubusercontent.com/bel/devbox-win/main/modules/community/gaming.ps1"
    },
    @{
        Name         = "ai-tools"
        Description  = "Local AI workstation stack (Ollama, LM Studio, Hugging Face CLI)"
        Author       = "devbox-win"
        Version      = "1.0.0"
        Dependencies = @("packages")
        Url          = "https://raw.githubusercontent.com/bel/devbox-win/main/modules/community/ai-tools.ps1"
    },
    @{
        Name         = "game-dev"
        Description  = "Game development workstation (Unity Hub, Blender, Godot)"
        Author       = "community"
        Version      = "1.0.0"
        Dependencies = @("packages")
        Url          = "https://raw.githubusercontent.com/bel/devbox-win/main/modules/community/game-dev.ps1"
    },
    @{
        Name         = "music-production"
        Description  = "Audio production & DAW tools (Audacity, Reaper, ASIO4ALL)"
        Author       = "community"
        Version      = "1.0.0"
        Dependencies = @("packages")
        Url          = "https://raw.githubusercontent.com/bel/devbox-win/main/modules/community/music-production.ps1"
    }
)

function Test-DevboxCommunityModuleContract {
    param([string]$Path)

    $errors = [System.Collections.Generic.List[string]]::new()
    $metadata = [ordered]@{}

    if (-not (Test-Path $Path)) {
        $errors.Add("Module file does not exist at path: $Path")
        return [PSCustomObject]@{
            Valid    = $false
            Errors   = $errors
            Metadata = $metadata
        }
    }

    # 1. AST Syntax Check
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors -and $parseErrors.Count -gt 0) {
        foreach ($pe in $parseErrors) {
            $errors.Add("Syntax error at line $($pe.Extent.StartLineNumber): $($pe.Message)")
        }
        return [PSCustomObject]@{
            Valid    = $false
            Errors   = $errors
            Metadata = $metadata
        }
    }

    # 2. Check for required function definitions in AST
    $functionDefs = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    $functionNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($f in $functionDefs) {
        [void]$functionNames.Add($f.Name)
    }

    $requiredFunctions = @("Test-TargetState", "Invoke-Module", "Get-ModuleMetadata")
    foreach ($rf in $requiredFunctions) {
        if (-not $functionNames.Contains($rf)) {
            $errors.Add("Contract violation: Missing required function '$rf'")
        }
    }

    # 3. Extract and validate metadata
    if ($functionNames.Contains("Get-ModuleMetadata")) {
        try {
            $metaFuncAst = $functionDefs | Where-Object { $_.Name -eq "Get-ModuleMetadata" } | Select-Object -First 1
            if ($null -ne $metaFuncAst) {
                $sb = [scriptblock]::Create($metaFuncAst.Extent.Text + "; Get-ModuleMetadata")
                $metaObj = & $sb

                if ($metaObj -and ($metaObj -is [System.Collections.IDictionary] -or $metaObj.PSObject.Properties['Name'])) {
                    if ($metaObj -is [System.Collections.IDictionary]) {
                        foreach ($k in $metaObj.Keys) { $metadata[$k] = $metaObj[$k] }
                    } else {
                        foreach ($prop in $metaObj.PSObject.Properties) { $metadata[$prop.Name] = $prop.Value }
                    }

                    if (-not $metadata.Contains("Name") -or [string]::IsNullOrWhiteSpace($metadata["Name"])) {
                        $errors.Add("Contract violation: Metadata must contain non-empty 'Name'")
                    }
                    if (-not $metadata.Contains("Description") -or [string]::IsNullOrWhiteSpace($metadata["Description"])) {
                        $errors.Add("Contract violation: Metadata must contain non-empty 'Description'")
                    }
                    if (-not $metadata.Contains("Dependencies")) {
                        $metadata["Dependencies"] = @("packages")
                    }
                } else {
                    $errors.Add("Contract violation: 'Get-ModuleMetadata' must return a metadata dictionary or object")
                }
            } else {
                $errors.Add("Contract violation: Missing 'Get-ModuleMetadata' AST")
            }
        } catch {
            $errors.Add("Failed to evaluate 'Get-ModuleMetadata': $($_.Exception.Message)")
        }
    }

    return [PSCustomObject]@{
        Valid    = ($errors.Count -eq 0)
        Errors   = $errors
        Metadata = $metadata
    }
}

function Get-DevboxCommunityModules {
    param(
        [string]$RepoRoot = ""
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
    }

    $communityDir = Join-Path $RepoRoot "modules\community"
    $results = [System.Collections.Generic.List[object]]::new()

    if (-not (Test-Path $communityDir)) {
        return ,$results
    }

    # Load active config to check enabled status
    $configFile = Join-Path $RepoRoot "config.yaml"
    $activeCommunityList = @()
    if (Test-Path $configFile) {
        try {
            $parsed = Read-DevboxConfigFile -Path $configFile -SkipPresetResolution
            if ($parsed.Contains("community_modules") -and ($null -ne $parsed["community_modules"])) {
                $activeCommunityList = @($parsed["community_modules"])
            }
        } catch {
            # Ignore config read errors
        }
    }

    $files = Get-ChildItem -Path $communityDir -Filter "*.ps1" -File
    foreach ($f in $files) {
        $contract = Test-DevboxCommunityModuleContract -Path $f.FullName
        $modName = if ($contract.Metadata.Contains("Name")) { $contract.Metadata["Name"] } else { [System.IO.Path]::GetFileNameWithoutExtension($f.Name) }
        $desc    = if ($contract.Metadata.Contains("Description")) { $contract.Metadata["Description"] } else { "No description provided" }
        $author  = if ($contract.Metadata.Contains("Author")) { $contract.Metadata["Author"] } else { "Unknown" }
        $version = if ($contract.Metadata.Contains("Version")) { $contract.Metadata["Version"] } else { "1.0.0" }
        $deps    = if ($contract.Metadata.Contains("Dependencies")) { @($contract.Metadata["Dependencies"]) } else { @("packages") }

        $isEnabled = ($activeCommunityList -contains $modName)

        $results.Add([PSCustomObject]@{
            Name         = $modName
            Description  = $desc
            Author       = $author
            Version      = $version
            Dependencies = $deps
            Valid        = $contract.Valid
            Errors       = $contract.Errors
            Path         = $f.FullName
            Enabled      = $isEnabled
            Installed    = $true
        })
    }

    return ,$results
}

function Install-DevboxCommunityModule {
    param(
        [Parameter(Mandatory=$true)][string]$NameOrUrl,
        [string]$RepoRoot = "",
        [switch]$DryRun
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
    }

    $communityDir = Join-Path $RepoRoot "modules\community"
    if (-not (Test-Path $communityDir)) {
        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $communityDir -Force | Out-Null
        }
    }

    $isUrl = ($NameOrUrl -match "^https?://")
    $targetFileName = ""
    $downloadUrl = ""

    if ($isUrl) {
        $downloadUrl = $NameOrUrl
        $uri = [System.Uri]$downloadUrl
        $targetFileName = [System.IO.Path]::GetFileName($uri.AbsolutePath)
        if (-not $targetFileName.EndsWith(".ps1", [System.StringComparison]::OrdinalIgnoreCase)) {
            $targetFileName = "$targetFileName.ps1"
        }
    } else {
        # Check if matching module is in curated catalog
        $catalogMatch = $script:CuratedCatalog | Where-Object { $_.Name -eq $NameOrUrl } | Select-Object -First 1
        if ($catalogMatch) {
            $targetFileName = "$($catalogMatch.Name).ps1"
            $downloadUrl = $catalogMatch.Url
        } else {
            $targetFileName = "$NameOrUrl.ps1"
        }
    }

    $destPath = Join-Path $communityDir $targetFileName

    if (Test-Path $destPath) {
        Write-DevboxInfo "Community module '$targetFileName' is already present locally at: $destPath"
        $contract = Test-DevboxCommunityModuleContract -Path $destPath
        if ($contract.Valid) {
            Write-DevboxOk "Contract check: PASSED (Valid community module)"
        } else {
            Write-DevboxWarn "Local file does not satisfy contract: $($contract.Errors -join '; ')"
        }
        return [PSCustomObject]@{ Status = "SKIP"; Path = $destPath; Message = "Module already installed" }
    }

    if ($DryRun) {
        Write-DevboxDryRun "Would download and install community module: $targetFileName from $downloadUrl"
        return [PSCustomObject]@{ Status = "OK"; Path = $destPath; Message = "Dry run: would install" }
    }

    if (-not $downloadUrl) {
        Write-DevboxFail "Cannot resolve source URL for community module: $NameOrUrl"
        return [PSCustomObject]@{ Status = "FAIL"; Message = "Unknown module or missing URL" }
    }

    Write-DevboxInfo "Downloading community module from: $downloadUrl..."
    try {
        Invoke-RestMethod -Uri $downloadUrl -OutFile $destPath -ErrorAction Stop
        Write-DevboxOk "Downloaded to $destPath"
    } catch {
        Write-DevboxFail "Download failed" $_.Exception.Message
        return [PSCustomObject]@{ Status = "FAIL"; Message = $_.Exception.Message }
    }

    # Validate contract
    $contract = Test-DevboxCommunityModuleContract -Path $destPath
    if (-not $contract.Valid) {
        Write-DevboxFail "Module does not satisfy devbox-win community contract. Removing file."
        foreach ($err in $contract.Errors) {
            Write-DevboxFail "  $err"
        }
        Remove-Item -Path $destPath -Force -ErrorAction SilentlyContinue
        return [PSCustomObject]@{ Status = "FAIL"; Message = "Contract validation failed" }
    }

    Write-DevboxOk "Community module verified and installed: $($contract.Metadata['Name']) v$($contract.Metadata['Version'])"
    Write-DevboxInfo "To activate in DAG execution, add to your config.yaml:"
    Write-Host "       community_modules:"
    Write-Host "         - $($contract.Metadata['Name'])"

    return [PSCustomObject]@{
        Status   = "OK"
        Path     = $destPath
        Metadata = $contract.Metadata
    }
}

function Show-DevboxMarketplace {
    param(
        [string]$RepoRoot = ""
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
    }

    Write-DevboxBanner -SubTitle "Community Module Marketplace"

    $installed = Get-DevboxCommunityModules -RepoRoot $RepoRoot

    Write-DevboxSection "Locally Installed Community Modules"
    if ($installed.Count -eq 0) {
        Write-Host "  $($script:C.Dim)No community modules installed in modules/community/$($script:C.Reset)"
    } else {
        foreach ($mod in $installed) {
            $statusBadge = if ($mod.Valid) {
                if ($mod.Enabled) { "$($script:C.BrightGreen)[ENABLED]$($script:C.Reset)" } else { "$($script:C.Cyan)[INSTALLED]$($script:C.Reset)" }
            } else {
                "$($script:C.BrightRed)[INVALID]$($script:C.Reset)"
            }
            $nameFormatted = "{0,-18}" -f $mod.Name
            $verFormatted  = "{0,-7}" -f "v$($mod.Version)"
            Write-Host "  $statusBadge $nameFormatted $verFormatted : $($mod.Description)"
            Write-Host "             $($script:C.Dim)Dependencies: $($mod.Dependencies -join ', ') | Author: $($mod.Author)$($script:C.Reset)"
        }
    }

    Write-DevboxSection "Curated Community Catalog"
    foreach ($cat in $script:CuratedCatalog) {
        $isInst = @($installed | Where-Object { $_.Name -eq $cat.Name }).Count -gt 0
        $badge = if ($isInst) { "$($script:C.BrightGreen)[AVAILABLE - INSTALLED]$($script:C.Reset)" } else { "$($script:C.BrightCyan)[CATALOG ITEM]$($script:C.Reset)" }
        $nameFormatted = "{0,-16}" -f $cat.Name
        Write-Host "  $badge $nameFormatted : $($cat.Description)"
        Write-Host "         $($script:C.Dim)Command: pwsh -NoProfile -File core/engine.ps1 -InstallModule $($cat.Name)$($script:C.Reset)"
    }

    Write-Host ""
    Write-Host "$($script:C.Gray)==============================================================================$($script:C.Reset)"
    Write-Host "  $($script:C.Bold)MARKETPLACE CLI USAGE$($script:C.Reset)"
    Write-Host "$($script:C.Gray)------------------------------------------------------------------------------$($script:C.Reset)"
    Write-Host "  Browse Catalog   : pwsh -NoProfile -File core/engine.ps1 -Marketplace"
    Write-Host "  Install by Name  : pwsh -NoProfile -File core/engine.ps1 -InstallModule <name>"
    Write-Host "  Install from URL : pwsh -NoProfile -File core/engine.ps1 -InstallModule https://example.com/custom.ps1"
    Write-Host "  Enable in Config : Add to config.yaml under 'community_modules: [ <name> ]'"
    Write-Host "$($script:C.Gray)==============================================================================$($script:C.Reset)"
    Write-Host ""
}

# Direct invocation handling
if ($MyInvocation.InvocationName -ne '.') {
    if ($InstallModule) {
        Write-DevboxBanner -SubTitle "Community Module Installer"
        $res = Install-DevboxCommunityModule -NameOrUrl $InstallModule -RepoRoot $RepoRoot -DryRun:$DryRun
        if ($res.Status -eq "FAIL") { exit 1 } else { exit 0 }
    } else {
        Show-DevboxMarketplace -RepoRoot $RepoRoot
        exit 0
    }
}
