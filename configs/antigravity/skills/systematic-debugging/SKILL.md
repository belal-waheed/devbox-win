---
name: systematic-debugging
description: Strict 4-phase diagnostic runbook enforcing the Iron Law ("No fixes without root cause investigation first"). Use when encountering any bug, unexpected behavior, test failure, or regression across any stack.
---

# Systematic Debugging & Root Cause Investigation Runbook

## The Iron Law

```
=====================================================
  NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
=====================================================
```

Symptom patches mask underlying structural defects and inevitably cause regressions. Never apply a code fix until the precise root cause is isolated and proven.

---

## 1. The 4-Phase Diagnostic Process

### Phase 1: Isolation & Minimal Reproduction
- Read the entire stack trace and error logs without skimming.
- Create a minimal, isolated reproduction case (a standalone script or minimal failing unit test).
- Trace the exact line and runtime state where expected behavior diverges from actual behavior.

### Phase 2: Pattern & Boundary Analysis
- Inspect recent Git diffs and commits touching the affected module.
- Check component boundaries: Log inputs and outputs entering and exiting the boundary.
- Compare with working reference implementations in the codebase.

### Phase 3: Single-Variable Hypothesis
- Formulate a single, falsifiable hypothesis: *"Function X produces invalid state Y because Z is undefined during lifecycle phase W."*
- Change **one variable at a time** to validate the hypothesis.

### Phase 4: Root Fix & Verification
- Write a failing unit test that directly reproduces the defect.
- Implement the minimal correct fix at the root cause layer.
- Run the full test suite to verify the fix passes and introduces zero regressions.

---

## 2. The 3-Fix Rule

```
[Fix Attempt 1 Failed] --> Re-verify logs and assumptions
[Fix Attempt 2 Failed] --> Isolate dependencies and mock external state
[Fix Attempt 3 Failed] --> STOP IMMEDIATELY. Re-evaluate overall architecture.
```

If 3 fix attempts fail, the problem is not a minor bug—it is an architectural mismatch or incorrect mental model of the system. Stop churning code, review documentation, and re-assess.

---

## 3. Verification & Testing

Validate debugging effectiveness:
1. Ensure a failing test was written before the fix:
   ```bash
   npm test -- --grep "regression"
   # or: dotnet test / pytest
   ```
2. Verify full suite passes with zero regressions:
   ```bash
   npm test
   ```
3. Verify clean git diff without leftover debug logs:
   ```bash
   git diff
   ```

---

## 4. Things to Avoid

- Never wrap failing code in silent `try/catch { /* ignore */ }` blocks to suppress error messages.
- Never write fix code while guessing without log proof or reproduction test.
- Avoid testing multiple hypotheses simultaneously.
- Never declare a bug fixed without running automated tests.
