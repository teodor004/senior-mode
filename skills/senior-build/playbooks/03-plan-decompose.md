# 03 — Plan & Decompose into Work Packages

Purpose: split the spec into independent, parallel-safe work packages (WPs) with file ownership.

## Delegate
Same `architect-planner` (continue/resume it if possible, else new call with spec.md inline). Output `.senior/<slug>/plan.md` and one `.senior/<slug>/wp/WP-<n>.md` per package using `templates/work-package.md`.

## Decomposition rules
1. **Disjoint ownership:** every file to be created/modified appears in exactly one WP's `owned_files`. Read-only dependencies go in `reads`.
2. **Shared hotspots** (lockfiles, package manifests, root configs, DB migrations, barrel/index files, routing tables, generated code) belong to a single sequential `WP-0 foundation` that runs first, or to the integrator. Never to two WPs.
3. **Contracts first:** if WP-B consumes WP-A's interface, the interface (signature/types/stub) is defined in the spec or built by WP-0, so A and B can run in parallel against it.
4. **Size:** each WP ≈ 1–8 files, ≤ ~300 changed lines, completable in its maxTurns. Split larger ones.
5. **Tests travel with code:** each implementation WP includes its unit tests unless a separate test-writer WP is clearly cheaper.
6. **Dependencies form a DAG**; compute waves: wave 0 = no deps, wave k = deps all in < k.
7. Each WP gets `type`, `complexity` (S/M/L), `risk` (L/M/H) — routing uses these.

## plan.md must contain
- WP table: id, title, type, complexity, risk, owned files, depends_on, wave, suggested agent/model/effort/maxTurns (from 04-routing-policy.md), isolation.
- Wave diagram (text), critical path, total estimated agents.
- Integration order and merge strategy.
- Verification plan: which ATs run after which wave; final full-suite command.
- Ownership check: a list of all owned files with their single owner (orchestrator verifies no duplicates).

## Machine-readable block (append to plan.md, keep in sync)
```json
{"wps":[{"id":"WP-1","title":"...","type":"impl-complex","complexity":"M","risk":"M",
  "owned_files":["src/a.ts"],"reads":["src/types.ts"],"depends_on":[],"wave":0,
  "agent":"implementer-complex","model":"sonnet","effort":"medium","isolation":"worktree",
  "acceptance":["AT-1","AT-3"],"test_command":"npm test -- a.spec.ts"}]}
```

## Orchestrator checks before STOP-2
- No file owned twice (diff the lists). No cycles. Every AT covered by some WP.
- If < 3 WPs or all WPs are sequential → recommend NOT fanning out (see 04 "When not to fan out").

## Gate — STOP-2
Commit planning artifacts on the senior branch if the user keeps `.senior/` tracked (`git add .senior/<slug> && git commit -m "chore(senior): spec and plan for <slug>"`), then record `base_sha` = new HEAD (worktrees must see this commit).
Present STOP-2 with WP table, waves, routing, risks, estimated cost. Wait (unless --auto). Set phase `awaiting-approval` while waiting, then `execute`.
