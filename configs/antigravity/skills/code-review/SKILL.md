---
name: code-review
description: Review code changes against coding standards and specification requirements using parallel subagents. Use when reviewing branches, pull requests, work-in-progress diffs, or validating changes against a spec.
---

# Code Review: Dual-Axis Standards & Spec Review

Perform structured code review along two independent axes:
1. **Standards:** Does the code conform to repository architectural conventions and code quality baselines?
2. **Spec:** Does the implementation match the originating specification without gaps or scope creep?

Both axes execute via parallel subagents to ensure unbiased, unpolluted analysis.

---

## 1. Operating Directives

1. **Independent Evaluation:** Never merge or conflate Standards and Spec findings. A pull request can be architecturally flawless yet build the wrong feature, or faithfully implement the spec while introducing severe technical debt.
2. **Pin the Base Point:** Resolve the comparison base before spawning subagents:
   ```bash
   git diff <fixed-point>...HEAD
   git log <fixed-point>..HEAD --oneline
   ```
3. **Primary Evidence:** Require concrete file paths, line numbers, and diff hunks for every finding.
4. **Baseline Smells:** Audit for Fowler code smells (Mysterious Name, Duplicated Code, Feature Envy, Data Clumps, Primitive Obsession, Shotgun Surgery). Documented repository rules always supersede heuristics.

---

## 2. Review Protocol

### Step 1: Resolve Target Diffs & Spec
- Locate the fixed point ref (`main`, commit hash, or branch).
- Retrieve the originating specification, issue description, or PR requirements.

### Step 2: Automated Diff Audit
Run the automated diff auditor script to detect immediate guardrail violations:
```powershell
pwsh -NoProfile -File scripts/audit-diff.ps1
```
See [scripts/audit-diff.ps1](scripts/audit-diff.ps1) for automated emoji, destructive command, and missing test checks.

### Step 3: Parallel Subagent Execution
- **Standards Reviewer:** Audits diff against codebase conventions, linters, and architectural boundaries.
- **Spec Reviewer:** Verifies each acceptance criterion and flags scope creep or omissions.

### Step 4: Synthesis & Reporting
- Output side-by-side markdown findings under `## Standards` and `## Spec`.
- Summarize actionable blocking items vs. advisory improvements.

---

## 3. Verification & Testing

Verify review findings before presenting:
1. Run automated linters and type checkers:
   ```bash
   npm run lint
   # or: dotnet format --verify-no-changes
   ```
2. Run test suite to verify test coverage across modified paths:
   ```bash
   npm test
   ```
3. Run automated diff audit:
   ```powershell
   pwsh -NoProfile -File scripts/audit-diff.ps1
   ```
4. Confirm git diff ref resolves without errors:
   ```bash
   git rev-parse --verify HEAD
   ```

---

## 4. Common Pitfalls & Negative Constraints

- Never re-rank or discard spec failures based on clean standards scores.
- Avoid broad conversational critiques without citing exact diff hunks and line ranges.
- Do not execute modifying refactors during a review pass without user authorization.
- Never approve pull requests with unhandled regression risks or broken tests.
