---
name: powershell
description: Comprehensive conventions and production standards for PowerShell 7+ (pwsh) and Windows PowerShell 5.1 automation. Covers pipeline idioms, object stream manipulation, UTF-8 file I/O, WinRT toast notifications, Windows Task Scheduler, background daemons, and robust error handling. Use when crafting pwsh CLI one-liners, diagnosing shell syntax errors, building Windows automations, or executing administrative filesystem workflows.
---

# PowerShell 7+ (pwsh) Automation & Command Execution Guide

Production standards for PowerShell 7+ and Windows PowerShell 5.1 automation, CLI operations, and Windows integration.

---

## 1. Execution Directives & Shell Standards

- **Always include `-NoProfile`**:
  ```powershell
  pwsh -NoProfile -Command "..."
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "script.ps1"
  ```
- **Strict Error Handling**: Wrap in `try { ... } catch { ... }` and set `$ErrorActionPreference = "Stop"` for non-interactive automation:
  ```powershell
  $ErrorActionPreference = "Stop"
  try {
      Get-Item -LiteralPath $path -ErrorAction Stop
  } catch {
      Write-Error "Failed: $($_.Exception.Message)"
      exit 1
  }
  ```
- **The Runner Quoting / Expansion Trap**:
  - Double quotes in programmatic CLI runners eagerly expand `$_` and `$()`.
  - Use single quotes outer: `pwsh -NoProfile -Command 'Get-ChildItem | ForEach-Object { $_.Name }'`
  - Or backtick-escape variables when outer double quotes are needed: `Write-Output `$_.Name`
- **Safe UTF-8 Encoding**: Enforce UTF-8 without BOM for all file I/O and HTTP APIs:
  ```powershell
  Set-Content -Path $filePath -Value $content -Encoding utf8
  $utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
  Invoke-RestMethod -Uri $url -Method Post -Body $utf8Bytes -ContentType "text/plain; charset=utf-8"
  ```

---

## 2. Object Pipeline Idioms

PowerShell operates on .NET objects, not plain text streams:

```powershell
# Filtering & Selecting
Get-Service | Where-Object { $_.Status -eq 'Running' }
Get-Process | Select-Object -Property Id, ProcessName, WorkingSet64 -First 10

# Dynamic Calculated Properties
Get-ChildItem -File | Select-Object Name,
    @{ Name = 'SizeMB'; Expression = { [math]::Round($_.Length / 1MB, 2) } },
    @{ Name = 'Modified'; Expression = { $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm") } }

# Grouping and Aggregation
Get-ChildItem -File -Recurse | Group-Object Extension | Select-Object Name, Count,
    @{ Name = 'TotalMB'; Expression = { [math]::Round(($_.Group | Measure-Object Length -Sum).Sum / 1MB, 2) } } |
    Sort-Object TotalMB -Descending

# Parallel Processing (PowerShell 7+)
$items | ForEach-Object -Parallel {
    Process-Item -Target $_
} -ThrottleLimit 4
```

---

## 3. Windows WinRT Toast Notifications

Native interactive toast alerts without third-party dependencies:

```powershell
function Show-WindowsToast {
    param (
        [string]$Title,
        [string]$Message,
        [string]$ClickUrl = "obsidian://open?vault=hola&file=inbox/Today"
    )

    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

    $XmlMessage = [System.Security.SecurityElement]::Escape($Message) -replace '•', '&#x2022;'
    $XmlTitle   = [System.Security.SecurityElement]::Escape($Title)

    $template = @"
<toast activationType="protocol" launch="$ClickUrl">
    <visual>
        <binding template="ToastGeneric">
            <text>$XmlTitle</text>
            <text>$XmlMessage</text>
        </binding>
    </visual>
</toast>
"@
    try {
        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($template)
        $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Antigravity").Show($toast)
    } catch {
        Write-Warning "Toast notification failed: $($_.Exception.Message)"
    }
}
```

---

## 4. Background Daemons & Task Scheduler

```powershell
# Background process spawn with hidden window
Start-Process -FilePath "pwsh" -ArgumentList "-NoProfile -WindowStyle Hidden -File C:\scripts\daemon.ps1"

# Windows Task Scheduler registration
$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument '-NoProfile -NonInteractive -WindowStyle Hidden -File C:\scripts\task.ps1'
$trigger = New-ScheduledTaskTrigger -Daily -At 9am
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName 'AntigravityDailySync' -Action $action -Trigger $trigger -Settings $settings -Description 'Daily sync' -Force
```

---

## 5. Script Verification & Linting

Audit scripts for syntax, UTF-8 encoding, and `-NoProfile` compliance:
```powershell
pwsh -NoProfile -File scripts/test-profile-syntax.ps1 -Path ".\script.ps1"
```
See [scripts/test-profile-syntax.ps1](scripts/test-profile-syntax.ps1) for the AST parser and compliance auditor implementation.

---

## 6. Common Pitfalls & Negative Constraints

- Never invoke `pwsh` or `powershell` without the `-NoProfile` flag.
- Never execute destructive deletions (`rmdir /s /q`, `del /s /q`, `Remove-Item -Recurse -Force` on system or root directories).
- Avoid parsing command output with string regex when native PowerShell object properties are accessible (`Select-Object`, `Where-Object`).
- Never rely on default shell encoding; always explicitly specify `-Encoding utf8NoBOM` or `utf8`.
- Do not suppress critical errors using blanket `$ErrorActionPreference = 'SilentlyContinue'` without targeted try/catch handling.
