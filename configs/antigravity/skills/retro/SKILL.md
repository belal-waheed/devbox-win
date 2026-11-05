---
name: retro
description: Conduct post-implementation retrospectives to analyze agent friction, failure root causes, and propose actionable rule or skill updates.
---

# Retro: Post-Implementation Retrospective & Self-Correction Protocol

Retro is an engineering governance protocol executed following the completion of major features, sprints, or pull requests. It systematically inspects agent execution transcripts, identifies points of friction and tool failure, isolates root causes, and synthesizes permanent, actionable guardrails to prevent recurring errors.

```
[Completed Feature / Session Transcript]
                   │
                   ▼
     [1. Trajectory & Error Mining]   ──► Parse logs, retries, tool failures, overrides
                   │
                   ▼
     [2. Failure Mode Taxonomy]       ──► Classify root causes (Ambiguity, Tools, Invariants)
                   │
                   ▼
     [3. Rule & Skill Synthesis]      ──► Formulate concrete, non-fluff guardrails
                   │
                   ▼
     [4. Permanent Living Vault Sync] ──► Update project rules, ADRs, and documentation
```

---

## 1. Core Operating Principles

1. **Blameless Root Cause Investigation:** Focus on systemic failure modes, missing invariants, and unclear interfaces rather than superficial mistakes.
2. **First-Principles Corrective Action:** Every observed bug or friction point must yield a concrete, enforceable guardrail (a rule update, test seam, or skill refinement)—never vague advice.
3. **Transcript-Grounded Evidence:** Base retro observations on concrete data: tool errors, command retries, user corrections, and token bloat from session logs.
4. **Permanent Knowledge Capture:** Ensure learnings are persisted to repository rules, living documentation, or project hubs, preventing context decay across sessions.
5. **Zero Emojis:** Maintain clean, professional, and dense technical documentation without decorative emojis or filler.

---

## 2. Retrospective Workflow

### Phase 1: Trajectory Mining
- Review the session trajectory transcript (`transcript.jsonl` or execution history):
  - Count repeated tool executions or command failures.
  - Identify prompts where the agent drifted from instructions or required user intervention.
  - Note unexpected subagent spawns, context window overflow, or slow operations.

### Phase 2: Failure Mode Taxonomy
Categorize every identified friction point into one of four standard failure modes:

| Failure Mode | Definition | Typical Manifestation |
|---|---|---|
| **1. Prompt Ambiguity** | Requirements lacked concrete acceptance criteria or edge conditions. | Agent made assumptions that required mid-flight correction. |
| **2. Tool / Environment Friction** | Tool limitations, missing CLI utilities, or shell escaping issues. | Failed PowerShell scripts, missing packages, or unsupported flags. |
| **3. Context Rot & Compaction** | Long context led to forgotten invariants or architectural drift. | Re-writing existing utilities, violating established patterns. |
| **4. Missed Invariants** | Code violated core system contracts or skipped boundary validation. | Broken tests, unhandled null states, skipped error boundaries. |

### Phase 3: Guardrail Synthesis
- For each failure mode, draft a concrete operational countermeasure:
  - **Rule Update:** Add a precise negative constraint to project rules.
  - **Skill Enhancement:** Refine a skill protocol with explicit checklists or error handlers.
  - **Automated Verification:** Add a lint rule, typecheck invariant, or test case.

### Phase 4: Vault & Documentation Synchronization
- Update the relevant project documentation hub or append a summary to the active sprint note.
- Output the retrospective report using the standard template below.

---

## 3. Standard Retrospective Report Schema

```markdown
# Engineering Retrospective: [Feature / Sprint Name]

**Date:** YYYY-MM-DD
**Initiative:** [Initiative Reference]
**Participants / Agents:** [Agent ID / Engineering Team]

---

## 1. Executive Summary
High-level overview of what was built, final outcome, and whether timeline/quality goals were achieved.

---

## 2. Quantitative Metrics
- **Tickets Completed:** N / N
- **Files Modified:** N
- **Test Coverage Change:** +X%
- **Tool Failures / Retries:** N occurrences

---

## 3. Friction Points & Failure Mode Analysis

### Issue 1: [Concise Description of Problem]
- **Observed Behavior:** What went wrong during execution (command failure, user correction, timeout).
- **Classification:** Prompt Ambiguity | Tool Friction | Context Rot | Missed Invariants
- **Root Cause Analysis:** Why did the failure occur at a first-principles level?
- **Impact:** Delay in tokens, unnecessary tool calls, or regression introduced.

### Issue 2: [Concise Description of Problem]
- **Observed Behavior:** What went wrong.
- **Classification:** Prompt Ambiguity | Tool Friction | Context Rot | Missed Invariants
- **Root Cause Analysis:** Why it happened.
- **Impact:** Tokens/time cost.

---

## 4. Proposed Actionable Guardrails

| Target System | Proposed Change | Purpose / Invariant Enforced |
|---|---|---|
| Project Rule (`RULE[...]`) | Add negative constraint prohibiting X | Prevent recurring regression |
| Skill (`SKILL.md`) | Add mandatory verification step in Phase Y | Catch type errors before test execution |
| CI Pipeline | Add script checking file path leaks | Ensure 100% portability in commits |

---

## 5. What Went Well (Preserved Strengths)
- Rapid tracer-bullet slicing enabled early integration testing.
- Layered clean architecture separated domain logic from persistence cleanly.
```

---

## 4. Verification & Quality Gates

Before concluding a retrospective:
- [ ] **Data Grounded:** Every cited friction point is backed by an actual event in the transcript.
- [ ] **Actionable Countermeasures:** Proposed guardrails are specific and immediately implementable.
- [ ] **Zero Sycophancy:** Real flaws and delays are analyzed honestly without defensive explanations.
- [ ] **No Local Path Leaks:** Documentation is clean and portable across machines.
