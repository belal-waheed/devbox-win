---
name: wayfinder
description: Map out large, complex, or ambiguous software initiatives into structured architectural decision trees, unknown elimination, and sequential milestone roadmaps.
---

# Wayfinder: Architectural Decision Mapping & Unknown Elimination

Wayfinder is an upstream-aligned exploration protocol for navigating complex, ambiguous, or multi-session software initiatives. It decomposes fuzzy objectives into structured decision trees, isolates technical spikes, eliminates unknowns, and establishes a locked architectural roadmap before committing to production code.

```
[Greenfield / Ambiguity]
         │
         ▼
[1. Charting & Scoping] ──► Define Destination, Constraints, Non-Goals
         │
         ▼
[2. Living Map & ADFs]  ──► Enumerate Unknowns & Architectural Decision Forks
         │
         ▼
[3. Spike Probing]      ──► Isolated Time-Boxed Experiments (Scratch/Spike)
         │
         ▼
[4. Roadmap Convergence]──► Lock Decisions ──► Hand off to /to-spec or /grill-me
```

---

## 1. Core Operating Principles

1. **Decide Before Doing:** Wayfinding produces locked architectural decisions, validated facts, and sequenced roadmaps—never premature production code.
2. **Eliminate the Fog of War First:** Identify and prioritize high-risk unknowns (data persistence, concurrency models, external API limits, compliance boundaries) before writing application logic.
3. **Living Map as Single Source of Truth:** All progress, trade-offs, and locked decisions are continuously updated in a central Living Map file (`.scratch/wayfinder/map.md` or dedicated tracker issue).
4. **Isolated Spike Experiments:** Spikes test exactly one unknown at a time. Spike code is strictly quarantined in throwaway scratch directories and is never directly merged into production.
5. **Clear Exit Criteria:** Wayfinding ends when the Frontier queue is empty, the Fog of War is fully charted, and all Architectural Decision Forks (ADFs) are resolved.

---

## 2. The 4-Stage Wayfinder Protocol

### Stage 1: Charting & Scoping
- Define the absolute destination: the quantifiable end state of the initiative.
- Identify known project boundaries, runtime constraints, and legacy seams.
- Establish explicit **Out of Scope** non-goals to immediately prevent scope creep.
- Initialize the Living Map artifact at `.scratch/wayfinder/map.md`.

### Stage 2: Unknown Enumeration & Architectural Decision Forks (ADFs)
- Identify all points of architectural uncertainty and formalize them as Architectural Decision Forks (ADFs).
- Each ADF defines a structural choice where multiple viable paths exist.
- Score options against constraints: operational simplicity, latency, developer ergonomics, blast radius, and reversibility.
- Categorize decisions by reversibility:
  - **Two-Way Doors (Reversible):** Fast-track with reasonable defaults.
  - **One-Way Doors (Irreversible / High-Blast):** Require spike proof, data modeling, or adversarial review.

### Stage 3: Spike Experimentation & Boundary Probing
- When an unknown cannot be resolved by reasoning or documentation inspection, conduct an isolated technical spike.
- Follow the **Spike Isolation Rules**:
  - Execute within a scratch directory (e.g., `.scratch/spikes/<topic>/`) or an isolated throwaway branch.
  - Implement the thinnest possible vertical probe that answers the target hypothesis.
  - Benchmark performance, verify API contract compatibility, or test error boundaries.
  - Extract the validated finding, record it in the ADF, and discard the throwaway code.

### Stage 4: Roadmap Sequencing & Convergence
- Organize resolved decisions into a sequential Directed Acyclic Graph (DAG).
- Group execution into logical milestone phases.
- Lock all decisions into the Living Map.
- Transition the initiative directly to `/to-spec` for formal RFC authoring or `/grill-me` for adversarial plan validation.

---

## 3. The Living Map Standard

The Living Map is maintained at `.scratch/wayfinder/map.md` and follows this exact Markdown structure:

