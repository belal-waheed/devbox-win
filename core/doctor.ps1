# ==============================================================================
# devbox-win :: Machine Health Doctor & Diagnostics
# Path: core/doctor.ps1
# Description: Comprehensive system environment, toolchain, and symlink audit.
# Standard: Zero emojis. Pure ANSI badges and structured diagnostic reports.
# ==============================================================================

[CmdletBinding()]
param(
    [switch]$AsObject,
    [switch]$Quiet
)

Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))

. (Join-Path $PSScriptRoot "logger.ps1")
. (Join-Path $PSScriptRoot "manifest.ps1")
. (Join-Path $PSScriptRoot "symlink.ps1")

function Invoke-DevboxDoctor {
    [CmdletBinding()]
    param(
        [switch]$AsObject,
        [switch]$Quiet
    )

    $script:checks = [System.Collections.Generic.List[object]]::new()
    $script:recommendations = [System.Collections.Generic.List[object]]::new()

    function Add-Check {
        param(
            [string]$Category,
            [string]$Name,
            [string]$Status, # OK, WARN, FAIL, INFO
            [string]$Message,
            [string]$Recommendation = ""
        )
        $chk = [PSCustomObject]@{
            Category       = $Category
            Name           = $Name
            Status         = $Status
            Message        = $Message
            Recommendation = $Recommendation
        }
        $script:checks.Add($chk)

        if ($Recommendation -and ($Status -eq "WARN" -or $Status -eq "FAIL")) {
            $script:recommendations.Add([PSCustomObject]@{
                Item           = $Name
                Status         = $Status
                Recommendation = $Recommendation
            })
        }
    }

    # --------------------------------------------------------------------------
    # 1. Operating System & Platform Architecture
    # --------------------------------------------------------------------------
    $osBuild = [System.Environment]::OSVersion.Version.Build
    if ($osBuild -ge 22000) {
        Add-Check -Category "System" -Name "Windows 11 Build" -Status "OK" `
            -Message "Build $osBuild (Supported)"
    } else {
        Add-Check -Category "System" -Name "Windows 11 Build" -Status "FAIL" `
            -Message "Build $osBuild (Unsupported: requires Windows 11 Build 22000+)" `
            -Recommendation "Upgrade the operating system to Windows 11 Build 22000 or higher."
    }

    # --------------------------------------------------------------------------
    # 2. Windows Developer Mode (Enables unprivileged symlinks)
    # --------------------------------------------------------------------------
    $devModeReg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    $devModeVal = (Get-ItemProperty -Path $devModeReg -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
    if ($devModeVal -eq 1) {
        Add-Check -Category "System" -Name "Developer Mode" -Status "OK" `
            -Message "Enabled (Unprivileged symbolic links permitted)"
    } else {
        Add-Check -Category "System" -Name "Developer Mode" -Status "WARN" `
            -Message "Disabled (Symlink creation will require elevation)" `
            -Recommendation "Enable Developer Mode in Windows Settings (System -> For developers) or run bootstrap.ps1 as Administrator."
    }

    # --------------------------------------------------------------------------
    # 3. PowerShell Runtime & Execution Policy
    # --------------------------------------------------------------------------
    $psVer = $PSVersionTable.PSVersion
    $execPolicy = Get-ExecutionPolicy
    $isPolicyRestricted = ($execPolicy -eq "Restricted" -or $execPolicy -eq "Undefined")

    if ($psVer.Major -ge 7) {
        if ($isPolicyRestricted) {
            Add-Check -Category "System" -Name "PowerShell Runtime" -Status "WARN" `
                -Message "PowerShell $psVer (ExecutionPolicy: $execPolicy)" `
                -Recommendation "Run: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"
        } else {
            Add-Check -Category "System" -Name "PowerShell Runtime" -Status "OK" `
                -Message "PowerShell $psVer ($execPolicy)"
        }
    } else {
        Add-Check -Category "System" -Name "PowerShell Runtime" -Status "FAIL" `
            -Message "Windows PowerShell $psVer (PowerShell 7+ required)" `
            -Recommendation "Install PowerShell 7+ via winget: winget install --id Microsoft.PowerShell"
    }

    # --------------------------------------------------------------------------
    # 4. Long Paths Support (MAX_PATH removal)
    # --------------------------------------------------------------------------
    $longPathsReg = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    $longPathsVal = (Get-ItemProperty -Path $longPathsReg -ErrorAction SilentlyContinue).LongPathsEnabled
    if ($longPathsVal -eq 1) {
        Add-Check -Category "System" -Name "Long Paths Support" -Status "OK" `
            -Message "Enabled (Win32 MAX_PATH 260-char limitation removed)"
    } else {
        Add-Check -Category "System" -Name "Long Paths Support" -Status "WARN" `
            -Message "Disabled (Deep paths may cause filesystem operations to fail)" `
            -Recommendation "Run as Administrator: Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1"
    }

    # --------------------------------------------------------------------------
    # 5. Winget Toolchain & Health
    # --------------------------------------------------------------------------
    $wingetCmd = Get-Command "winget" -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        $wingetVer = & winget --version 2>$null
        if ($LASTEXITCODE -eq 0 -and (-not [string]::IsNullOrWhiteSpace($wingetVer))) {
            $cleanWinget = $wingetVer.Trim()
            if (-not $cleanWinget.StartsWith("v", [System.StringComparison]::OrdinalIgnoreCase)) {
                $cleanWinget = "v$cleanWinget"
            }
            Add-Check -Category "System" -Name "Winget Toolchain" -Status "OK" `
                -Message $cleanWinget
        } else {
            Add-Check -Category "System" -Name "Winget Toolchain" -Status "WARN" `
                -Message "CLI present but execution failed" `
                -Recommendation "Repair Windows App Installer from the Microsoft Store."
        }
    } else {
        Add-Check -Category "System" -Name "Winget Toolchain" -Status "FAIL" `
            -Message "winget command not found in PATH" `
            -Recommendation "Install App Installer from the Microsoft Store or download from https://github.com/microsoft/winget-cli/releases"
    }

    # --------------------------------------------------------------------------
    # 6. Network Connectivity (GitHub APIs and raw content)
    # --------------------------------------------------------------------------
    $netOk = $false
    $netMessage = ""
    try {
        $handler = [System.Net.Http.SocketsHttpHandler]::new()
        $handler.ConnectTimeout = [TimeSpan]::FromSeconds(4)
        $client = [System.Net.Http.HttpClient]::new($handler)
        $client.Timeout = [TimeSpan]::FromSeconds(5)

        $t1 = $client.GetAsync("https://github.com")
        $t2 = $client.GetAsync("https://raw.githubusercontent.com")
        [System.Threading.Tasks.Task]::WaitAll(@($t1, $t2))

        if ($t1.Result.IsSuccessStatusCode -and $t2.Result.IsSuccessStatusCode) {
            $netOk = $true
            $netMessage = "github.com & raw.githubusercontent.com reachable"
        } else {
            $netMessage = "GitHub endpoints responded with non-success HTTP status"
        }
    } catch {
        $netMessage = $_.Exception.Message
    }

    if ($netOk) {
        Add-Check -Category "System" -Name "Network Connectivity" -Status "OK" `
            -Message $netMessage
    } else {
        Add-Check -Category "System" -Name "Network Connectivity" -Status "FAIL" `
            -Message "Connection failed ($netMessage)" `
            -Recommendation "Verify internet connectivity, proxy configuration, or firewall rules blocking GitHub."
    }

    # --------------------------------------------------------------------------
    # 7. Git Installation & Configured Identity
    # --------------------------------------------------------------------------
    $gitCmd = Get-Command "git" -ErrorAction SilentlyContinue
    if ($gitCmd) {
        $gitVer = (& git --version 2>$null)
        $gitName = (& git config --get user.name 2>$null)
        $gitEmail = (& git config --get user.email 2>$null)

        $cleanName = if ($gitName) { $gitName.Trim() } else { "" }
        $cleanEmail = if ($gitEmail) { $gitEmail.Trim() } else { "" }

        if ($cleanName -and $cleanEmail) {
            Add-Check -Category "Git" -Name "Git Identity" -Status "OK" `
                -Message "$cleanName <$cleanEmail> ($($gitVer.Trim()))"
        } else {
            Add-Check -Category "Git" -Name "Git Identity" -Status "WARN" `
                -Message "Git installed ($($gitVer.Trim())) but user.name or user.email unset" `
                -Recommendation "Run: git config --global user.name 'Your Name'; git config --global user.email 'you@example.com'"
        }
    } else {
        Add-Check -Category "Git" -Name "Git CLI" -Status "WARN" `
            -Message "Git not detected in PATH" `
            -Recommendation "Install Git: winget install --id Git.Git"
    }

    # --------------------------------------------------------------------------
    # 8. Symlink Integrity & Manifest Audit
    # --------------------------------------------------------------------------
    $manifest = Load-DevboxManifest
    $symlinks = if ($manifest.Contains("symlinks") -and ($null -ne $manifest["symlinks"])) { @($manifest["symlinks"]) } else { @() }

    $brokenLinks = [System.Collections.Generic.List[object]]::new()
    $healthyCount = 0

    if ($symlinks.Count -gt 0) {
        foreach ($link in $symlinks) {
            $dst = $link.destination
            $src = $link.source

            $dstExists = Test-Path -LiteralPath $dst
            $srcExists = Test-Path -LiteralPath $src

            $isReparse = $false
            if ($dstExists) {
                $dstItem = Get-Item -LiteralPath $dst -Force -ErrorAction SilentlyContinue
                if ($null -ne $dstItem -and ($dstItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                    $isReparse = $true
                }
            }

            if ($dstExists -and $isReparse -and $srcExists) {
                $healthyCount++
            } else {
                $brokenReason = if (-not $dstExists) { "Destination missing" }
                                elseif (-not $isReparse) { "Destination is regular file, not a symlink" }
                                elseif (-not $srcExists) { "Target source file missing ($src)" }
                                else { "Invalid link structure" }
                $brokenLinks.Add([PSCustomObject]@{
                    Destination = $dst
                    Source      = $src
                    Reason      = $brokenReason
                })
            }
        }

        if ($brokenLinks.Count -gt 0) {
            Add-Check -Category "Dotfiles" -Name "Symlink Integrity" -Status "WARN" `
                -Message "$($brokenLinks.Count) of $($symlinks.Count) symlink(s) broken or orphaned" `
                -Recommendation "Repair symlinks by running: pwsh -NoProfile -File core/engine.ps1 -Module dotfiles"
        } else {
            Add-Check -Category "Dotfiles" -Name "Symlink Integrity" -Status "OK" `
                -Message "All $healthyCount registered symlink(s) healthy and resolved"
        }
    } else {
        Add-Check -Category "Dotfiles" -Name "Symlink Integrity" -Status "INFO" `
            -Message "No active symlinks registered in ~/.devbox-win/manifest.json"
    }

    # --------------------------------------------------------------------------
    # 9. Toolchain & Runtime Inventory
    # --------------------------------------------------------------------------
    # VS Code
    $codeCmd = Get-Command "code" -ErrorAction SilentlyContinue
    if ($codeCmd) {
        $codeVer = & code --version 2>$null
        $codeVerStr = if ($codeVer) { $codeVer[0].Trim() } else { "Installed" }
        Add-Check -Category "Toolchain" -Name "Visual Studio Code" -Status "OK" -Message "v$codeVerStr"
    } else {
        Add-Check -Category "Toolchain" -Name "Visual Studio Code" -Status "INFO" -Message "Not installed in PATH"
    }

    # Windows Terminal
    $wtCmd = Get-Command "wt.exe" -ErrorAction SilentlyContinue
    $wtPkg = Get-AppxPackage -Name "Microsoft.WindowsTerminal" -ErrorAction SilentlyContinue
    if ($wtCmd -or $wtPkg) {
        $wtVer = if ($wtPkg) { $wtPkg.Version } else { "Installed" }
        Add-Check -Category "Toolchain" -Name "Windows Terminal" -Status "OK" -Message "Installed ($wtVer)"
    } else {
        Add-Check -Category "Toolchain" -Name "Windows Terminal" -Status "INFO" -Message "Not installed"
    }

    # Starship Prompt
    $starCmd = Get-Command "starship" -ErrorAction SilentlyContinue
    if ($starCmd) {
        $starVer = & starship --version 2>$null
        $starStr = if ($starVer) { ($starVer -split '\s+')[1] } else { "Installed" }
        Add-Check -Category "Toolchain" -Name "Starship Prompt" -Status "OK" -Message "v$starStr"
    } else {
        Add-Check -Category "Toolchain" -Name "Starship Prompt" -Status "WARN" -Message "Not installed or not in PATH" `
            -Recommendation "Install Starship prompt: winget install --id Starship.Starship"
    }

    # Node.js
    $nodeCmd = Get-Command "node" -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        $nodeVer = & node -v 2>$null
        Add-Check -Category "Toolchain" -Name "Node.js Runtime" -Status "OK" -Message "$($nodeVer.Trim())"
    } else {
        Add-Check -Category "Toolchain" -Name "Node.js Runtime" -Status "INFO" -Message "Not installed"
    }

    # Python
    $pyCmd = Get-Command "python" -ErrorAction SilentlyContinue
    if ($pyCmd) {
        $pyVer = & python --version 2>$null
        Add-Check -Category "Toolchain" -Name "Python Runtime" -Status "OK" -Message "$($pyVer.Trim())"
    } else {
        Add-Check -Category "Toolchain" -Name "Python Runtime" -Status "INFO" -Message "Not installed"
    }

    # Rust
    $rustCmd = Get-Command "rustc" -ErrorAction SilentlyContinue
    if ($rustCmd) {
        $rustVer = & rustc --version 2>$null
        Add-Check -Category "Toolchain" -Name "Rust Toolchain" -Status "OK" -Message "$($rustVer.Trim())"
    } else {
        Add-Check -Category "Toolchain" -Name "Rust Toolchain" -Status "INFO" -Message "Not installed"
    }

    # .NET SDK
    $dotnetCmd = Get-Command "dotnet" -ErrorAction SilentlyContinue
    if ($dotnetCmd) {
        $dotnetVer = & dotnet --version 2>$null
        Add-Check -Category "Toolchain" -Name ".NET SDK" -Status "OK" -Message "v$($dotnetVer.Trim())"
    } else {
        Add-Check -Category "Toolchain" -Name ".NET SDK" -Status "INFO" -Message "Not installed"
    }

    # GlazeWM
    $glazeCmd = Get-Command "glazewm" -ErrorAction SilentlyContinue
    $glazeProc = Get-Process "glazewm" -ErrorAction SilentlyContinue
    if ($glazeCmd -or $glazeProc) {
        $statusStr = if ($glazeProc) { "Installed (Active / Running)" } else { "Installed (Not running)" }
        Add-Check -Category "Toolchain" -Name "GlazeWM Tiling WM" -Status "OK" -Message $statusStr
    } else {
        Add-Check -Category "Toolchain" -Name "GlazeWM Tiling WM" -Status "INFO" -Message "Not installed"
    }

    # Zebar
    $zebarCmd = Get-Command "zebar" -ErrorAction SilentlyContinue
    $zebarProc = Get-Process "zebar" -ErrorAction SilentlyContinue
    if ($zebarCmd -or $zebarProc) {
        $statusStr = if ($zebarProc) { "Installed (Active / Running)" } else { "Installed (Not running)" }
        Add-Check -Category "Toolchain" -Name "Zebar Status Bar" -Status "OK" -Message $statusStr
    } else {
        Add-Check -Category "Toolchain" -Name "Zebar Status Bar" -Status "INFO" -Message "Not installed"
    }

    # --------------------------------------------------------------------------
    # Calculate Summary Statistics
    # --------------------------------------------------------------------------
    $passCount = @($script:checks | Where-Object { $_.Status -eq "OK" }).Count
    $warnCount = @($script:checks | Where-Object { $_.Status -eq "WARN" }).Count
    $failCount = @($script:checks | Where-Object { $_.Status -eq "FAIL" }).Count
    $infoCount = @($script:checks | Where-Object { $_.Status -eq "INFO" }).Count

    $doctorResult = [PSCustomObject]@{
        Checks          = $script:checks
        BrokenSymlinks  = $brokenLinks
        Recommendations = $script:recommendations
        Passed          = $passCount
        Warnings        = $warnCount
        Failures        = $failCount
        Info            = $infoCount
        Healthy         = ($failCount -eq 0)
    }

    if ($AsObject) {
        return $doctorResult
    }

    # --------------------------------------------------------------------------
    # Render Diagnostic TUI
    # --------------------------------------------------------------------------
    if (-not $Quiet) {
        Write-DevboxBanner -SubTitle "Machine Health & Environment Doctor"

        $categoryOrder = @("System", "Git", "Dotfiles", "Toolchain")
        $grouped = $script:checks | Group-Object Category
        $sortedGroups = $grouped | Sort-Object {
            $idx = $categoryOrder.IndexOf($_.Name)
            if ($idx -ge 0) { $idx } else { 99 }
        }

        foreach ($group in $sortedGroups) {
            Write-DevboxSection "$($group.Name) Diagnostics"
            foreach ($item in $group.Group) {
                $nameFormatted = "{0,-26}" -f $item.Name
                switch ($item.Status) {
                    "OK"   { Write-Host "  $($script:C.BrightGreen)$($script:C.Bold)[OK]$($script:C.Reset)   $nameFormatted : $($item.Message)" }
                    "WARN" { Write-Host "  $($script:C.BrightYellow)$($script:C.Bold)[WARN]$($script:C.Reset) $nameFormatted : $($item.Message)" }
                    "FAIL" { Write-Host "  $($script:C.BrightRed)$($script:C.Bold)[FAIL]$($script:C.Reset) $nameFormatted : $($item.Message)" }
                    "INFO" { Write-Host "  $($script:C.Cyan)$($script:C.Bold)[INFO]$($script:C.Reset) $nameFormatted : $($item.Message)" }
                }
            }
        }

        if ($brokenLinks.Count -gt 0) {
            Write-DevboxSection "Broken Symlink Details"
            foreach ($bl in $brokenLinks) {
                Write-Host "  $($script:C.BrightRed)[FAIL]$($script:C.Reset) Destination: $($bl.Destination)"
                Write-Host "         Expected Source : $($bl.Source)"
                Write-Host "         Diagnosis       : $($bl.Reason)"
            }
        }

        if ($recommendations.Count -gt 0) {
            Write-DevboxSection "Recommended Remediations"
            foreach ($rec in $recommendations) {
                $badge = if ($rec.Status -eq "FAIL") { "$($script:C.BrightRed)[FIX]$($script:C.Reset)" } else { "$($script:C.BrightYellow)[FIX]$($script:C.Reset)" }
                Write-Host "  $badge $($script:C.Bold)$($rec.Item)$($script:C.Reset)"
                Write-Host "         $($rec.Recommendation)"
            }
        }

        Write-Host ""
        Write-Host "$($script:C.Gray)==============================================================================$($script:C.Reset)"
        Write-Host "  $($script:C.Bold)DOCTOR AUDIT SUMMARY$($script:C.Reset)"
        Write-Host "$($script:C.Gray)------------------------------------------------------------------------------$($script:C.Reset)"
        Write-Host "  $($script:C.BrightGreen)[OK]   Healthy Checks$($script:C.Reset)    : $passCount"
        Write-Host "  $($script:C.Cyan)[INFO] Inventory Items$($script:C.Reset)   : $infoCount"
        Write-Host "  $($script:C.BrightYellow)[WARN] Warnings / Notices$($script:C.Reset): $warnCount"
        if ($failCount -gt 0) {
            Write-Host "  $($script:C.BrightRed)[FAIL] Critical Failures$($script:C.Reset) : $failCount"
        } else {
            Write-Host "  $($script:C.Dim)[FAIL] Critical Failures : 0$($script:C.Reset)"
        }
        Write-Host "$($script:C.Gray)==============================================================================$($script:C.Reset)"

        if ($failCount -gt 0) {
            Write-Host ""
            Write-Host "  $($script:C.BrightRed)$($script:C.Bold)System status: ATTENTION REQUIRED ($failCount critical failure(s))$($script:C.Reset)"
            Write-Host "  Resolve critical failures before provisioning to prevent setup errors."
            Write-Host ""
        } elseif ($warnCount -gt 0) {
            Write-Host ""
            Write-Host "  $($script:C.BrightGreen)$($script:C.Bold)System status: HEALTHY$($script:C.Reset) $($script:C.Dim)($warnCount non-blocking recommendation(s))$($script:C.Reset)"
            Write-Host ""
        } else {
            Write-Host ""
            Write-Host "  $($script:C.BrightGreen)$($script:C.Bold)System status: OPTIMAL - Machine is fully configured for devbox-win.$($script:C.Reset)"
            Write-Host ""
        }
    }

    if ($failCount -gt 0) {
        exit 1
    } else {
        exit 0
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-DevboxDoctor -AsObject:$AsObject -Quiet:$Quiet
}
