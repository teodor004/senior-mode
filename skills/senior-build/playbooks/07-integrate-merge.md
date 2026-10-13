# 07 — Integrate & Merge

## Per wave (after 06 passes)
Delegate to `integrator` (sonnet/medium), working in the main checkout on `senior/<slug>`:
1. `git switch senior/<slug>`; ensure clean status.
2. Merge WP branches in plan's integration order: `git merge --no-ff <wp-branch> -m "merge <WP-id>: <title>"`.
3. On conflict: resolve only if mechanical (imports, adjacent edits); if semantic, abort that merge (`git merge --abort`) and return `conflict` with the files and both intents.
4. After all merges: run full build + lint + typecheck + test suite. Compare to the baseline from 01-explore (pre-existing failures are not regressions).
5. Return:
INTEGRATION
{"merged":["WP-1","WP-2"],"conflicts":[],"suite":{"command":"...","passed":true,"summary":"..."},"regressions":[],"head_sha":"..."}

Orchestrator: on regressions → route a fix WP (implementer-complex) against the senior branch, then re-run 06 targeted review. Max 2 rounds, then STOP.

## Final merge — STOP-3
After the last wave:
=== STOP-3: Ready to merge senior/<slug> into <base_branch> ===
Show: diffstat (`git diff --stat <base_branch>...senior/<slug>`), suite result, open minors, risks.
Options: merge (fast-forward/--no-ff) | leave branch for PR | abort.
- Even in --auto: do not merge into base; leave the branch and say how to open a PR.
- Never push. Never force.

## Cleanup (after decision)
List leftover worktrees: `git worktree list`. Offer (do not auto-run) `git worktree remove <path>` and `git branch -d <wp-branch>` for merged WP branches.
