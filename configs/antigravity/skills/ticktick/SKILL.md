---
name: ticktick
description: "Interact with TickTick task management and habit tracker. Use when the user asks to view, add, complete tasks, inspect habits, or run weekly reviews."
---

# TickTick CLI & Automation Guide

Production standards and command reference for interacting with TickTick tasks, habit tracking, financial runway envelopes, and weekly reviews via the native PowerShell CLI utility.

---

## 1. Architecture & Execution Model

The TickTick integration operates through a local CLI engine backed by the official TickTick Open API v1.

- **Engine Script:** `~/.devbox/tools/ticktick/ticktick.ps1`
- **Global PATH Shims:** `D:\apps\ticktick.cmd` and `D:\apps\ticktick.ps1`
- **Authentication:** Windows User Environment Variable `TICKTICK_TOKEN` (Bearer authorization header).
- **Session Cache:** `$HOME\.ticktick_cache.json` stores 1-based indices and metadata from the most recent list operation for fast completion and deletion by index.
- **API Base URL:** `https://api.ticktick.com/open/v1`

```
User Prompt -> Antigravity Agent -> ticktick CLI (pwsh) -> TickTick Open API
                                         |
                                         v
                              $HOME\.ticktick_cache.json
```

---

## 2. Natural-Language Triggers & Intent Mapping

| User Intent | Command Pattern | Example Agent Execution |
| :--- | :--- | :--- |
| View weekly tasks / today agenda | `ticktick list [project]` | `pwsh -NoProfile -Command "ticktick list Week"` |
| View financial commitments / bills | `ticktick list Money` | `pwsh -NoProfile -Command "ticktick list Money"` |
| Check weekly food & coffee budget | `ticktick runway` | `pwsh -NoProfile -Command "ticktick runway"` |
| Create a new task with due date | `ticktick add <title> [options]` | `pwsh -NoProfile -Command "ticktick add 'Assignment 1' -Due tomorrow -Priority high"` |
| Add a task with checklist subtasks | `ticktick add <title> -Items ...` | `pwsh -NoProfile -Command "ticktick add 'Study Module' -Items 'Video 1','Video 2'"` |
| Mark task complete by index | `ticktick complete <index>` | `pwsh -NoProfile -Command "ticktick complete 1"` |
| Mark task complete by title | `ticktick complete <title>` | `pwsh -NoProfile -Command "ticktick complete 'Assignment 1'"` |
| Delete a task | `ticktick delete <index\|title>` | `pwsh -NoProfile -Command "ticktick delete 3"` |
| Inspect active habits | `ticktick habits` | `pwsh -NoProfile -Command "ticktick habits"` |
| Record daily habit check-in | `ticktick checkin <name\|id>` | `pwsh -NoProfile -Command "ticktick checkin Reading"` |
| Perform Sunday weekly review | `ticktick review` | `pwsh -NoProfile -Command "ticktick review"` |

---

## 3. Command Line Reference

### `ticktick list [project]`
Displays active tasks formatted as a tabular index view with priority badges and checklist items. Refreshes `$HOME\.ticktick_cache.json`.
- `[project]`: Target project name (defaults to `Week`). Supported names: `Week`, `Money`, `Templates`, `Asp.Net Core`.

### `ticktick add <title> [options]`
Creates a new task in the target project.
- `<title>`: Task headline string.
- `-Project, -p <name>`: Target project (default: `Week`).
- `-Due, -d <date>`: Due date string. Accepts `today`, `tomorrow`, or standard ISO date `YYYY-MM-DD`. Formatted as ISO-8601 UTC timestamp.
- `-Priority, -pr <val>`: Priority level. Accepts `0`/`none`, `1`/`low`, `3`/`med`, `5`/`high`.
- `-Items, -i <list>`: Checklist subtasks as comma-separated strings or array.

### `ticktick complete <index|title|id> [-Project <p>]`
Marks a task as completed via `POST /open/v1/project/{projectId}/task/{taskId}/complete`.
- Accepts a 1-based index from the last `list` command, a partial title, or a 24-character hexadecimal ID.

### `ticktick delete <index|title|id> [-Project <p>] [-Force]`
Permanently deletes a task via `DELETE /open/v1/project/{projectId}/task/{taskId}`.
- Enforces safety invariants: recurring bills cannot be deleted without `-Force`.

### `ticktick habits`
Retrieves registered habits via `GET /open/v1/habit` with goal and frequency.

### `ticktick checkin <habitName|id>`
Submits a habit check-in record for the current day (`stamp: YYYYMMDD`) via `POST /open/v1/habit/{id}/checkin`.

### `ticktick runway`
Retrieves and renders the living financial runway envelope task from the `Money` project, stripping escape artifacts for clean terminal display.

### `ticktick review`
Runs the weekly Sunday review macro:
1. Lists remaining active tasks in `Week`.
2. Summarizes completed tasks from recent API history.
3. Renders current runway envelope from `Money`.
4. Outputs the Sunday review checklist.

---

## 4. Project Mapping Registry

The CLI includes static lookup mappings and falls back to dynamic API discovery:

| Project Key | Project ID | Purpose |
| :--- | :--- | :--- |
| `Week` | `6ae48710e9aeba00000001f9` | Primary active weekly sprint commitments |
| `Money` | `6ae486f08f08415c2854014e` | Fixed bills, subscriptions, and living runway envelope |
| `Templates` | `6ae488508f083c2a9da91a7a` | Reusable task blueprints and checklists |
| `Asp.Net Core` | `6ae47b11e9aeba0000000059` | Academic / project development board |

---

## 5. Safety Invariants & Guardrails

1. **Recurring Bill Protection:** The `delete` verb contains an invariant guard preventing deletion of recurring financial commitments (`Rent`, `Internet`, `Electricity`, `Gym`, `Utilities`) unless the `-Force` flag is explicitly provided.
2. **Credential Isolation:** The API token is stored exclusively in the Windows User environment variable `TICKTICK_TOKEN`. Never hardcode, commit, or print the raw token.
3. **Zero Emojis:** Terminal output, status logs, badges, and documentation strictly use clean ASCII indicators (`[HIGH]`, `[MED]`, `[LOW]`, `[NONE]`, `[ ]`, `[x]`).
4. **PowerShell Non-Interactive Standard:** Always invoke the CLI with `-NoProfile` (`pwsh -NoProfile -Command "ticktick ..."`).
