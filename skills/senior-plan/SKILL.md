---
name: senior-plan
description: Planning-only senior mode. Use when the user wants a spec, ADRs, risk register and work-package plan WITHOUT implementation ("plan this like a senior", "just the plan", "design doc for X").
argument-hint: "<goal>"
---

Run the senior-build process for: $ARGUMENTS — phases 00 → 03 ONLY.

1. Read and follow, in order:
   - `${CLAUDE_SKILL_DIR}/../senior-build/playbooks/00-intake-clarify.md`
   - `${CLAUDE_SKILL_DIR}/../senior-build/playbooks/01-explore.md`
   - `${CLAUDE_SKILL_DIR}/../senior-build/playbooks/02-spec.md`
   - `${CLAUDE_SKILL_DIR}/../senior-build/playbooks/03-plan-decompose.md`
   - and apply `${CLAUDE_SKILL_DIR}/../senior-build/playbooks/04-routing-policy.md` to fill the routing columns.
2. Skip branch creation if the user only wants documents; write to `.senior/<slug>/`.
3. End at STOP-2 with the plan summary and: "Run `/fanout .senior/<slug>/plan.md` to execute."
4. Do not spawn implementers. Allowed agents: explorer, architect-planner.
