# 08 — Final Report

Write `.senior/<slug>/report.md` from `templates/final-report.md`, then print a condensed version (≤ 40 lines) in chat.

## Must include
- Outcome: merged / branch ready / partial / aborted — one sentence.
- What was built: FR → WP → commit mapping; AT verification table (AT, status, evidence).
- Decisions: ADR list with one-line rationale; assumptions made (esp. --auto).
- Risks: residual risks from the register + new ones found in review; follow-ups (minor findings).
- Execution log: agents run (type, model, effort, status, rounds), escalations, waves, wall time if known.
- Cost/usage notes: number of subagent runs by model; advise the user to check `/usage` (or `/cost`) for actual consumption — do NOT invent token numbers.
- Cleanup instructions: worktrees/branches remaining.
- Design docs: `.senior/` is git-excluded, so offer to copy spec.md, adr/ and report.md into a tracked folder (e.g. `docs/design/<slug>/`) if the user wants them in history.

Set state.phase = `done`. Suggest `/retro` if the run had escalations or > 1 fix round.
