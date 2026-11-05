---
name: ntfy-push-notifications
description: Conventions and patterns for ntfy.sh and self-hosted ntfy push notification integration across Node.js, PowerShell, cURL, and GitHub Actions. Covers interactive action buttons, deep links, priority levels, markdown formatting, and mobile push automation. Use when sending alerts or mobile push notifications.
---

# ntfy Push Notifications Guide

Runbook for dispatching formatted mobile push notifications with interactive deep links via ntfy.sh.

## 1. Core Architecture & HTTP Headers

| Header | Example Value | Description |
| :--- | :--- | :--- |
| `Title` | `Goal Complete` | Notification title (clean ASCII without emoji clutter) |
| `Priority` | `high` | `min`, `low`, `default`, `high`, `urgent` (`high` triggers sound/vibration) |
| `Markdown` | `yes` | Enables markdown rendering in notification body |
| `Click` | `obsidian://open?vault=hola&file=inbox/Today` | URI opened when tapping notification body |
| `Actions` | `view, Review Today, obsidian://...; view, Dashboard, ...` | Interactive buttons placed on notification card |

---

## 2. Implementation Patterns

### PowerShell (`Invoke-RestMethod`)
```powershell
$NtfyUrl = "https://ntfy.sh/$NtfyTopic"
$Headers = @{
    "Title"     = "Sprint Sync Complete"
    "Priority"  = "high"
    "Markdown"  = "yes"
    "Click"     = "obsidian://open?vault=hola&file=inbox/Today"
    "Actions"   = "view, Review Today, obsidian://open?vault=hola&file=inbox/Today; view, Dashboard, obsidian://open?vault=hola&file=Dashboard"
}
$Utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($Message)
Invoke-RestMethod -Uri $NtfyUrl -Method Post -Body $Utf8Bytes -Headers $Headers -ContentType "text/markdown; charset=utf-8"
```

---

## 3. Verification & Testing

Validate notification delivery:
1. **Dry-Run Curl Test:**
   ```bash
   pwsh -NoProfile -Command "Invoke-RestMethod -Uri 'https://ntfy.sh/belal-hola-vault' -Method Post -Body 'Test Notification' -Headers @{ Title = 'Antigravity Test'; Priority = 'default' }"
   ```
2. **Action Button URL Verification:** Verify `obsidian://open?vault=...` links resolve to actual vault paths.
3. **UTF-8 Encoding Check:** Test Arabic/non-Latin strings to ensure zero mojibake or question mark corruptions.

---

## 4. Common Pitfalls & Negative Constraints

- **Never omit explicit UTF-8 encoding:** String payloads must be converted to UTF-8 bytes to prevent character corruption.
- **Never add emoji icons to Title headers:** Keep notification titles clean and professional.
- **Avoid unescaped commas in Actions header:** Separate multiple actions with semicolons (`;`).