```markdown
# Initiative Living Map: [Initiative Name]

**Status:** Active | Ready for Spec | Blocked
**Last Updated:** YYYY-MM-DD
**Owner:** [Agent / Engineering Lead]

---

## 1. Destination
Clear, unambiguous statement of the target end-state and quantifiable success metrics.

## 2. Locked Decisions (Decisions So Far)
| ID | Decision | Chosen Alternative | Key Rationale | Date |
|---|---|---|---|---|
| ADF-01 | Storage Engine | PostgreSQL + pgvector | Existing infra, ACID guarantee, lower ops overhead | YYYY-MM-DD |
| ADF-02 | Auth Boundary | Session Cookies via Redis | Sub-millisecond revocation, zero JWT sprawl | YYYY-MM-DD |

## 3. Frontier (Active Decisions Under Review)
- [ ] **ADF-03: Real-Time Sync Strategy**
  - **Question:** Server-Sent Events vs WebSockets for dashboard state delivery?
  - **Dependencies:** Blocked by ADF-02.
  - **Status:** Spike underway in `.scratch/spikes/realtime-sse/`.
- [ ] **ADF-04: Background Job Processing**
  - **Question:** In-memory queue vs BullMQ / Redis stream?
  - **Dependencies:** None.

## 4. Fog of War (Unexplored Domains)
- Multi-tenant tenant data isolation model (schema-per-tenant vs row-level security).
- Data retention and cold-storage compliance pipeline.

## 5. Out of Scope (Explicit Non-Goals)
- Custom OAuth provider implementation (third-party federated identity used exclusively).
- Legacy database backward-compatibility adapters.
```

---

## 4. Architectural Decision Fork (ADF) Template

When analyzing a significant decision, append or link an ADF record using this schema:

```markdown
### ADF-[NN]: [Decision Title]

**Context & Problem Statement:**
What technical problem or architectural tension requires a decision? What are the hard constraints?

**Decision Candidates:**

#### Option A: [Name] (Recommended)
- **Mechanics:** How this option works.
- **Pros:** Measurable advantages.
- **Cons & Risks:** Trade-offs, operational burdens, limitations.
- **Blast Radius:** Scope of code and systems affected.

#### Option B: [Name]
- **Mechanics:** How this option works.
- **Pros:** Measurable advantages.
- **Cons & Risks:** Trade-offs, operational burdens, limitations.
- **Blast Radius:** Scope of code and systems affected.

**Reversibility:** Type 1 (One-Way Door - hard to reverse) | Type 2 (Two-Way Door - easy to reverse)

**Resolution:**
- **Outcome:** Selected Option A.
- **Justification:** Why this option wins given current constraints.
- **Validation:** Test seam or spike verification that confirms feasibility.
```

---

## 5. Spike Isolation & Hygiene Rules

1. **Strict Quarantine:** Spikes must reside exclusively in `.scratch/spikes/` or branch `spike/*`. Spikes must never be committed directly to main branches or production service trees.
2. **Hypothesis-Driven:** Every spike must begin with a single falsifiable statement: *"Hypothesis: Service X can ingest 5,000 events/sec with < 50ms p99 latency using batch bulk inserts."*
3. **Zero Polishing:** Write only enough code to prove or disprove the hypothesis. Avoid abstractions, clean-ups, unit tests, or edge-case handling in spikes.
4. **Extract Knowledge, Delete Artifact:** Record findings and measurements in the Living Map, then clean up or archive the spike code.

---

## 6. Verification & Quality Gates

Before declaring Wayfinding complete and advancing to `/to-spec`:
- [ ] **Destination is locked:** Quantifiable success criteria established.
- [ ] **Frontier is cleared:** Zero pending or unassigned ADFs in the Frontier queue.
- [ ] **Fog of War is eliminated:** No unaddressed system domains remain unknown.
- [ ] **Spike code quarantined:** No scratch/spike code leaked into active source trees.
- [ ] **Out of Scope boundaries set:** Non-goals clearly defined to prevent downstream drift.
