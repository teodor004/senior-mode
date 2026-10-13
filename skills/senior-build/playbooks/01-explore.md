# 01 — Explore

Purpose: map only the code that matters, cheaply, without polluting the main context.

## Delegate
Spawn 1–3 `explorer` subagents IN PARALLEL (single message, multiple Agent calls), each with a distinct question, e.g.:
- A: "Architecture & entry points relevant to <goal>; build/test/lint commands."
- B: "Existing patterns to imitate for <feature type> (file paths + 1-line summaries)."
- C: "Risky areas: shared state, migrations, public APIs, config, lockfiles touched by <goal>."
Use 1 explorer for small repos (< ~50 source files).

## Required return format (put this in each prompt)
```
EXPLORE-RESULT
question: <...>
findings:
  - path: <file>  why: <relevance>  notes: <≤ 2 lines>
commands: {build: "...", test: "...", lint: "...", typecheck: "..."}
conventions: [<naming, error handling, test layout>]
hotspots: [<files many WPs would need to touch>]
unknowns: [<what could not be determined>]
```

## Orchestrator actions
1. Merge results into `.senior/<slug>/explore.md` (dedupe; keep ≤ 150 lines).
2. Verify the test command actually runs: `<test command>` once (or ask explorer to). Record baseline pass/fail — pre-existing failures must be known before blaming new work.
3. Update state.phase = `spec`.

## Do not
- Do not read whole directories yourself; that is what explorers are for.
- Do not start designing; record facts only.
