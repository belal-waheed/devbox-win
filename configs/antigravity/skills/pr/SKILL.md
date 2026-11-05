---
name: pr
description: Package implemented code changes into proof-backed pull request bodies with visual summaries, verification evidence, and blast-radius risk analysis.
---

# PR: Proof-Backed Pull Request Authoring Protocol

PR packages implemented code changes into high-density, evidence-backed pull request descriptions. Grounded in Matt Pocock's PR architecture standards, it replaces vague commit summaries with structured visual call trees, concrete verification proof, blast-radius risk classifications, and explicit rollback strategies.

```
[Git Working Tree / Branch Diffs]
                │
                ▼
   [1. Diff & Evidence Analysis]  ──► Inspect changes & execute test suites
                │
                ▼
   [2. Visual Summary Modeling]   ──► Generate ASCII call tree or Mermaid diagram
                │
                ▼
   [3. Blast Radius & Danger]     ──► One-Way vs Two-Way Door & Rollback Plan
                │
                ▼
   [4. PR Packaging & Publish]    ──► gh pr create or REST API fallback
```

---

## 1. Core Operating Principles

1. **Proof Over Promises:** Every PR must include verifiable execution proof (passing test suite output, typecheck confirmation, or curl benchmark logs). Never claim code works without pasted evidence.
2. **Visual Orientation:** Reviewers must comprehend system changes within five seconds via an ASCII call tree, file map, or Mermaid architecture diagram.
3. **Explicit Blast Radius & Danger Classification:** State clearly whether this PR is a One-Way Door (irreversible schema change, public API break) or a Two-Way Door (internal refactor, additive feature). Detail the exact rollback plan.
4. **Conventional Commits Alignment:** Enforce standard Conventional Commits formatting (`feat:`, `fix:`, `refactor:`, `test:`, `perf:`, `chore:`).
5. **Zero Emojis:** Strictly adhere to the zero-emoji standard in PR titles, markdown bodies, and automation logs.

---

## 2. Pull Request Authoring Workflow

### Phase 1: Diff & Evidence Inspection
1. Inspect the branch diff against the base branch:
   ```bash
   git diff --stat origin/main...HEAD
   ```
2. Execute project verification suites and capture raw, clean terminal outputs:
   - Typechecking (`tsc --noEmit` or equivalent)
   - Unit & Integration test runner (`npm test`, `pytest`, `dotnet test`)
   - Linter / Code formatting verification

### Phase 2: Visual Architecture Synthesis
- Map the flow of execution or file modifications into a visual representation:
  - For API/backend changes: ASCII call tree or Mermaid sequence diagram.
  - For multi-module changes: Directory/file tree indicating additions, modifications, and deletions.

### Phase 3: Blast Radius & Merge Danger Assessment
- Classify the risk profile:
  - **Risk Level:** Low | Medium | High | Critical
  - **Decision Type:** One-Way Door (requires migration script, irreversible state) vs Two-Way Door (clean git revert).
  - **Breaking Changes:** Explicit list of any deprecated methods, signature changes, or config key renames.
  - **Rollback Strategy:** Exact command or deployment action to undo changes if an incident occurs.

### Phase 4: Publishing
- Format the final description and submit via GitHub CLI:
  ```bash
  gh pr create --title "feat(domain): add atomic order processing with idempotency" --body-file .scratch/pr_body.md
  ```
- If GitHub CLI is unavailable, fall back to GitHub REST API via PowerShell (`Invoke-RestMethod`).

---

## 3. Standard PR Description Template

Every Pull Request must follow this exact Markdown structure:

```markdown
## Summary
Concise 1-2 sentence description of the change and its primary user/system impact.

---

## 1. Visual Summary

```
[HTTP Request: POST /api/orders]
       │
       ▼
OrderController.create()
       │
       ├──► OrderValidator.validate() [Zod: Validates schema & items]
       │
       ├──► IdempotencyService.checkOrLock() [Redis: 60s lease]
       │       │
       │       └── (Duplicate Key) ──► Early Return: 409 Conflict
       │
       └──► OrderRepository.save() [Postgres: Atomic Transaction]
               │
               └──► EventDispatcher.publish(OrderCreatedEvent)
```

---

## 2. Proof & Verification Evidence

### Automated Test Suite Run
```
PASS tests/unit/order-service.spec.ts
  OrderService
    ✓ should create order and return 201 when payload is valid (18 ms)
    ✓ should abort and return 409 when duplicate idempotency key exists (12 ms)
    ✓ should roll back transaction when inventory reservation fails (15 ms)

Test Suites: 1 passed, 1 total
Tests:       3 passed, 3 total
Snapshots:   0 total
Time:        1.42 s
```

### Typecheck & Lint Output
```
$ tsc --noEmit
Done in 1.12s. Zero errors found.
```

---

## 3. Blast Radius & Merge Danger

| Dimension | Assessment | Details |
|---|---|---|
| **Risk Level** | Low / Medium | Affects only order ingestion pathway |
| **Door Type** | Two-Way Door | Safe to revert via single commit revert |
| **Breaking API Changes** | None | Fully additive fields; existing payload backwards compatible |
| **Database Migrations** | None | Uses existing tables |

### Rollback Strategy
If errors occur post-deploy:
1. Revert merge commit via `git revert -m 1 <commit-hash>`.
2. Deploy previous release tag.
3. No data patching or DB migration rollbacks required.

---

## 4. Conventional Commits
- `feat(orders): implement idempotency check in order ingestion`
- `test(orders): add unit tests for concurrent duplicate order requests`
- `docs(orders): document idempotency key header in api reference`

---

## 5. Review Checklist
- [ ] Layered Clean Architecture respected (`Router -> Service -> Repository`).
- [ ] Input validation enforced at system edge via schema parser.
- [ ] No hardcoded configuration, secrets, or machine-specific paths.
- [ ] All unit and integration tests passing.
```

---

## 4. Anti-Patterns & Negative Constraints

- **Never submit empty or single-line PR descriptions:** Descriptions like "fixed bugs" or "updated code" are prohibited.
- **Never claim tests pass without terminal log evidence:** Always copy the exact test runner output into the Proof section.
- **Never omit the rollback strategy:** Every PR must clearly instruct the on-call engineer how to safely back out the change.
- **Never include personal machine paths:** Verify that all paths in code diffs and logs are repository-relative.
