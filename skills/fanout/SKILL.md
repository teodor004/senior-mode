---
name: fanout
description: Execute an existing senior-mode plan (plan.md with work packages) via routed parallel subagents, review, and integration.
argument-hint: "<path/to/plan.md> [--max-parallel N] [--auto]"
disable-model-invocation: true
---

Plan: $ARGUMENTS

1. Read the plan and its `wp/` files. Validate: machine-readable JSON block present, no file owned twice, DAG acyclic, every WP has acceptance criteria and a test command. If invalid, list problems and stop.
2. Run the path-case and kit-files-ignored checks from the Preflight in `${CLAUDE_SKILL_DIR}/../senior-build/playbooks/00-intake-clarify.md` (stop on a path-case mismatch).
   Then load/restore `.senior/<slug>/state.json` (create if missing; base_sha = current HEAD on `senior/<slug>`; create that branch if absent).
3. Confirm with the user (unless `--auto`): waves, agents/models, max parallel. This is STOP-2.
4. Read and follow in order:
   - `${CLAUDE_SKILL_DIR}/../senior-build/playbooks/04-routing-policy.md`
   - `${CLAUDE_SKILL_DIR}/../senior-build/playbooks/05-fanout-execute.md`
   - `${CLAUDE_SKILL_DIR}/../senior-build/playbooks/06-review-verify.md`
   - `${CLAUDE_SKILL_DIR}/../senior-build/playbooks/07-integrate-merge.md`
   - `${CLAUDE_SKILL_DIR}/../senior-build/playbooks/08-report.md`
5. Resume-safe: skip WPs whose state is `done` and whose branch is already merged into `senior/<slug>`.
