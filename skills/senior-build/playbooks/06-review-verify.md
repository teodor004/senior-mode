# 06 — Adversarial Review, Test Gate, Bounded Fix Loop

## 1. Test gate (cheap, first)
For each `done` WP branch: run its `test_command` in its worktree path (or ask the integrator to). Any failure → straight to fix loop; skip expensive review until green.

## 2. Reviews (parallel, read-only)
Spawn in one message:
- `reviewer-adversarial` (opus/high) — once per wave, covering all WP diffs (`git diff <base_sha>..<branch>` per branch) against spec.md and the WPs' acceptance criteria.
- `security-reviewer` (sonnet/medium) — only if any WP risk=H or touches auth, input parsing, file/OS calls, secrets, deps, network.

Review prompt must include: spec.md FR/NFR/AT list, the WP files, the branch names + base_sha, and this checklist:

### Adversarial checklist
- Correctness: does the code actually satisfy each AT? Try to construct a failing input for each.
- Edge cases: empty/null, boundaries, unicode, large inputs, concurrency/re-entrancy, time zones, partial failure.
- Contracts: signatures/types match spec exactly; no silent breaking change to public API.
- Tests: do tests assert behaviour (not implementation)? Would they fail if the code were wrong? Any skipped/flaky tests?
- Scope: changes outside owned_files; dead code; debug leftovers; TODOs without issue.
- Errors: swallowed exceptions, missing error paths, misleading messages, resource leaks.
- Consistency with codebase conventions and ADRs.
- Cross-WP integration: incompatible assumptions between branches.

### Required return
```
REVIEW
{"verdict":"approve|request_changes|block",
 "findings":[{"id":"F-1","severity":"blocker|major|minor|nit","wp":"WP-2","file":"src/x.ts","line":42,
   "claim":"...","evidence":"failing input / reasoning / command output","fix":"concrete change"}],
 "ats_unverified":["AT-4"]}
```
Rule for reviewers: every blocker/major must include evidence; claims without evidence are downgraded to minor.

## 3. Bounded fix loop
- Group blocker+major findings by WP. Send to the WP's original subagent (resume if possible) or a new one of the same type, on the same branch: "Fix these findings; re-run tests; commit; return RESULT".
- After each fix round, re-run test gate and a *targeted* re-review (same reviewer, only the findings + new diff).
- Max 2 rounds per WP → then escalate once per 04 → then STOP and ask the human with the unresolved findings.
- Minor/nit: batch into the report as follow-ups; do not loop on them.

## 4. Gate decision
gate = `passed` when: all WP tests green, no open blocker/major, every AT either verified or explicitly waived by the human. Write `.senior/<slug>/review.md` (findings table + resolution). Update state.gate.
