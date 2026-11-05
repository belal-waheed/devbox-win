---
name: obsidian-vault
description: Standards and architecture for the Hola 3-Vault Monorepo (dev/, projects/, life/), flat 8-pillar taxonomy, vault-local assets/ isolation, Markdown note specifications, Obsidian Bases (.base), and JSON Canvas (.canvas). Use when creating or modifying notes, databases, templates, or visual canvas boards in Obsidian.
---

# Obsidian Vault Architecture, Bases & Canvas Guide

Comprehensive guide for managing markdown notes, databases, and visual canvas graphs inside the Hola 3-Vault Monorepo (`~/Documents/Vault`).

---

## 1. 3-Vault Monorepo Architecture & Scope Matrix

The monorepo is decoupled into three independent Obsidian vaults, each configured with its own isolated `.obsidian/` environment:

```
~/Documents/Vault/ (Monorepo Root & Git Repository)
│
├── dev/                     [Knowledge Base & University Reference]
│   ├── assets/              (Vault-isolated images & technical diagrams)
│   ├── _templates/          (Local templates: concept-spec.md, _folder-hub.md)
│   ├── _dev.md              (Master knowledge hub with Dataview aggregations)
│   └── 1-backend/ .. 8-tools/ (Flat 8-pillar taxonomy; max folder depth = 1)
│
├── projects/                [Engineering Control Room & Architecture Hub]
│   ├── assets/              (Architecture diagrams & system design exports)
│   ├── _templates/          (Local templates: project-hub.md, adr.md, _folder-hub.md)
│   ├── _projects.md         (Master project registry & active index)
│   └── <project-slug>/      (Autonomous project directories: _<project>.md, _log.md, specs/)
│
└── life/                    [Personal Sanctuary]
    ├── assets/              (Personal reference documents, receipts, maps)
    ├── _life.md             (Personal hub)
    └── goals/, health/, reading/, references/
```

### Responsibility & Domain Invariants

