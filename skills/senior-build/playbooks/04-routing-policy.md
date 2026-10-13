# 04 — Routing Policy (model · effort · maxTurns · isolation)

Principle: pay for intelligence only where errors are expensive. Cheap models for cheap work.

## Decision table
| WP / task type | Agent | Model | Effort | maxTurns* | Isolation |
|---|---|---|---|---|---|
| Codebase search, file mapping, "where is X" | explorer | haiku | low | 20 | none (read-only) |
| Spec, decomposition, ADRs, risk | architect-planner | opus | high | 30 | none (writes .senior/ only) |
| Complex impl: new abstraction, cross-module, concurrency, state, auth/crypto, perf-sensitive, unclear spec | implementer-complex | sonnet | medium (high if risk=H) | 40 | worktree |
| Mechanical impl: boilerplate following an existing pattern, config, rename, CRUD, glue, migrations from template | implementer-simple | haiku | low | 20 | worktree |
| Unit test scaffolding, fixtures, snapshot updates | test-writer | haiku | low | 25 | worktree |
| Integration/property tests, tricky mocks | test-writer (override) | sonnet | medium | 25 | worktree |
| Docs, README, changelog, docstrings | docs-writer | haiku | low | 15 | worktree |
| Adversarial correctness review | reviewer-adversarial | opus | high | 25 | none (read-only) |
| Security review (only if any WP risk=H or touches auth, input parsing, secrets, deps, network) | security-reviewer | sonnet | medium | 20 | none (read-only) |
| Merge, conflict resolution, full test run | integrator | sonnet | medium | 30 | none (main checkout, senior branch) |

*maxTurns is set in agent frontmatter; it cannot be passed per call. Defaults above are the shipped values.

## Overrides (per Agent call)
Pass `model` and/or `effort` on the Agent call only to apply the escalation ladder below. Never pass fable/best/inherit.

## Escalation ladder (per WP, max one step)
1. Haiku/low WP fails acceptance after 1 fix round → re-run as implementer-complex sonnet/medium.
2. Sonnet/medium WP fails after 2 fix rounds → sonnet/high once, else STOP and ask the human.
3. Opus is never used for implementation by default. Offer it at a STOP if a WP is blocked on reasoning.

## Fan-out rules
- **Max parallel:** `--max-parallel` or 4 (Pro: consider 2–3; Max: up to 6). Never exceed the number of independent WPs in the current wave.
- **One message, many calls:** launch a wave's WPs as multiple Agent tool calls in a single assistant message.
- **Contention avoidance:** disjoint `owned_files`; hotspots only in WP-0 or integrator; no WP edits files another WP in the same wave reads as a contract.
- **Waves:** next wave starts only after the previous wave's WPs are reviewed-and-merged into the senior branch (or explicitly declared independent of them).
- **Worker isolation:** worker agents have no Agent tool (no nested fan-out) — the orchestrator is the only spawner.

## When NOT to fan out (run one implementer sequentially instead)
- < 3 WPs, or total expected diff < ~150 lines.
- WPs share most files or form a chain (A→B→C) with no width.
- The core design is still uncertain (spike first with one implementer-complex).
- The repo has no runnable tests (fan-out without a gate multiplies risk) — first create a test harness WP.
- User is near a usage limit (ask).

## Cost sanity check (state at STOP-2)
Estimated agents = explorers + 1 architect + Σ WPs + reviewers (+ fixes ≤ 2×WPs). Flag if > 12.
