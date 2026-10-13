# 05 — Fan-out & Execute

## Preconditions
state.phase = `execute`; plan approved (or --auto); `base_sha` = HEAD of senior branch containing the plan; `.claude/settings.json` has `worktree.baseRef: "head"` (if unknown, the base-check step below protects you).

## Per wave
1. Select WPs in the wave whose deps are merged. Cap to max_parallel; queue the rest.
2. For each WP, build the delegation prompt from this skeleton (fill every field; paste the WP file verbatim):

```
You are executing ONE work package for project <slug>. You cannot see the orchestrator's conversation; everything you need is below.

BASE_SHA: <sha>
WORK PACKAGE (verbatim):
<contents of .senior/<slug>/wp/WP-n.md>

RULES
- First: verify base. Run `git merge-base --is-ancestor <BASE_SHA> HEAD`. If it fails, run
  `git checkout -B "$(git rev-parse --abbrev-ref HEAD)" <BASE_SHA>` before any edit.
- Edit ONLY owned_files. If you must touch another file, stop and report it under `deviations` with status "blocked".
- Follow conventions: <from explore.md>. No new dependencies unless the WP allows it.
- Run: <test_command> (and lint/typecheck if listed). Fix your own failures.
- Commit all work in your worktree: `git add -A && git commit -m "<WP-id>: <title>"`. Do not push. Do not merge.
- Stop when acceptance criteria are met; do not gold-plate.

RETURN exactly one block at the end:
RESULT
{"wp":"WP-n","status":"done|partial|blocked","branch":"<git rev-parse --abbrev-ref HEAD>","head_sha":"<sha>",
 "files_changed":["..."],"tests":{"command":"...","passed":true,"summary":"12 passed, 0 failed"},
 "acceptance":[{"id":"AT-1","met":true,"evidence":"test name / output line"}],
 "deviations":[],"risks":[],"notes":"≤ 3 lines"}
```

3. Spawn each with the Agent tool: `subagent_type` = routed agent, `description` = "<WP-id> <title>", optional `model`/`effort` only for escalations. Agents with `isolation: worktree` in frontmatter get their own worktree automatically.
4. On each return: parse RESULT; record `worktreeBranch`/`worktreePath` if the tool result provides them (prefer them over self-reported branch); update state.wps and run-log.md (agent, model, effort, status, duration if shown).
5. Handling:
   - `done` → queue for phase 06 review.
   - `partial` (hit maxTurns) → resume the same subagent once with "continue to completion", else escalate per 04.
   - `blocked` → if deviation is a missing contract, fix the plan (re-ask architect only if design changed) and re-run; otherwise STOP and ask.
6. Do not start the next wave until this wave passes 06 and merges in 07 (partial integration per wave).

## Guardrails
- Never run two WPs that own the same file, even if retrying.
- If any subagent reports touching files outside ownership, treat as review blocker.
- If the user interrupts, write state first, then respond.
