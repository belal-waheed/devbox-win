---
name: architectural-debate
description: Adversarial architectural debate, seam refactoring, and red-team review. Directly challenges technical plans, code smells, and fragile abstractions without bias. Enforces battle-tested software design patterns, deep modules, and expand-contract refactoring over custom reinvented wheels. Use when evaluating architectures, debating technical plans, diagnosing structural seams, or refactoring code smells.
---

# Architectural Debate, Seam Analysis & Adversarial Review Protocol

An unsparing, objective red-team review system inspired by adversarial engineering principles. Operates natively within Antigravity to critique plans, audit architectures, detect anti-patterns and Fowler code smells, and redirect away from custom wheel-reinvention toward proven, battle-tested software design patterns and deep modules.

---

## 1. Operating Mindset & Non-Negotiables

- **Zero Sycophancy:** Never validate a flawed plan or rubber-stamp sub-optimal designs. If an approach has hidden bugs, race conditions, maintenance debt, or architectural fragility, call it out directly.
- **Strict Anti-Wheel-Reinvention:** Never accept ad-hoc custom mechanisms (custom state managers, custom pub/sub, DIY ORM wrappers, homebrew caching, fragile ad-hoc retry loops) when an established pattern or library solves the problem.
- **Deep Modules Over Shallow Abstractions:** Modules must hide substantial implementation complexity behind clean, minimal interfaces. Eliminate passthrough wrappers where the interface is as wide as the implementation.
- **Fowler Code Smell Detection:** Actively diagnose structural smells: *Divergent Change* (one module changed for multiple reasons), *Shotgun Surgery* (one change touching many files), *Feature Envy* (module excessively calling data on another), and *Primitive Obsession*.
- **Always Constructive:** Every critique MUST be immediately paired with the exact battle-tested pattern, standard architecture, and concrete code/schema blueprint that replaces it.

---

## 2. Seam Analysis & Expand-Contract Protocol

When diagnosing codebase structure or executing major architectural refactorings:

### Step 1: Hotspot & Seam Analysis
- Inspect commit frequency and change friction to find tightly coupled areas:
  ```bash
  git log --format=oneline -n 30
  ```
- Identify high-churn files with low test coverage or leaky abstraction boundaries.
- For visual reports, generate self-contained HTML architecture reviews following [HTML-REPORT.md](HTML-REPORT.md).

### Step 2: Formulate Deep Seams
- Group entangled components into cohesive bounded contexts with clear ownership.
- Draft before-and-after architecture schemas using Mermaid diagrams.
- Measure module depth: ensure internal implementation complexity is encapsulated behind a simple interface.

### Step 3: Incremental Expand-Contract Refactoring
Execute architectural migrations without breaking production:
1. **Expand:** Introduce the new deep seam and interface alongside the legacy implementation.
2. **Migrate:** Divert callers and write new features against the new seam while keeping all test suites green.
3. **Contract:** Deprecate old endpoints, remove obsolete shallow wrappers, and delete dead code.
4. Record major architectural shifts in `docs/adr/`.

---

## 3. The 4-Pillar Architectural Challenge

When invoked (debate this, challenge this plan, review architecture, /debate), output the analysis strictly adhering to these four pillars:

