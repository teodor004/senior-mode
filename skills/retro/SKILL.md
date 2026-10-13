---
name: retro
description: Retrospective on the last senior-mode run - what worked, routing misfires, cost hotspots - and concrete edits to the routing policy and playbooks.
argument-hint: "[slug]"
disable-model-invocation: true
---

Target run: $ARGUMENTS (default: most recently modified `.senior/*/`).

1. Read state.json, run-log.md, review.md, report.md, and `.senior/run-log.jsonl` (hook log) for that run.
2. Produce:
   - Timeline: phases, waves, agent runs (by model/effort), fix rounds, escalations.
   - Routing misfires: WPs where haiku failed and needed escalation; WPs where opus/sonnet was overkill (trivial diff, first-try pass).
   - Review quality: findings that were real vs. noise; ATs that were weak.
   - Plan quality: ownership conflicts, missing contracts, mis-sized WPs.
3. Append 3–7 dated, specific lessons to `.senior/LESSONS.md` (create if missing). Format: `- [YYYY-MM-DD][<slug>] <lesson> → <proposed rule change>`.
4. Propose (do not apply) diffs to `04-routing-policy.md` or playbooks; ask the user before editing kit files.
5. Keep the output ≤ 60 lines. Use only haiku-level effort yourself; do not spawn agents unless the logs are > 500 lines (then one explorer).
