# 02 — Spec, ADRs, Risks

Purpose: a reviewable contract of WHAT and WHY before HOW.

## Delegate
One `architect-planner` call (opus/high). Prompt must include: intake.md and explore.md contents verbatim, the absolute paths of this skill's `templates/spec.md` and `templates/adr.md` (resolve them from the skill directory you saw when SKILL.md loaded — `${CLAUDE_SKILL_DIR}` is only expanded inside SKILL.md, not in playbooks), and the output paths below. The architect writes ONLY under `.senior/<slug>/`.

## Spec requirements (architect must satisfy)
- Problem, goals, non-goals (explicit), users/interfaces.
- Functional requirements as numbered, testable statements: `FR-1 … FR-n`.
- Non-functional requirements with a measurable bar: `NFR-1 …`.
- Interfaces/contracts: function signatures, CLI flags, HTTP routes, schemas — exact types.
- Acceptance tests: `AT-1 …`, each mapped to FR/NFR, each runnable (command or test name).
- Risk register: id, description, likelihood (L/M/H), impact (L/M/H), mitigation, owner WP.
- Assumptions (especially in --auto mode) and open questions.
- ADRs: one file per non-obvious decision (library choice, data model, sync vs async, migration strategy). Max 3 unless justified.

## Orchestrator checks (reject and re-ask once if any fail)
- Every FR has ≥ 1 AT. Every H-impact risk has a mitigation.
- Non-goals section is non-empty.
- Contracts are concrete enough that two engineers would implement compatible code.

## Exit
Files: `.senior/<slug>/spec.md`, `.senior/<slug>/adr/ADR-00N-<title>.md`. state.phase = `plan`.
