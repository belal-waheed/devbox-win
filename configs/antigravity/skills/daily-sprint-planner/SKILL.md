---
name: daily-sprint-planner
description: Interactive workflows for daily planning via TickTick CLI, weekly sprint milestones, task execution tracking, and automatic documentation sync in Obsidian. Use when the user asks to plan their day or week, review tasks, log completed engineering work, or update vault documentation after a work session.
---

# Daily Task Execution, Sprint Milestones & Technical Documentation Sync Guide

Comprehensive runbook for daily task management via TickTick CLI, active sprint milestones, and living technical documentation synchronization across the Hola 3-Vault Monorepo (`~/Documents/Vault`).

---

## When to use this skill
Activate this skill whenever:
- The user asks to plan their day, start a morning kickoff, or review today's schedule/tasks.
- The user asks to plan their week, review active sprint deliverables, or track milestones.
- The user finishes a coding session, fixes a bug, completes a deployment, or finishes a technical task and needs documentation, tasks, and project hubs updated.
- The user asks for an end-of-day review, task rollover, or session wrap-up.

---

## 1. Architectural Source of Truth

```
+-------------------------------------------------------------------------+
|                  Task & Documentation Source of Truth                   |
+------------------------------------+------------------------------------+
| Tasks, Habits, & Daily Execution   | Living Technical Documentation     |
| (Managed strictly in TickTick)     | (Managed in Obsidian Monorepo)     |
+------------------------------------+------------------------------------+
| - Daily Frog & execution tasks     | - Project Hubs:                    |
| - Recurring bills & runway         |   projects/<project>/_<project>.md |
| - Habit check-ins                  | - Co-located Execution Logs:       |
| - Fast CLI: ticktick list/complete |   projects/<project>/_log.md       |
|                                    | - Dev Knowledge Hub: dev/_dev.md   |
+------------------------------------+------------------------------------+
```

> [!IMPORTANT] Decommissioning of `Today.md`
> `inbox/Today.md` and rolling daily markdown notes have been permanently deleted.
> - **Never** search for, create, or update `Today.md`.
> - **Task State:** Check off tasks in **TickTick** via CLI (`ticktick complete <index>`).
> - **Work Logs:** Record completed engineering work in the project's local log file: `projects/<project>/_log.md`.

---

## Mode 1: Daily Planning Kickoff (`plan day` / morning routine)

### Trigger phrases:
`"plan my day"`, `"let's plan today"`, `"morning kickoff"`, `"what's on my plate?"`, `"today's tasks"`

### Step-by-Step Procedure:
1. **Query Active Tasks via TickTick CLI**:
   ```powershell
   pwsh -NoProfile -Command "ticktick list"
   ```
2. **Review Top Priorities (The Frog)**:
   - Identify the user's top 3 priority actions for the day from the returned list.
   - If new tasks are needed, add them via CLI:
     ```powershell
     pwsh -NoProfile -Command "ticktick add 'Task Title' -Due today -Priority high"
     ```
3. **Inspect Habits & Financial Envelopes (Optional)**:
   - If requested, audit daily habit streaks:
     ```powershell
     pwsh -NoProfile -Command "ticktick habits"
     ```
   - If requested, check weekly budget runway:
     ```powershell
     pwsh -NoProfile -Command "ticktick runway"
     ```

---

## Mode 2: Weekly Milestone Review (`plan week` / weekly kickoff)

### Trigger phrases:
`"plan week"`, `"weekly sprint"`, `"new sprint"`, `"sprint kickoff"`, `"review this week"`

### Step-by-Step Procedure:
1. **Audit Active Project Milestones**:
   - Inspect active project hubs under [`~/Documents/Vault\projects/`](~/Documents/Vault/projects/) (e.g. `projects/velos/_velos.md`, `projects/devbox-win/_devbox-win.md`, `projects/portfolio/_portfolio.md`).
   - Identify active deliverables under `## Active Deliverables & Milestones`.
2. **Synchronize Deliverables into TickTick**:
   - Create week tasks with checklist items for multi-step deliverables:
     ```powershell
     pwsh -NoProfile -Command "ticktick add 'Feature Implementation' -Project Week -Items 'Unit tests','API route','Documentation'"
     ```
3. **Run Weekly Review**:
   - Execute the Sunday weekly review workflow:
     ```powershell
     pwsh -NoProfile -Command "ticktick review"
     ```

---

## Mode 3: Continuous Execution & Post-Work Reconciliation (The Iron Law)

### Trigger moments:
- The user completes a feature, bug fix, refactor, or architectural change.
- Explicit triggers: `"sync docs"`, `"log what we did"`, `"we finished [X]"`, `"update task plan"`.

### The 4-Step Mandatory Pipeline:

```
[Completed Work] 
       │
       ▼
[Step 1: Check Off Tasks in TickTick]   ──> ticktick complete <index>
       │
       ▼
[Step 2: Sync Project Hub]              ──> projects/<project>/_<project>.md
       │
       ▼
[Step 3: Co-locate Engineering Log]     ──> projects/<project>/_log.md
       │
       ▼
[Step 4: Git Presentation & Push]       ──> Conventional Commit + hola-sync
```

1. **Step 1: Task Check-Off (TickTick)**:
   - Query task index: `ticktick list`.
   - Mark completed: `ticktick complete <index>` (e.g., `ticktick complete 1`).
2. **Step 2: Project Hub Sync**:
   - Open [`projects/<project>/_<project>.md`](~/Documents/Vault/projects/).
   - Update project status, milestone checkboxes, and link any newly created architecture guides or ADRs.
3. **Step 3: Co-located Engineering Log**:
   - Append concise technical accomplishments directly under [`projects/<project>/_log.md`](~/Documents/Vault/projects/) (or `dev/<pillar>/_log.md` if study work):
     - Architectural decisions made and patterns implemented.
     - Key commands executed and verification evidence (e.g. test counts, benchmark numbers).
     - Diff summary and files modified.
4. **Step 4: Git Approval & Sync**:
   - Present Conventional Commit message in chat and await user approval.
   - After user approval, commit changes and execute:
     ```powershell
     pwsh -NoProfile -Command "hola-sync"
     ```

---

## Mode 4: End-of-Day Review & Wrap-Up (`end of day`)

### Trigger phrases:
`"end of day"`, `"evening review"`, `"wrap up today"`, `"finish day"`

### Step-by-Step Procedure:
1. **Audit Completed Tasks**:
   - Run `ticktick list` to check remaining open items.
   - Check off completed tasks or reschedule unfinished items to tomorrow:
     ```powershell
     pwsh -NoProfile -Command "ticktick complete <index>"
     ```
2. **Record Habit Check-ins**:
   - Mark completed daily habits:
     ```powershell
     pwsh -NoProfile -Command "ticktick checkin '<HabitName>'"
     ```
3. **Ensure Monorepo Sync**:
   - The scheduled task `HolaVaultSync` runs automatically at 20:00 (8:00 PM) daily.
   - For an immediate push, execute `hola-sync`.

---

## Negative Constraints & Invariants

- **Never create or reference `Today.md`:** Rolling daily markdown files are dead. All task tracking belongs in TickTick.
- **Zero Emojis:** Strictly prohibited in code, tasks, notes, logs, and commit messages.
- **Never perform unscoped file sweeps:** Modify notes only within the active project directory boundary (`projects/<project>/`).
- **Always verify before completion:** Unit test and audit changes before marking tasks complete in TickTick.