| Vault | Domain Boundary | Core Stack & Methodologies | Master Hub |
| :--- | :--- | :--- | :--- |
| **`dev/`** | Reusable computer science, technical pillars, university coursework. | 8 Pillars: Backend, Frontend, Database, Architecture, Software Design, Testing, University (Sinai Semester 7), Tools. | [`_dev.md`](file:///D:/dev/obsidian/hola/dev/_dev.md) |
| **`projects/`** | Active engineering codebases, system designs, living specs, ADRs, execution logs. | 14 Active Projects: Velos, devbox-win, SafeSwim, Portfolio, O2om, Markbel, CEMA, Tivaq, TickTick, Zebar, etc. | [`_projects.md`](file:///D:/dev/obsidian/hola/projects/_projects.md) |
| **`life/`** | Private life routines, wellness, curated reading, personal credentials. | Strictly user-managed. The AI agent never touches this directory without explicit user instruction. | [`_life.md`](file:///D:/dev/obsidian/hola/life/_life.md) |

> [!IMPORTANT] Permanent Elimination of `Today.md`
> `inbox/Today.md`, `sprints/`, and `finance/` have been permanently decommissioned.
> - **Task & Habit Source of Truth:** Managed strictly in **TickTick** via CLI (`ticktick`).
> - **Technical Accomplishment Logs:** Co-located directly under `projects/<project>/_log.md` (or `dev/<pillar>/_log.md`).
> - **Never** re-create, search for, or write to `Today.md`.

---

## 2. Note Specifications & Standard Anatomy

### A. Technical Concept Note Specification (`dev/<pillar>/<note>.md`)
All new engineering notes in `dev/` follow the standardized 3-part specification:
```markdown
---
type: tech-doc
topic: [backend | frontend | database | architecture | software-design | testing | tools]
tags:
  - dev
  - [concept-tag]
status: active
---

# [Concept Title]

> [!NAV] Navigation
> [[_dev|Dev Master Hub]] | **Pillar:** [[<pillar>/_<pillar>|<Pillar> Hub]]

---

## 1. Core Invariants & Mental Models
- Fundamental axioms, mathematical properties, and architectural trade-offs.
- Visual state machines or sequence flows using Mermaid diagrams.

## 2. Production Patterns & Implementation
- Idiomatic, copy-pasteable production implementations (C#, TypeScript, SQL, Rust).
- Defensive programming invariants, boundary validation, and error handling.

## 3. Pitfalls & Anti-Patterns
- Performance bottlenecks (N+1 queries, memory leaks, un-indexed scans).
- Concurrency race conditions, fragile abstractions, and anti-patterns.
```

### B. Project Hub Note (`projects/<project>/_<project>.md`)
```markdown
---
type: project-hub
status: [active | production | maintenance | prototype]
priority: [high | medium | low]
tags:
  - project
---

# [Project Name] Hub

> [!NAV] Navigation
> [[_projects|Projects Master Hub]] | **Technical Log:** [[projects/<project>/_log|<Project> Log]]

## 1. Executive Vision & Architecture Overview
High-level architectural topology, technology stack, and business domain invariants.

## 2. Living Documentation & Architecture Records
- **System Overview:** `docs/overview.md`
- **Architecture & System Design:** `docs/architecture.md`
- **ADRs:** `docs/adr/`

## 3. Active Deliverables & Milestones
- [ ] Deliverable 1
```

### C. Co-Located Project Log Note (`projects/<project>/_log.md`)
```markdown
---
type: project-log
tags:
  - project
  - log
---

# [Project Name] — Engineering Execution Log

> [!NAV] Navigation
> [[_projects|Projects Master Hub]] | **Parent Hub:** [[projects/<project>/_<project>|<Project> Hub]]

---

### [Feature or Workstream Title] (YYYY-MM-DD)
- **Technical Summary:** Concise description of what was implemented, refactored, or fixed.
- **Architectural Decisions:** State machine choices, data structures, or patterns selected.
- **Verification Evidence:** Test results (e.g. 156 passing tests), benchmarks, build outputs.
- **Commits:** Conventional commit hash references.
```

---

## 3. Asset & Image Isolation Rules

1. **Vault-Local Assets:** Each vault owns its isolated `assets/` directory (`dev/assets/`, `projects/assets/`, `life/assets/`).
2. **Settings Invariant:** Every vault sets `"attachmentFolderPath": "assets"` in `.obsidian/app.json`.
3. **Embed Syntax:** Always use standard Obsidian wikilinks: `![[diagram-name.png]]`.
4. **Never** link to external filesystem paths outside the vault boundary.

---

## 4. Cross-Vault Linking Protocols

Because each vault is an isolated indexing process in Obsidian:
1. **Interactive Navigation across Vaults:** Use native Obsidian URIs:
   ```markdown
   * Architectural pattern derived from [System Scalability](obsidian://open?vault=dev&file=4-architecture%2Fsystem-scalability).
   ```
2. **Local Vault Master Navigation:** Never link sub-vault notes to the root `Dashboard.md`. Always link to the local master hub:
   - Inside `dev`: `[[_dev|Dev Master Hub]]`
   - Inside `projects`: `[[_projects|Projects Master Hub]]`
   - Inside `life`: `[[_life|Life Master Hub]]`

---

## 5. Obsidian Bases (`.base`) Integration

A `.base` file defines structured tabular and board views over markdown frontmatter:
```yaml
filters:
  and:
    - file.folder == "projects"
    - file.tags contains "#active"
views:
  - type: table
    name: "Active Projects"
    columns:
      - property: file.name
        label: "Project"
      - property: status
        label: "Status"
      - property: priority
        label: "Priority"
```

---

## 6. Obsidian JSON Canvas (`.canvas`) Generation

A `.canvas` file represents visual node graphs with collision-free coordinates:
```json
{
  "nodes": [
    {
      "id": "node_1",
      "type": "text",
      "text": "## API Gateway\n- Port: 8000",
      "x": 0,
      "y": 0,
      "width": 260,
      "height": 140,
      "color": "5"
    },
    {
      "id": "node_2",
      "type": "file",
      "file": "projects/auth/_auth.md",
      "x": 320,
      "y": 0,
      "width": 260,
      "height": 140,
      "color": "4"
    }
  ],
  "edges": [
    {
      "id": "edge_1",
      "fromNode": "node_1",
      "fromSide": "right",
      "toNode": "node_2",
      "toSide": "left",
      "label": "Routes to"
    }
  ]
}
```
- **Semantic Colors:** `1`: Red/Alert, `2`: Orange/Next, `3`: Yellow/Note, `4`: Green/Done, `5`: Blue/Component, `6`: Purple/System.

---

## 7. Negative Constraints & Guardrails

- **Zero Emojis:** Strictly prohibited across all notes, tags, headers, and logs.
- **Never Modify `.obsidian/` Directly:** Do not edit Obsidian caches or workspace state.
- **No Tag Spaces:** Use `#backend/api` or `#csharp-dotnet`, never spaces.
- **No Orphan Notes:** Every note must link back to its parent pillar hub (`[[1-backend/_backend|Backend Hub]]`) or project hub.
- **Monorepo Git Sync:** Git operations are handled via `hola-sync` CLI or automated Task Scheduler `HolaVaultSync`. Community plugin `obsidian-git` remains disabled on desktop to prevent boot freezes.