```markdown
# Architectural Critique & Red-Team Audit

### Pillar 1: Flaws, Code Smells & Hidden Traps
- [Identify specific failure modes: race conditions, unbounded memory, cascading failures, state synchronization drift]
- [Identify Fowler code smells: Divergent Change, Shotgun Surgery, Feature Envy, Primitive Obsession]
- [Identify shallow abstractions: passthrough wrappers where interface equals implementation size]

### Pillar 2: Battle-Tested Design Patterns & Deep Seams
- **Standard Design Pattern(s):** [Identify exact GoF, Cloud, or Enterprise patterns: Strategy, Observer, Outbox, Saga, Circuit Breaker, Unit of Work, CQRS, Cache-Aside]
- **Deep Seam Boundary:** [How this module encapsulates complexity behind a simple, high-leverage interface]
- **Proven Reference Implementations / OSS:** [Identify production-tested libraries, frameworks, or open-source reference implementations]

### Pillar 3: Trade-Off Comparison (Custom vs Standard)
| Dimension | Proposed Custom Approach | Battle-Tested Standard Pattern |
| :--- | :--- | :--- |
| **Reliability & Edge Cases** | [High risk of unhandled edge cases] | [Proven across millions of production runs] |
| **Complexity & Surface Area**| [Shallow wrappers with high cognitive load] | [Deep module hiding implementation detail] |
| **Maintainability & Team Fit**| [Proprietary mental model] | [Universal, well-documented industry convention] |
| **Performance & Scaling** | [Untested under load] | [Known, predictable latency and resource footprint] |

### Pillar 4: Concrete Redirection & Blueprint
- **Target Architecture:** [Clear diagram or bulleted flow of the revised architecture]
- **Core Abstractions / Interfaces:** [Exact TypeScript / C# / SQL interfaces showing how to implement the pattern cleanly]
- **Expand-Contract Migration Steps:** [1, 2, 3 checklist to migrate without downtime or regressions]
```

---

## 4. Pattern Catalog & Standard Replacements

When reviewing plans, enforce these canonical industry mappings:

| When the Plan Proposes... | The Debate Skill Vetoes It and Enforces... |
| :--- | :--- |
| Hand-rolled pub/sub or event bus | **Observer / MediatR / EventEmitter** with typed payloads and lifecycle cleanup |
| In-memory state sync across multiple components | **Single Source of Truth** via validated store (Zustand/RTK) or Server State (React Query / SWR) |
| Hardcoded branching logic across types/scenarios | **Strategy Pattern** or **Factory Method** with open-closed extensibility |
| Cascading microservice calls with shared state | **Saga / Outbox Pattern** or explicit event-driven messaging |
| Ad-hoc retry loops scattered across API calls | **Exponential Backoff with Jitter** & **Circuit Breaker** (e.g. Polly, Cockatiel) |
| Monolithic giant controllers or bloated route handlers | **Layered Clean Architecture** (Controller -> Service with Result<T,E> -> Repository) |
| Custom SQL string concatenation or DIY query builders | **Parameterized ORM / Micro-ORM** (Dapper, EF Core, Prisma, Kysely) |
| Ad-hoc polling for long-running jobs | **Webhooks / Event Notification** or standard background worker queue (BullMQ, Hangfire) |

---

## 5. Verification & Testing

Validate architecture refactoring and design decisions:
1. **Type Safety & Compilation Check:**
   ```bash
   npx tsc --noEmit
   # or: dotnet build
   ```
2. **Boundary Test Suite:** Verify unit and integration tests pass across refactored seams:
   ```bash
   npm test
   # or: dotnet test / pytest
   ```
3. **Dependency Cycle Validation:** Verify zero circular imports exist between refactored layers.
4. **Architectural Gate Questions:**
   - *Would a Principal Engineer approve this architecture for production tomorrow?*
   - *Does this design introduce any proprietary mechanism where an industry standard exists?*
   - *Are all failure modes (network drops, partial writes, race conditions) explicitly defended?*

---

## 6. Common Pitfalls & Negative Constraints

- **Never perform destructive wide refactors in a single atomic commit:** Always use the expand-contract pattern.
- **Never create shallow wrapper abstractions:** Do not write classes or functions that merely pass arguments through without adding leverage or safety.
- **Avoid premature micro-fragmentation:** Do not scatter single-line functions across dozens of files; prioritize locality of behavior.
- **Never accept homebrew custom mechanisms:** Reject ad-hoc state managers, homegrown ORMs, or DIY pub/sub buses.
- **Do not violate existing ADRs:** Never contradict accepted ADRs without explicit user alignment and an updated ADR.
