# ==============================================================================
# devbox-win :: Lightweight Visual Dashboard Companion
# Path: core/dashboard.ps1
# Description: Generates standalone HTML dashboard and launches in Microsoft Edge.
# Standard: Zero emojis. WCAG AA compliance, 8px grid, SVG vector icons, dark theme.
# ==============================================================================

[CmdletBinding()]
param(
    [string]$OutputPath = "",
    [switch]$NoLaunch,
    [string]$RepoRoot = ""
)

Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

. (Join-Path $PSScriptRoot "logger.ps1")
. (Join-Path $PSScriptRoot "config.ps1")
. (Join-Path $PSScriptRoot "doctor.ps1")
. (Join-Path $PSScriptRoot "manifest.ps1")
. (Join-Path $PSScriptRoot "state.ps1")

function Get-EdgeExecutablePath {
    $candidates = @(
        "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        "C:\Program Files\Microsoft\Edge\Application\msedge.exe",
        "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    $cmd = Get-Command "msedge" -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return ""
}

function New-DevboxDashboardHtml {
    param(
        [string]$RepoRoot,
        [string]$DestinationPath
    )

    Write-DevboxInfo "Gathering workstation health diagnostics and configuration state..."

    # 1. Run Doctor Audit
    $doctorObj = Invoke-DevboxDoctor -AsObject -Quiet
    $checks = if ($doctorObj -and $doctorObj.Checks) { @($doctorObj.Checks) } else { @() }
    $passCount = if ($doctorObj) { $doctorObj.Passed } else { 0 }
    $warnCount = if ($doctorObj) { $doctorObj.Warnings } else { 0 }
    $failCount = if ($doctorObj) { $doctorObj.Failures } else { 0 }
    $totalChecks = $checks.Count

    # 2. Load Configuration
    $configFile = Join-Path $RepoRoot "config.yaml"
    $config = $null
    if (Test-Path $configFile) {
        try {
            $config = Read-DevboxConfigFile -Path $configFile
        } catch {
            $config = Get-DevboxDefaultConfig
        }
    } else {
        $config = Get-DevboxDefaultConfig
    }

    $userName = if ($config.user -and $config.user.name) { $config.user.name } else { $env:USERNAME }
    $userEmail = if ($config.user -and $config.user.email) { $config.user.email } else { "$($env:USERNAME)@localhost" }
    $activePreset = if ($config.preset) { $config.preset } else { "fullstack" }

    # 3. Load Manifest & State
    $manifest = Load-DevboxManifest
    $installedPkgs = if ($manifest.Contains("packages") -and $manifest["packages"]) { @($manifest["packages"].Keys) } else { @() }
    $installedCount = @($installedPkgs).Count
    $symlinks = if ($manifest.Contains("symlinks") -and $manifest["symlinks"]) { @($manifest["symlinks"].Keys) } else { @() }
    $symlinksCount = @($symlinks).Count

    $state = Load-DevboxState
    $completedModules = if ($state.Contains("completedModules") -and $state["completedModules"]) { @($state["completedModules"]) } else { @() }

    # 4. Tiling WM & Shell Process Checks
    $glazeProc = Get-Process "glazewm" -ErrorAction SilentlyContinue
    $glazeRunning = ($null -ne $glazeProc)
    $zebarProc = Get-Process "zebar" -ErrorAction SilentlyContinue
    $zebarRunning = ($null -ne $zebarProc)

    # 5. Runtimes detection
    $runtimesData = [System.Collections.Generic.List[object]]::new()
    $runtimesToCheck = @(
        @{ Name = "Node.js"; Cmd = "node"; Args = "--version" },
        @{ Name = "Python";  Cmd = "python"; Args = "--version" },
        @{ Name = "Rust";    Cmd = "rustc"; Args = "--version" },
        @{ Name = ".NET";    Cmd = "dotnet"; Args = "--version" },
        @{ Name = "Git";     Cmd = "git"; Args = "--version" },
        @{ Name = "Starship"; Cmd = "starship"; Args = "--version" }
    )
    foreach ($rt in $runtimesToCheck) {
        $found = Get-Command $rt.Cmd -ErrorAction SilentlyContinue
        $ver = "Not installed"
        $status = "missing"
        if ($found) {
            try {
                $rawVer = & $rt.Cmd $rt.Args 2>$null | Out-String
                $ver = ($rawVer -split "`r?`n")[0].Trim()
                $status = "installed"
            } catch {
                $ver = "Detected"
                $status = "installed"
            }
        }
        $runtimesData.Add([PSCustomObject]@{
            Name    = $rt.Name
            Version = $ver
            Status  = $status
        })
    }

    # Generate checks HTML table rows
    $checksHtml = [System.Text.StringBuilder]::new()
    foreach ($c in $checks) {
        $badgeClass = switch ($c.Status) {
            "OK"   { "badge-ok" }
            "WARN" { "badge-warn" }
            "FAIL" { "badge-fail" }
            default { "badge-info" }
        }
        $recHtml = if ($c.Recommendation) { "<div class='text-muted small' style='margin-top:4px;'>Recommendation: $($c.Recommendation)</div>" } else { "" }
        [void]$checksHtml.AppendLine(@"
        <tr>
            <td><span class='badge $badgeClass'>$($c.Status)</span></td>
            <td><strong>$($c.Category)</strong></td>
            <td><strong>$($c.Name)</strong></td>
            <td>$($c.Message)$recHtml</td>
        </tr>
"@)
    }

    # Generate packages HTML list
    $pkgsHtml = [System.Text.StringBuilder]::new()
    $configuredPkgs = if ($config.Contains("packages") -and $config["packages"]) { @($config["packages"]) } else { @() }
    $allPkgs = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($p in $configuredPkgs) { [void]$allPkgs.Add($p) }
    foreach ($p in $installedPkgs) { [void]$allPkgs.Add($p) }

    foreach ($pkgId in $allPkgs) {
        $isInst = ($installedPkgs -contains $pkgId)
        $badge = if ($isInst) { "<span class='badge badge-ok'>TRACKED</span>" } else { "<span class='badge badge-info'>CONFIGURED</span>" }
        [void]$pkgsHtml.AppendLine(@"
        <div class='pkg-card'>
            <div class='pkg-info'>
                <div class='pkg-id'>$pkgId</div>
            </div>
            <div>$badge</div>
        </div>
"@)
    }

    # Generate Runtimes HTML
    $runtimesHtml = [System.Text.StringBuilder]::new()
    foreach ($r in $runtimesData) {
        $badgeClass = if ($r.Status -eq "installed") { "badge-ok" } else { "badge-warn" }
        [void]$runtimesHtml.AppendLine(@"
        <div class='metric-card'>
            <div class='metric-header'>
                <span class='metric-title'>$($r.Name)</span>
                <span class='badge $badgeClass'>$($r.Status.ToUpper())</span>
            </div>
            <div class='metric-value'>$($r.Version)</div>
        </div>
"@)
    }

    # Generate Modules Progress HTML
    $modulesHtml = [System.Text.StringBuilder]::new()
    $knownModules = @("packages", "fonts", "envvars", "git", "shell", "editor", "runtimes", "databases", "keybindings", "glazewm", "zebar", "dotfiles")
    foreach ($m in $knownModules) {
        $isDone = ($completedModules -contains $m)
        $badgeClass = if ($isDone) { "badge-ok" } else { "badge-info" }
        $statusText = if ($isDone) { "PROVISIONED" } else { "PENDING" }
        [void]$modulesHtml.AppendLine(@"
        <div class='mod-item'>
            <span class='mod-name'>$m</span>
            <span class='badge $badgeClass'>$statusText</span>
        </div>
"@)
    }

    # Overall Health Status Title
    $systemStatusBadge = if ($failCount -gt 0) {
        "<span class='badge badge-fail' style='font-size:14px;padding:6px 14px;'>ATTENTION REQUIRED</span>"
    } elseif ($warnCount -gt 0) {
        "<span class='badge badge-warn' style='font-size:14px;padding:6px 14px;'>HEALTHY (NOTICES)</span>"
    } else {
        "<span class='badge badge-ok' style='font-size:14px;padding:6px 14px;'>OPTIMAL</span>"
    }

    $timestampNow = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    # Complete Self-Contained HTML Document
    $htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>devbox-win :: Workstation Dashboard</title>
    <style>
        :root {
            --bg-base: #0b0f17;
            --bg-surface: #131b2a;
            --bg-card: #1a2336;
            --bg-card-hover: #212c44;
            --border: #26334d;
            --border-subtle: #1c273c;
            --text-primary: #f8fafc;
            --text-secondary: #94a3b8;
            --text-muted: #64748b;
            --accent-primary: #38bdf8;
            --accent-primary-hover: #0ea5e9;
            --status-ok: #34d399;
            --status-ok-bg: rgba(52, 211, 153, 0.12);
            --status-warn: #fbbf24;
            --status-warn-bg: rgba(251, 191, 36, 0.12);
            --status-fail: #f87171;
            --status-fail-bg: rgba(248, 113, 113, 0.12);
            --status-info: #38bdf8;
            --status-info-bg: rgba(56, 189, 248, 0.12);
            --font-stack: Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            --font-mono: "Cascadia Code", "JetBrains Mono", Consolas, monospace;
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            background-color: var(--bg-base);
            color: var(--text-primary);
            font-family: var(--font-stack);
            font-size: 14px;
            line-height: 1.5;
            -webkit-font-smoothing: antialiased;
        }

        .layout {
            display: flex;
            min-height: 100vh;
        }

        .sidebar {
            width: 260px;
            background-color: var(--bg-surface);
            border-right: 1px solid var(--border);
            padding: 24px 16px;
            display: flex;
            flex-direction: column;
            gap: 24px;
        }

        .brand {
            display: flex;
            align-items: center;
            gap: 12px;
            padding-bottom: 16px;
            border-bottom: 1px solid var(--border-subtle);
        }

        .brand-icon {
            width: 36px;
            height: 36px;
            background: linear-gradient(135deg, #0284c7, #38bdf8);
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #fff;
        }

        .brand-title {
            font-size: 16px;
            font-weight: 700;
            letter-spacing: -0.02em;
            color: var(--text-primary);
        }

        .brand-sub {
            font-size: 11px;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }

        .nav-list {
            list-style: none;
            display: flex;
            flex-direction: column;
            gap: 4px;
        }

        .nav-item {
            padding: 10px 14px;
            border-radius: 6px;
            color: var(--text-secondary);
            cursor: pointer;
            display: flex;
            align-items: center;
            gap: 12px;
            font-weight: 500;
            transition: all 0.15s ease;
        }

        .nav-item:hover {
            background-color: var(--bg-card);
            color: var(--text-primary);
        }

        .nav-item.active {
            background-color: var(--bg-card);
            color: var(--accent-primary);
            border-left: 3px solid var(--accent-primary);
        }

        .sidebar-footer {
            margin-top: auto;
            padding-top: 16px;
            border-top: 1px solid var(--border-subtle);
            font-size: 12px;
            color: var(--text-muted);
        }

        .main-content {
            flex: 1;
            padding: 32px;
            overflow-y: auto;
        }

        .header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-bottom: 32px;
            padding-bottom: 24px;
            border-bottom: 1px solid var(--border);
        }

        .header-title {
            font-size: 24px;
            font-weight: 700;
            letter-spacing: -0.03em;
            margin-bottom: 4px;
        }

        .header-desc {
            color: var(--text-secondary);
            font-size: 13px;
        }

        .stat-grid {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 16px;
            margin-bottom: 32px;
        }

        .stat-card {
            background-color: var(--bg-surface);
            border: 1px solid var(--border);
            border-radius: 10px;
            padding: 20px;
            display: flex;
            flex-direction: column;
            gap: 8px;
        }

        .stat-label {
            font-size: 12px;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 0.05em;
            font-weight: 600;
        }

        .stat-val {
            font-size: 28px;
            font-weight: 700;
            font-family: var(--font-mono);
            letter-spacing: -0.03em;
        }

        .stat-sub {
            font-size: 12px;
            color: var(--text-secondary);
        }

        .section-title {
            font-size: 16px;
            font-weight: 600;
            letter-spacing: -0.02em;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .card {
            background-color: var(--bg-surface);
            border: 1px solid var(--border);
            border-radius: 10px;
            padding: 24px;
            margin-bottom: 32px;
        }

        .grid-2 {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 24px;
        }

        .badge {
            display: inline-flex;
            align-items: center;
            padding: 3px 8px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: 600;
            letter-spacing: 0.04em;
            text-transform: uppercase;
            font-family: var(--font-mono);
        }

        .badge-ok { background: var(--status-ok-bg); color: var(--status-ok); border: 1px solid rgba(52, 211, 153, 0.25); }
        .badge-warn { background: var(--status-warn-bg); color: var(--status-warn); border: 1px solid rgba(251, 191, 36, 0.25); }
        .badge-fail { background: var(--status-fail-bg); color: var(--status-fail); border: 1px solid rgba(248, 113, 113, 0.25); }
        .badge-info { background: var(--status-info-bg); color: var(--status-info); border: 1px solid rgba(56, 189, 248, 0.25); }

        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
        }

        th {
            text-align: left;
            padding: 12px 14px;
            color: var(--text-muted);
            border-bottom: 1px solid var(--border);
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }

        td {
            padding: 12px 14px;
            border-bottom: 1px solid var(--border-subtle);
            color: var(--text-secondary);
        }

        tr:hover td {
            background-color: rgba(255, 255, 255, 0.02);
            color: var(--text-primary);
        }

        .cmd-box {
            background-color: var(--bg-base);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 16px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 12px;
            font-family: var(--font-mono);
            font-size: 12px;
        }

        .cmd-code {
            color: var(--accent-primary);
            overflow-x: auto;
        }

        .btn-copy {
            background-color: var(--bg-card);
            border: 1px solid var(--border);
            color: var(--text-primary);
            padding: 6px 12px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 12px;
            font-weight: 500;
            display: flex;
            align-items: center;
            gap: 6px;
            transition: all 0.15s ease;
        }

        .btn-copy:hover {
            background-color: var(--accent-primary);
            color: #000;
            border-color: var(--accent-primary);
        }

        .pkg-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
            gap: 12px;
        }

        .pkg-card {
            background-color: var(--bg-card);
            border: 1px solid var(--border-subtle);
            border-radius: 6px;
            padding: 12px 14px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .pkg-id {
            font-family: var(--font-mono);
            font-size: 12px;
            color: var(--text-primary);
            font-weight: 500;
        }

        .mod-list {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
            gap: 8px;
        }

        .mod-item {
            background-color: var(--bg-card);
            border: 1px solid var(--border-subtle);
            border-radius: 6px;
            padding: 10px 14px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .mod-name {
            font-weight: 500;
            text-transform: capitalize;
            color: var(--text-primary);
        }

        .metric-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
            gap: 16px;
        }

        .metric-card {
            background-color: var(--bg-card);
            border: 1px solid var(--border-subtle);
            border-radius: 8px;
            padding: 16px;
        }

        .metric-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 8px;
        }

        .metric-title {
            font-size: 13px;
            font-weight: 600;
            color: var(--text-secondary);
        }

        .metric-value {
            font-family: var(--font-mono);
            font-size: 14px;
            color: var(--text-primary);
            font-weight: 600;
        }

        .toast {
            position: fixed;
            bottom: 24px;
            right: 24px;
            background-color: var(--accent-primary);
            color: #0b0f17;
            padding: 10px 18px;
            border-radius: 6px;
            font-weight: 600;
            font-size: 13px;
            opacity: 0;
            transform: translateY(10px);
            transition: all 0.2s ease;
            pointer-events: none;
            box-shadow: 0 4px 12px rgba(0,0,0,0.4);
        }

        .toast.show {
            opacity: 1;
            transform: translateY(0);
        }

        .tab-panel {
            display: none;
        }

        .tab-panel.active {
            display: block;
        }

        .icon {
            width: 16px;
            height: 16px;
            display: inline-block;
            vertical-align: middle;
            stroke-width: 2;
            stroke: currentColor;
            fill: none;
            stroke-linecap: round;
            stroke-linejoin: round;
        }
    </style>
</head>
<body>
    <div class="layout">
        <!-- Sidebar Navigation -->
        <aside class="sidebar">
            <div class="brand">
                <div class="brand-icon">
                    <svg class="icon" style="width:20px;height:20px;" viewBox="0 0 24 24"><polyline points="4 17 10 11 4 5"></polyline><line x1="12" y1="19" x2="20" y2="19"></line></svg>
                </div>
                <div>
                    <div class="brand-title">devbox-win</div>
                    <div class="brand-sub">Native Windows 11</div>
                </div>
            </div>

            <ul class="nav-list">
                <li class="nav-item active" onclick="switchTab('tab-overview')">
                    <svg class="icon" viewBox="0 0 24 24"><rect x="3" y="3" width="7" height="7"></rect><rect x="14" y="3" width="7" height="7"></rect><rect x="14" y="14" width="7" height="7"></rect><rect x="3" y="14" width="7" height="7"></rect></svg>
                    Overview
                </li>
                <li class="nav-item" onclick="switchTab('tab-doctor')">
                    <svg class="icon" viewBox="0 0 24 24"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>
                    Doctor Diagnostics
                </li>
                <li class="nav-item" onclick="switchTab('tab-packages')">
                    <svg class="icon" viewBox="0 0 24 24"><line x1="16.5" y1="9.4" x2="7.5" y2="4.21"></line><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path><polyline points="3.27 6.96 12 12.01 20.73 6.96"></polyline><line x1="12" y1="22.08" x2="12" y2="12"></line></svg>
                    Packages & Tools
                </li>
                <li class="nav-item" onclick="switchTab('tab-tiling')">
                    <svg class="icon" viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect><line x1="3" y1="9" x2="21" y2="9"></line><line x1="9" y1="21" x2="9" y2="9"></line></svg>
                    Tiling WM & Shell
                </li>
                <li class="nav-item" onclick="switchTab('tab-actions')">
                    <svg class="icon" viewBox="0 0 24 24"><polyline points="4 17 10 11 4 5"></polyline><line x1="12" y1="19" x2="20" y2="19"></line></svg>
                    CLI Actions
                </li>
            </ul>

            <div class="sidebar-footer">
                <div>Host: <strong>$($env:COMPUTERNAME)</strong></div>
                <div>User: <strong>$userName</strong></div>
                <div style="margin-top:6px;font-size:11px;">Updated: $timestampNow</div>
            </div>
        </aside>

        <!-- Main Workspace -->
        <main class="main-content">
            <!-- Header -->
            <div class="header">
                <div>
                    <h1 class="header-title">Workstation Health & Ecosystem</h1>
                    <div class="header-desc">Active Preset: <strong>$activePreset</strong> | Configuration: <strong>$configFile</strong></div>
                </div>
                <div>$systemStatusBadge</div>
            </div>

            <!-- Tab: Overview -->
            <div id="tab-overview" class="tab-panel active">
                <div class="stat-grid">
                    <div class="stat-card">
                        <span class="stat-label">Health Checks</span>
                        <span class="stat-val" style="color:var(--status-ok);">$passCount / $totalChecks</span>
                        <span class="stat-sub">$failCount Critical | $warnCount Notices</span>
                    </div>
                    <div class="stat-card">
                        <span class="stat-label">Installed Packages</span>
                        <span class="stat-val" style="color:var(--accent-primary);">$installedCount</span>
                        <span class="stat-sub">Tracked in Manifest</span>
                    </div>
                    <div class="stat-card">
                        <span class="stat-label">Active Dotfiles</span>
                        <span class="stat-val" style="color:var(--status-ok);">$symlinksCount</span>
                        <span class="stat-sub">Symlinked to System</span>
                    </div>
                    <div class="stat-card">
                        <span class="stat-label">GlazeWM Status</span>
                        <span class="stat-val" style="color:$(if ($glazeRunning) { 'var(--status-ok)' } else { 'var(--text-muted)' });">$(if ($glazeRunning) { 'ACTIVE' } else { 'IDLE' })</span>
                        <span class="stat-sub">Zebar: $(if ($zebarRunning) { 'Running' } else { 'Stopped' })</span>
                    </div>
                </div>

                <div class="card">
                    <div class="section-title">
                        <svg class="icon" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>
                        Language Runtimes & Core Toolchain
                    </div>
                    <div class="metric-grid">
                        $($runtimesHtml.ToString())
                    </div>
                </div>

                <div class="card">
                    <div class="section-title">
                        <svg class="icon" viewBox="0 0 24 24"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"></path></svg>
                        Provisioning Pipeline Status
                    </div>
                    <div class="mod-list">
                        $($modulesHtml.ToString())
                    </div>
                </div>
            </div>

            <!-- Tab: Doctor Diagnostics -->
            <div id="tab-doctor" class="tab-panel">
                <div class="card">
                    <div class="section-title">
                        <svg class="icon" viewBox="0 0 24 24"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>
                        Detailed Machine Diagnostics Audit
                    </div>
                    <table>
                        <thead>
                            <tr>
                                <th style="width:100px;">Status</th>
                                <th style="width:140px;">Category</th>
                                <th style="width:200px;">Check Name</th>
                                <th>Diagnostic Result & Details</th>
                            </tr>
                        </thead>
                        <tbody>
                            $($checksHtml.ToString())
                        </tbody>
                    </table>
                </div>
            </div>

            <!-- Tab: Packages -->
            <div id="tab-packages" class="tab-panel">
                <div class="card">
                    <div class="section-title">
                        <svg class="icon" viewBox="0 0 24 24"><line x1="16.5" y1="9.4" x2="7.5" y2="4.21"></line><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path><polyline points="3.27 6.96 12 12.01 20.73 6.96"></polyline><line x1="12" y1="22.08" x2="12" y2="12"></line></svg>
                        Winget Package Inventory & Catalog
                    </div>
                    <div class="pkg-grid">
                        $($pkgsHtml.ToString())
                    </div>
                </div>
            </div>

            <!-- Tab: Tiling WM & Shell -->
            <div id="tab-tiling" class="tab-panel">
                <div class="grid-2">
                    <div class="card">
                        <div class="section-title">
                            <svg class="icon" viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect><line x1="3" y1="9" x2="21" y2="9"></line><line x1="9" y1="21" x2="9" y2="9"></line></svg>
                            GlazeWM Tiling Window Manager
                        </div>
                        <p style="color:var(--text-secondary);margin-bottom:16px;">i3/bspwm-inspired dynamic tiling window manager for native Windows 11.</p>
                        <div style="display:flex;justify-content:space-between;padding:12px;background:var(--bg-card);border-radius:6px;margin-bottom:8px;">
                            <span>Process Status</span>
                            <span class="badge $(if ($glazeRunning) { 'badge-ok' } else { 'badge-warn' })">$(if ($glazeRunning) { 'RUNNING' } else { 'STOPPED' })</span>
                        </div>
                        <div style="display:flex;justify-content:space-between;padding:12px;background:var(--bg-card);border-radius:6px;">
                            <span>Config Path</span>
                            <span style="font-family:var(--font-mono);font-size:12px;">dotfiles/glazewm/config.yaml</span>
                        </div>
                    </div>

                    <div class="card">
                        <div class="section-title">
                            <svg class="icon" viewBox="0 0 24 24"><line x1="4" y1="21" x2="4" y2="14"></line><line x1="4" y1="10" x2="4" y2="3"></line><line x1="12" y1="21" x2="12" y2="12"></line><line x1="12" y1="8" x2="12" y2="3"></line><line x1="20" y1="21" x2="20" y2="16"></line><line x1="20" y1="12" x2="20" y2="3"></line><line x1="1" y1="14" x2="7" y2="14"></line><line x1="9" y1="8" x2="15" y2="8"></line><line x1="17" y1="16" x2="23" y2="16"></line></svg>
                            Zebar Status Bar
                        </div>
                        <p style="color:var(--text-secondary);margin-bottom:16px;">Polybar-style customizable status bar companion for GlazeWM.</p>
                        <div style="display:flex;justify-content:space-between;padding:12px;background:var(--bg-card);border-radius:6px;margin-bottom:8px;">
                            <span>Process Status</span>
                            <span class="badge $(if ($zebarRunning) { 'badge-ok' } else { 'badge-warn' })">$(if ($zebarRunning) { 'RUNNING' } else { 'STOPPED' })</span>
                        </div>
                        <div style="display:flex;justify-content:space-between;padding:12px;background:var(--bg-card);border-radius:6px;">
                            <span>Config Path</span>
                            <span style="font-family:var(--font-mono);font-size:12px;">dotfiles/zebar/config.yaml</span>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Tab: Actions -->
            <div id="tab-actions" class="tab-panel">
                <div class="card">
                    <div class="section-title">
                        <svg class="icon" viewBox="0 0 24 24"><polyline points="4 17 10 11 4 5"></polyline><line x1="12" y1="19" x2="20" y2="19"></line></svg>
                        One-Click Copyable CLI Operations
                    </div>
                    <p style="color:var(--text-secondary);margin-bottom:20px;">Click copy to grab the exact PowerShell 7+ command line string to run in your terminal.</p>

                    <div class="cmd-box">
                        <div class="cmd-code">pwsh -NoProfile -File core/engine.ps1 -Doctor</div>
                        <button class="btn-copy" onclick="copyCmd('pwsh -NoProfile -File core/engine.ps1 -Doctor')">Copy</button>
                    </div>

                    <div class="cmd-box">
                        <div class="cmd-code">pwsh -NoProfile -File core/engine.ps1 -Sync</div>
                        <button class="btn-copy" onclick="copyCmd('pwsh -NoProfile -File core/engine.ps1 -Sync')">Copy</button>
                    </div>

                    <div class="cmd-box">
                        <div class="cmd-code">pwsh -NoProfile -File core/engine.ps1 -Backup</div>
                        <button class="btn-copy" onclick="copyCmd('pwsh -NoProfile -File core/engine.ps1 -Backup')">Copy</button>
                    </div>

                    <div class="cmd-box">
                        <div class="cmd-code">pwsh -NoProfile -File core/engine.ps1 -Marketplace</div>
                        <button class="btn-copy" onclick="copyCmd('pwsh -NoProfile -File core/engine.ps1 -Marketplace')">Copy</button>
                    </div>

                    <div class="cmd-box">
                        <div class="cmd-code">pwsh -NoProfile -File core/engine.ps1 -DryRun</div>
                        <button class="btn-copy" onclick="copyCmd('pwsh -NoProfile -File core/engine.ps1 -DryRun')">Copy</button>
                    </div>

                    <div class="cmd-box">
                        <div class="cmd-code">pwsh -NoProfile -File core/engine.ps1</div>
                        <button class="btn-copy" onclick="copyCmd('pwsh -NoProfile -File core/engine.ps1')">Copy</button>
                    </div>
                </div>
            </div>
        </main>
    </div>

    <!-- Notification Toast -->
    <div id="toast" class="toast">Command copied to clipboard</div>

    <script>
        function switchTab(tabId) {
            document.querySelectorAll('.tab-panel').forEach(el => el.classList.remove('active'));
            document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));
            const target = document.getElementById(tabId);
            if (target) { target.classList.add('active'); }
            const nav = Array.from(document.querySelectorAll('.nav-item')).find(el => el.getAttribute('onclick').includes(tabId));
            if (nav) { nav.classList.add('active'); }
        }

        function copyCmd(text) {
            navigator.clipboard.writeText(text).then(() => {
                showToast('Copied to clipboard: ' + text);
            }).catch(() => {
                showToast('Failed to copy');
            });
        }

        function showToast(msg) {
            const toast = document.getElementById('toast');
            toast.textContent = msg;
            toast.classList.add('show');
            setTimeout(() => { toast.classList.remove('show'); }, 2500);
        }
    </script>
</body>
</html>
"@

    Set-Content -Path $DestinationPath -Value $htmlContent -Encoding utf8
    return $DestinationPath
}

function Show-DevboxDashboard {
    param(
        [string]$OutputPath = "",
        [switch]$NoLaunch,
        [string]$RepoRoot = ""
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
    }

    Write-DevboxBanner -SubTitle "Visual Dashboard Companion"

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = Join-Path $env:TEMP "devbox_dashboard.html"
    }

    $genPath = New-DevboxDashboardHtml -RepoRoot $RepoRoot -DestinationPath $OutputPath
    Write-DevboxOk "Dashboard generated successfully at: $genPath"

    if ($NoLaunch) {
        Write-DevboxInfo "Launch skipped per -NoLaunch flag."
        return [PSCustomObject]@{ Status = "OK"; Path = $genPath }
    }

    $edgePath = Get-EdgeExecutablePath
    if ($edgePath) {
        Write-DevboxInfo "Launching dashboard in Microsoft Edge app mode..."
        Start-Process -FilePath $edgePath -ArgumentList "--app=file:///$genPath" -ErrorAction SilentlyContinue
        Write-DevboxOk "Launched via Microsoft Edge app window."
    } else {
        Write-DevboxInfo "Opening dashboard in default browser..."
        Start-Process -FilePath $genPath -ErrorAction SilentlyContinue
    }

    return [PSCustomObject]@{ Status = "OK"; Path = $genPath }
}

if ($MyInvocation.InvocationName -ne '.') {
    $res = Show-DevboxDashboard -OutputPath $OutputPath -NoLaunch:$NoLaunch -RepoRoot $RepoRoot
    if ($res.Status -eq "FAIL") { exit 1 } else { exit 0 }
}
