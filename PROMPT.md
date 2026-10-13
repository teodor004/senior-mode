# senior-mode: a Claude Code plugin that imitates ultracode with markdown skills and subagents (verified against the October 2026 docs)

You can get most of ultracode's behaviour without writing any workflow code. Use one orchestrator **skill** that runs in your main conversation. It loads phase playbooks only when it needs them and spawns **custom subagents** through the Agent tool. Each subagent has its own `model`, `effort`, `maxTurns` and `isolation: worktree` frontmatter. All of these are documented fields as of October 2026, and `effort` is a valid subagent field.\[1\]

What the kit can't match is determinism and scale. Ultracode moves the plan into a JavaScript workflow script and sends `xhigh` effort. This kit keeps Claude as a turn-by-turn orchestrator. In exchange you get human STOP checkpoints, which workflows can't offer mid-run, and much tighter cost control.\[2\]

## TL;DR

- **Build it as a plugin of skills, agents and hooks.** Package it as a Claude Code plugin called `senior-mode`: one `senior-build` skill, eight phase playbooks plus templates, nine subagents, and a `hooks/hooks.json`. You can install it with `/plugin marketplace add <you>/senior-mode` and `/plugin install senior-mode@senior-mode-market`, or by copying the folders into `.claude/`.
- **There are two triggers, and the slash command is the reliable one.** Typing "build like a senior: X" auto-triggers through the skill `description`/`when_to_use`, which is probabilistic. A `UserPromptSubmit` hook makes it deterministic. `/senior-build X` always works. Ultracode's own `ultracode` keyword can't be reused: it's a built-in that only Claude Code's harness recognises.
- **Cost control comes from routing, caps and gates.** Haiku/low handles exploration, docs and mechanical work. Sonnet/medium handles complex implementation. Opus/high handles planning and adversarial review. Every agent has explicit `maxTurns`, parallelism is capped at 4 by default, and fix loops stop after 2 rounds. Agents never use `inherit`, `fable` or `best`, so you can't be silently billed for Fable or usage credits. Expect multi-agent runs to cost several times a single session: Anthropic's engineering post "How we built our multi-agent research system" (June 2025) reports that "multi-agent systems use about 15× more tokens than chats."

## Key Findings (what the docs confirm and how it shaped the design)

1. **Custom commands and skills are now the same thing.** The docs say "A file at `.claude/commands/deploy.md` and a skill at `.claude/skills/deploy/SKILL.md` both create `/deploy` and work the same way."\[3\] Skills add supporting files, invocation control and auto-loading, so the kit uses skills only.\[4\]
2. **Skill frontmatter is richer than most guides show.** Documented fields include `name`, `description`, `when_to_use`, `argument-hint`, `arguments`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `disallowed-tools`, `model`, `effort`, `context: fork`, `agent`, `background`, `hooks`, `paths`, `shell`, `metadata`, `license` and `compatibility`. Claude Code ignores unknown fields silently. The combined `description` + `when_to_use` text is truncated at 1,536 characters, so put trigger phrases first.\[4\]
3. **Progressive disclosure is manual.** The docs say to "Reference supporting files from `SKILL.md` so Claude knows what each file contains and when to load it," and to keep `SKILL.md` under 500 lines.\[4\] Nothing loads supporting files automatically. That's why SKILL.md links each playbook by path and tells Claude when to read it. `${CLAUDE_SKILL_DIR}` resolves to the skill folder in both plugin and manual installs.\[4\]
4. **`effort` is a valid subagent field.** The full subagent field list is `name`, `description`, `tools`, `disallowedTools`, `model`, `permissionMode`, `mcpServers`, `hooks`, `maxTurns`, `skills`, `memory`, `background`, `omitClaudeMd`, `effort`, `isolation`, `color`, `initialPrompt` and `experimental`.\[1\] Effort options are `low`, `medium`, `high`, `xhigh` and `max`, and the available levels depend on the model.\[1\]\[4\]
5. **Routing can happen at definition time or call time.** The model is resolved in this order: per-invocation `model` parameter, then frontmatter `model`, then `CLAUDE_CODE_SUBAGENT_MODEL`, then the main conversation's model. The Agent tool also accepts a per-call `effort` parameter (v2.1.292+), and `CLAUDE_CODE_EFFORT_LEVEL` overrides both.\[1\]\[5\] The orchestrator can therefore escalate one package from Haiku to Sonnet without editing files.
6. **Plugin subagents ignore `hooks`, `mcpServers` and `permissionMode`.** This is a security rule.\[1\] The kit puts guardrails in the plugin's `hooks/hooks.json`, which does apply, and in a recommended project `settings.json`.\[1\]
7. **Worktree isolation branches from your default branch, not HEAD.** The docs say worktrees are "branched by default from your default branch rather than the parent session's `HEAD`" unless `worktree.baseRef` is `"head"`. A worktree with no changes is cleaned up; one with changes stays on disk.\[1\]\[6\] The Agent result reports `worktreePath` and `worktreeBranch`.\[5\] Two consequences: the kit tells you to set `worktree.baseRef: "head"`, and every implementer checks it's on the right base commit before editing.
8. **Subagents can nest and run concurrently, so the kit turns nesting off for workers.** Subagents can spawn subagents up to three layers deep by default (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`). By default 20 can run at once (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`). Past that, the official "Subagents in the SDK" doc says the Agent tool refuses with "Concurrent subagent limit reached", and "Sessions with ultracode active are never refused." Background is the default in interactive sessions.\[7\] Subagents never get `AskUserQuestion`.\[1\] Every worker's `tools` list therefore leaves out `Agent`, and only the main-thread orchestrator asks the human anything.
9. **Ultracode itself, as documented:**
   - It's "a Claude Code setting that turns on automatic workflow orchestration for the session".\[2\]
   - `claude --effort ultracode` also sets effort to `xhigh` and needs v2.1.203+.\[2\]\[8\]
   - The `ultracode` keyword only works in prompts you type yourself.\[2\]
   - Workflows run up to 16 concurrent agents and 1,000 agents per run, and allow "No mid-run user input".\[2\]\[9\]
   - On Pro, the size guideline defaults to `small` (fewer than 5 agents).\[2\]

   This last point is why the kit's optional workflow script only covers the post-approval execute → review stage.
10. **The cost evidence argues for gates.**
   - Anthropic's research-system write-up (June 2025) found "multi-agent systems use about 15× more tokens than chats".
   - The same post warned that domains with "many dependencies between agents are not a good fit for multi-agent systems today," and it named "most coding tasks" as an example.
   - The Claude blog post "Building multi-agent systems: When and how to use them" (January 2026) adds that "multi-agent implementations typically use 3-10x more tokens than single-agent approaches for equivalent tasks."

   Hence the routing policy's "when NOT to fan out" rules.

---

## Repository / plugin tree

```text
senior-mode/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── .gitattributes
├── LICENSE
├── README.md
├── skills/
│   ├── senior-build/
│   │   ├── SKILL.md
│   │   ├── playbooks/
│   │   │   ├── 00-intake-clarify.md
│   │   │   ├── 01-explore.md
│   │   │   ├── 02-spec.md
│   │   │   ├── 03-plan-decompose.md
│   │   │   ├── 04-routing-policy.md
│   │   │   ├── 05-fanout-execute.md
│   │   │   ├── 06-review-verify.md
│   │   │   ├── 07-integrate-merge.md
│   │   │   └── 08-report.md
│   │   └── templates/
│   │       ├── spec.md
│   │       ├── work-package.md
│   │       ├── adr.md
│   │       ├── final-report.md
│   │       └── run-log.md
│   ├── senior-plan/SKILL.md
│   ├── senior-review/SKILL.md
│   ├── fanout/SKILL.md
│   └── retro/SKILL.md
├── agents/
│   ├── architect-planner.md
│   ├── explorer.md
│   ├── implementer-complex.md
│   ├── implementer-simple.md
│   ├── test-writer.md
│   ├── reviewer-adversarial.md
│   ├── security-reviewer.md
│   ├── docs-writer.md
│   └── integrator.md
├── hooks/
│   └── hooks.json
├── scripts/
│   ├── guard-bash.sh
│   ├── log-subagent.sh
│   ├── stop-gate.sh
│   └── trigger-phrase.sh
└── extras/
    ├── settings.recommended.json
    ├── settings.manual-hooks.json
    └── workflows/
        └── senior-fanout.js        # optional, NOT auto-loaded
```

The workflow lives in `extras/` on purpose. A plugin's `workflows/` folder is auto-loaded as `/senior-mode:<name>`, and the kit should stay opt-in.

---

## Files

### `.claude-plugin/plugin.json`

```json
{
  "$schema": "https://json.schemastore.org/claude-code-plugin-manifest.json",
  "name": "senior-mode",
  "displayName": "Senior Mode (ultracode-lite)",
  "version": "0.1.0",
  "description": "Senior-engineer build orchestrator: intake, explore, spec, plan, routed parallel subagents (model+effort per task), adversarial review, test gate, merge, report - with human STOP checkpoints.",
  "author": { "name": "YOUR NAME", "url": "https://github.com/YOUR-GH" },
  "homepage": "https://github.com/YOUR-GH/senior-mode",
  "repository": "https://github.com/YOUR-GH/senior-mode",
  "license": "MIT",
  "keywords": ["orchestration", "subagents", "planning", "code-review", "worktrees", "ultracode"]
}
```

The `$schema` URL is a convenience for editors. Claude Code ignores it at load time, and I haven't verified that this exact URL exists, so delete the line if your editor complains. `name` must not start with `claude-`, which `claude plugin validate` reserves.

### `.claude-plugin/marketplace.json`

```json
{
  "name": "senior-mode-market",
  "description": "Marketplace for the senior-mode Claude Code plugin",
  "owner": { "name": "YOUR NAME", "url": "https://github.com/YOUR-GH" },
  "plugins": [
    {
      "name": "senior-mode",
      "source": "./",
      "description": "Ultracode-lite: senior-engineer plan → fan-out → review → merge workflow built from skills and subagents"
    }
  ]
}
```

### `.gitattributes`

```text
*.sh   text eol=lf
*.md   text eol=lf
*.json text eol=lf
*.js   text eol=lf
```

This matters on Windows. CRLF line endings break `#!/usr/bin/env bash` hooks inside WSL.

### `README.md`

````markdown
# senior-mode — ultracode-lite for Claude Code

Type **`build like a senior: <goal>`** (or `/senior-build <goal>`) and Claude Code runs a
staff-engineer process: clarify → explore → spec → plan with work packages → **routed parallel
subagents** (right model + effort per task, git-worktree isolation) → adversarial review + test
gate → merge → report. It stops for your approval after the plan and before merge.

Built only from markdown skills/subagents + a few hook scripts. Clean-room, MIT.

## Install

### A. As a plugin (recommended)
```text
/plugin marketplace add YOUR-GH/senior-mode
/plugin install senior-mode@senior-mode-market
/reload-plugins
```
Shell equivalent: `claude plugin marketplace add YOUR-GH/senior-mode && claude plugin install senior-mode@senior-mode-market`.
Plugin skills are namespaced: `/senior-mode:senior-build` (the bare `/senior-build` also works unless another command uses that name).

### B. Manual copy into one project
```bash
cp -r skills/* .claude/skills/
cp -r agents/* .claude/agents/
mkdir -p .claude/hooks/senior-mode && cp scripts/*.sh .claude/hooks/senior-mode/ && chmod +x .claude/hooks/senior-mode/*.sh
# then merge extras/settings.manual-hooks.json and extras/settings.recommended.json into .claude/settings.json
```

### Required one-time settings (both install methods)
Plugins cannot set permissions or `worktree.baseRef`, so add this to `.claude/settings.json`
(full file: `extras/settings.recommended.json`):
```json
{ "worktree": { "baseRef": "head" } }
```
Without it, worktree subagents branch from your *default branch*, not your current branch.
Also: `echo ".claude/worktrees/" >> .gitignore` and `echo ".senior/" >> .gitignore` (or commit `.senior/<slug>/` as design docs — your choice).
Hooks need `jq` and `git` (`sudo apt install jq` in WSL). Run Claude Code inside WSL2, not PowerShell.

## Usage
```text
build like a senior: add JWT auth to the Express API with refresh tokens
/senior-build --auto add CSV export to the reports page
/senior-build --max-parallel 2 migrate the date utils from moment to date-fns
/senior-plan design a plugin system for the CLI          # spec + plan only
/fanout .senior/csv-export/plan.md                       # execute an approved plan
/senior-review                                           # adversarial review of current branch vs base
/retro                                                   # lessons + routing tweaks from the last run
```
Checkpoints: **STOP-1** clarifying questions, **STOP-2** spec/plan approval, **STOP-3** merge approval.
`--auto` skips STOP-1/2 (assumptions are logged) but never pushes and never merges into your base branch.

## How it imitates ultracode
| ultracode | senior-mode |
|---|---|
| Claude writes a JS workflow; runtime orchestrates | Skill playbooks; Claude orchestrates turn-by-turn |
| `agent()` / `parallel()` / `pipeline()` / `phase()` | Agent tool calls in parallel, grouped by phase/wave |
| xhigh effort for the session | Per-agent model + effort routing (opus/high only where it pays) |
| Adversarial verification agents | `reviewer-adversarial` + `security-reviewer` + test gate + bounded fix loop |
| No mid-run input | Human STOP checkpoints (or `--auto`) |
Optional: `extras/workflows/senior-fanout.js` gives true script-driven fan-out for the execute/review stage.

## Cost & usage notes
- Subagents draw on the same usage limits as your main session. Multi-agent work costs a multiple of a single session.
- Check spend with `/usage` (alias `/cost`), per-agent model/effort with `/tasks`.
- Agents pin `haiku` / `sonnet` / `opus` explicitly — never `inherit`, `fable`, or `best` — so a Fable main session can't silently make every worker bill usage credits.
- Default max parallelism 4; fix loops capped at 2 rounds; every agent has `maxTurns`.
- Recommended main-session model: `sonnet` (the orchestrator coordinates; Opus does the hard thinking inside `architect-planner` and `reviewer-adversarial`).

## Limitations
- Natural-language triggering is probabilistic; the bundled `UserPromptSubmit` hook makes the phrase deterministic, `/senior-build` always works.
- Turn-by-turn orchestration is less deterministic than a workflow script; interrupting restarts the turn.
- Plugin subagents ignore `hooks`, `mcpServers`, `permissionMode` (security rule) — guardrails live in `hooks/hooks.json` and your settings.
- Model aliases resolve differently on Bedrock/Vertex/Foundry; effort levels fall back on models that don't support them.

## License
MIT. Clean-room: written from public Claude Code documentation only.
````

### `skills/senior-build/SKILL.md`

````markdown
---
name: senior-build
description: Senior-engineer build orchestrator (ultracode-lite). Use when the user says "build like a senior", "senior mode", "senior build", "plan and fan out", "ultracode-lite", or asks to build a non-trivial feature/project end-to-end with spec, plan, parallel subagents, review and merge. Runs intake → explore → spec → plan → routed parallel fan-out → adversarial review + test gate → integrate → report, with human STOP checkpoints.
when_to_use: 'Trigger phrases: "build like a senior: <goal>", "do this like a senior engineer", "senior mode on", "spec it, plan it, fan it out". Do NOT use for one-line fixes, typos, renames, or pure questions.'
argument-hint: "[--auto] [--max-parallel N] <goal>"
allowed-tools: Read Grep Glob Bash(git status *) Bash(git log *) Bash(git diff *) Bash(git branch *) Bash(git rev-parse *) Bash(mkdir -p .senior*)
---

# Senior Build Orchestrator

You are the ORCHESTRATOR (tech lead). You coordinate; specialists do the work.
Goal and flags: $ARGUMENTS

## Non-negotiable rules
1. Follow the phases in order. Before starting a phase, Read its playbook (paths below) — do not work from memory.
2. You never write production code yourself. Delegate via the Agent tool to the subagents named in the routing policy.
3. Every delegation prompt must be self-contained (subagents cannot see this conversation): goal, the work package verbatim, base commit SHA, owned files, acceptance criteria, test command, and the required RESULT block format.
4. Subagent names: use `senior-mode:<agent>` when installed as a plugin, `<agent>` when copied to `.claude/agents/`. If unsure, check the available agent types before the first spawn.
5. Never pass `model: fable`, `model: best`, or `inherit`. Model/effort come from 04-routing-policy.md only.
6. Never `git push`, never merge into the user's base branch without STOP-3 approval, never delete branches you did not create.
7. Keep state on disk, not in your head: `.senior/<slug>/state.json` and `.senior/<slug>/run-log.md` (templates/run-log.md). Update state at every phase transition.
8. Budgets: max parallel subagents = `--max-parallel` or 4; fix loop ≤ 2 rounds per WP; one model escalation per WP; then STOP and ask.
9. If the task is small (one file, < ~50 lines, no design choice): say so and do a lean path — explorer → single implementer → reviewer — skipping spec/ADRs. Ask first unless `--auto`.

## Modes
- Default: interactive with STOP-1, STOP-2, STOP-3.
- `--auto` in arguments: skip STOP-1 and STOP-2 (log every assumption in the spec under "Assumptions"); still stop at STOP-3 before merging into the base branch. Never push.

## Phase map (Read each file when you reach it)
| # | Phase | Playbook | Output | Gate |
|---|---|---|---|---|
| 0 | Intake & clarify | `${CLAUDE_SKILL_DIR}/playbooks/00-intake-clarify.md` | `intake.md`, branch, state.json | **STOP-1** |
| 1 | Explore | `${CLAUDE_SKILL_DIR}/playbooks/01-explore.md` | `explore.md` | — |
| 2 | Spec + ADRs + risks | `${CLAUDE_SKILL_DIR}/playbooks/02-spec.md` | `spec.md`, `adr/ADR-*.md` | — |
| 3 | Plan & decompose | `${CLAUDE_SKILL_DIR}/playbooks/03-plan-decompose.md` | `plan.md`, `wp/WP-*.md` | **STOP-2** |
| 4 | Routing | `${CLAUDE_SKILL_DIR}/playbooks/04-routing-policy.md` | routing table in plan.md | — |
| 5 | Fan-out & execute | `${CLAUDE_SKILL_DIR}/playbooks/05-fanout-execute.md` | WP branches + RESULT blocks | — |
| 6 | Review & verify | `${CLAUDE_SKILL_DIR}/playbooks/06-review-verify.md` | `review.md`, gate result | test gate |
| 7 | Integrate & merge | `${CLAUDE_SKILL_DIR}/playbooks/07-integrate-merge.md` | merged senior branch | **STOP-3** |
| 8 | Report | `${CLAUDE_SKILL_DIR}/playbooks/08-report.md` | `report.md` | — |

Templates: `${CLAUDE_SKILL_DIR}/templates/` — spec.md, work-package.md, adr.md, final-report.md, run-log.md.

## STOP checkpoint format (use exactly)
```
=== STOP-<n>: <title> ===
Summary: <3-6 bullets>
Artifacts: <paths>
Decision needed: approve | edit <what> | abort
Estimated next-phase cost: <#agents, models, rough size S/M/L>
```
Then wait for the user. Use AskUserQuestion for multiple-choice decisions when available.

## state.json contract
```json
{"slug":"csv-export","phase":"intake|explore|spec|plan|awaiting-approval|execute|review|integrate|report|done|aborted",
 "mode":"interactive|auto","base_branch":"main","senior_branch":"senior/csv-export","base_sha":"<sha>",
 "max_parallel":4,"gate":"pending|passed|failed","wps":{"WP-1":{"status":"todo|running|done|failed|blocked","branch":null,"fix_rounds":0,"escalated":false}}}
```
The Stop hook reads `phase` and `gate`: while phase is execute/review/integrate and gate ≠ passed, it will remind you to verify before ending your turn.

## Finish
End with the final report (phase 8) and set phase to `done`. If aborted, set `aborted`, summarize what exists and how to clean up worktrees/branches.
````

### `skills/senior-build/playbooks/00-intake-clarify.md`

```markdown
# 00 — Intake & Clarify

Purpose: turn a one-line goal into an unambiguous problem statement before spending tokens.

## Steps
1. Parse $ARGUMENTS: flags (`--auto`, `--max-parallel N`) and the goal text. Derive `slug` (kebab-case, ≤ 5 words).
2. Preflight (run, don't guess):
   - `git rev-parse --is-inside-work-tree` — if not a git repo, STOP: worktree isolation needs git; offer `git init` + initial commit.
   - `git status --porcelain` — if dirty, STOP and ask: commit, stash, or abort. Never auto-stash.
   - Record `base_branch` (`git rev-parse --abbrev-ref HEAD`) and `base_sha` (`git rev-parse HEAD`).
3. Create `.senior/<slug>/` and `state.json` (phase `intake`), `run-log.md` from template.
4. Create and switch to `senior/<slug>` from the current HEAD (`git switch -c senior/<slug>`). Update state.
5. Draft up to 5 clarifying questions, only where the answer changes the design. Cover: scope boundaries (in/out), users & interfaces, non-functional needs (perf, security, compat), constraints (stack, deps allowed), definition of done & how to verify.
6. Write `.senior/<slug>/intake.md`:
   - Goal (1 sentence), Context, Open questions, Proposed defaults (your best answer to each question).

## Gate — STOP-1
- Interactive: present questions with proposed defaults; wait. Record answers in intake.md.
- `--auto`: accept proposed defaults, record them as "Assumptions (auto mode)".
- Skip STOP-1 entirely if there are zero design-relevant questions; say so.

## Exit criteria
intake.md complete; branch created; state.phase = `explore`.
```

### `skills/senior-build/playbooks/01-explore.md`

````markdown
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
````

### `skills/senior-build/playbooks/02-spec.md`

```markdown
# 02 — Spec, ADRs, Risks

Purpose: a reviewable contract of WHAT and WHY before HOW.

## Delegate
One `architect-planner` call (opus/high). Prompt must include: intake.md and explore.md contents verbatim, the template path `${CLAUDE_SKILL_DIR}/../senior-build/templates/spec.md` and `adr.md`, and the output paths below. The architect writes ONLY under `.senior/<slug>/`.

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
```

### `skills/senior-build/playbooks/03-plan-decompose.md`

````markdown
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
````

### `skills/senior-build/playbooks/04-routing-policy.md`

```markdown
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
```

### `skills/senior-build/playbooks/05-fanout-execute.md`

````markdown
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
````

### `skills/senior-build/playbooks/06-review-verify.md`

````markdown
# 06 — Adversarial Review, Test Gate, Bounded Fix Loop

## 1. Test gate (cheap, first)
For each `done` WP branch: run its `test_command` in its worktree path (or ask the integrator to). Any failure → straight to fix loop; skip expensive review until green.

## 2. Reviews (parallel, read-only)
Spawn in one message:
- `reviewer-adversarial` (opus/high) — once per wave, covering all WP diffs (`git diff <base_sha>..<branch>` per branch) against spec.md and the WPs' acceptance criteria.
- `security-reviewer` (sonnet/medium) — only if any WP risk=H or touches auth, input parsing, file/OS calls, secrets, deps, network.

Review prompt must include: spec.md FR/NFR/AT list, the WP files, the branch names + base_sha, and this checklist:

### Adversarial checklist
- Correctness: does the code actually satisfy each AT? Try to construct a failing input for each.
- Edge cases: empty/null, boundaries, unicode, large inputs, concurrency/re-entrancy, time zones, partial failure.
- Contracts: signatures/types match spec exactly; no silent breaking change to public API.
- Tests: do tests assert behaviour (not implementation)? Would they fail if the code were wrong? Any skipped/flaky tests?
- Scope: changes outside owned_files; dead code; debug leftovers; TODOs without issue.
- Errors: swallowed exceptions, missing error paths, misleading messages, resource leaks.
- Consistency with codebase conventions and ADRs.
- Cross-WP integration: incompatible assumptions between branches.

### Required return
```
REVIEW
{"verdict":"approve|request_changes|block",
 "findings":[{"id":"F-1","severity":"blocker|major|minor|nit","wp":"WP-2","file":"src/x.ts","line":42,
   "claim":"...","evidence":"failing input / reasoning / command output","fix":"concrete change"}],
 "ats_unverified":["AT-4"]}
```
Rule for reviewers: every blocker/major must include evidence; claims without evidence are downgraded to minor.

## 3. Bounded fix loop
- Group blocker+major findings by WP. Send to the WP's original subagent (resume if possible) or a new one of the same type, on the same branch: "Fix these findings; re-run tests; commit; return RESULT".
- After each fix round, re-run test gate and a *targeted* re-review (same reviewer, only the findings + new diff).
- Max 2 rounds per WP → then escalate once per 04 → then STOP and ask the human with the unresolved findings.
- Minor/nit: batch into the report as follow-ups; do not loop on them.

## 4. Gate decision
gate = `passed` when: all WP tests green, no open blocker/major, every AT either verified or explicitly waived by the human. Write `.senior/<slug>/review.md` (findings table + resolution). Update state.gate.
````

### `skills/senior-build/playbooks/07-integrate-merge.md`

```markdown
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
```

### `skills/senior-build/playbooks/08-report.md`

```markdown
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

Set state.phase = `done`. Suggest `/retro` if the run had escalations or > 1 fix round.
```

### `skills/senior-build/templates/spec.md`

```markdown
# Spec: <title>  (slug: <slug>)
Status: draft | approved   Mode: interactive | auto   Base: <branch>@<sha>

## 1. Problem & context
## 2. Goals
## 3. Non-goals
## 4. Users & interfaces
## 5. Functional requirements
- FR-1: <testable statement>
## 6. Non-functional requirements
- NFR-1: <measurable bar>
## 7. Contracts (exact)
```text
<signatures / routes / schemas / CLI flags>
```
## 8. Acceptance tests
| AT | Covers | How to run | Expected |
|---|---|---|---|
| AT-1 | FR-1 | `<command or test name>` | <observable result> |
## 9. Risk register
| ID | Risk | L | I | Mitigation | Owner WP |
|---|---|---|---|---|---|
## 10. Assumptions
## 11. Open questions
## 12. ADRs
- ADR-001 <title> → adr/ADR-001-<slug>.md
```

### `skills/senior-build/templates/work-package.md`

```markdown
# WP-<n>: <title>
type: impl-complex | impl-simple | tests | docs | foundation
complexity: S | M | L    risk: L | M | H    wave: <k>
agent: <agent>   model: <haiku|sonnet|opus>   effort: <low|medium|high>   isolation: worktree | none
depends_on: [WP-x]

## Objective
<one paragraph: what this WP delivers and why>

## Owned files (only these may be edited/created)
- path/to/file.ext — create | modify

## Reads (read-only context)
- path/to/contract.ext

## Interfaces / contracts
- Provides: <exact signature/types>
- Consumes: <exact signature/types, from spec §7 or WP-0>

## Acceptance criteria
- [ ] AT-<k>: <observable result>  — verify with `<command>`
- [ ] Lint/typecheck clean: `<command>`

## Test command
`<command scoped to this WP>`

## Out of scope
- <explicitly excluded work>

## Notes for implementer
- Patterns to copy: <file:line>
- Pitfalls: <known risks>
```

### `skills/senior-build/templates/adr.md`

```markdown
# ADR-<NNN>: <decision title>
Status: proposed | accepted | superseded by ADR-<x>
Date: <YYYY-MM-DD>   Run: <slug>

## Context
<forces, constraints, what we learned in explore>

## Options considered
1. <option> — pros / cons
2. <option> — pros / cons

## Decision
<chosen option, stated imperatively>

## Consequences
- Positive:
- Negative / accepted risks:
- Follow-ups:
```

### `skills/senior-build/templates/final-report.md`

```markdown
# Senior Build Report: <title>
Outcome: <merged | branch ready: senior/<slug> | partial | aborted>
Base: <branch>@<sha> → Head: <sha>   Mode: <interactive|auto>

## What was built
| FR | WP | Commit(s) | Notes |
|---|---|---|---|

## Acceptance tests
| AT | Status (pass/fail/waived) | Evidence |
|---|---|---|

## Decisions (ADRs) & assumptions
## Review summary
- Findings: <n blocker / n major / n minor> — resolved: <n>; open minors: <list>
## Residual risks & follow-ups
## Execution log
| Agent | Model | Effort | WP | Status | Fix rounds | Escalated |
|---|---|---|---|---|---|---|
## Usage notes
- Subagent runs: haiku <n>, sonnet <n>, opus <n>. Check `/usage` for actual consumption.
## Cleanup
- Worktrees: <list or none>  Branches: <list>
```

### `skills/senior-build/templates/run-log.md`

```markdown
# Run log: <slug>
Started: <timestamp>  Mode: <mode>  Max parallel: <n>  Base: <branch>@<sha>

## Phase transitions
| Time | From → To | Note |
|---|---|---|

## Agent runs
| # | Agent | Model/Effort | WP/Task | Status | Rounds | Branch | Notes |
|---|---|---|---|---|---|---|---|

## Decisions & human checkpoints
| Checkpoint | Decision | By |
|---|---|---|

## Hook log
Machine log of subagent starts/stops: `.senior/run-log.jsonl` (written by hooks).
```

### `skills/senior-plan/SKILL.md`

```markdown
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
```

### `skills/senior-review/SKILL.md`

```markdown
---
name: senior-review
description: Adversarial senior review of the current branch (or a given branch/PR range) against its spec or stated intent, with evidence-backed findings and an optional bounded fix loop.
argument-hint: "[base-ref] [--fix]"
disable-model-invocation: true
---

Review target: $ARGUMENTS (default base: the merge-base with the default branch).

1. Determine range: `git merge-base HEAD <base>` → `git diff --stat <mb>..HEAD`. If a `.senior/*/spec.md` matches the branch, use it as the contract; otherwise ask the user for the intent in one sentence.
2. Read `${CLAUDE_SKILL_DIR}/../senior-build/playbooks/06-review-verify.md` and apply sections 1, 2 and 4 (test gate, reviews, gate decision).
3. Spawn `reviewer-adversarial` (and `security-reviewer` if the diff touches auth, parsing, secrets, deps, network) in parallel with the range, the contract, and the checklist.
4. Print findings sorted by severity with evidence. Write `.senior/review-<short-sha>.md`.
5. Only if `--fix` was passed: run the bounded fix loop (section 3) using implementer-complex on the current branch (no worktree), max 2 rounds.
```

### `skills/fanout/SKILL.md`

```markdown
---
name: fanout
description: Execute an existing senior-mode plan (plan.md with work packages) via routed parallel subagents, review, and integration.
argument-hint: "<path/to/plan.md> [--max-parallel N] [--auto]"
disable-model-invocation: true
---

Plan: $ARGUMENTS

1. Read the plan and its `wp/` files. Validate: machine-readable JSON block present, no file owned twice, DAG acyclic, every WP has acceptance criteria and a test command. If invalid, list problems and stop.
2. Load/restore `.senior/<slug>/state.json` (create if missing; base_sha = current HEAD on `senior/<slug>`; create that branch if absent).
3. Confirm with the user (unless `--auto`): waves, agents/models, max parallel. This is STOP-2.
4. Read and follow in order:
   - `${CLAUDE_SKILL_DIR}/../senior-build/playbooks/04-routing-policy.md`
   - `${CLAUDE_SKILL_DIR}/../senior-build/playbooks/05-fanout-execute.md`
   - `${CLAUDE_SKILL_DIR}/../senior-build/playbooks/06-review-verify.md`
   - `${CLAUDE_SKILL_DIR}/../senior-build/playbooks/07-integrate-merge.md`
   - `${CLAUDE_SKILL_DIR}/../senior-build/playbooks/08-report.md`
5. Resume-safe: skip WPs whose state is `done` and whose branch is already merged into `senior/<slug>`.
```

### `skills/retro/SKILL.md`

```markdown
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
```

### `agents/architect-planner.md`

```markdown
---
name: architect-planner
description: Senior architect for senior-mode runs. Use to write specs, ADRs, risk registers and work-package decompositions with file ownership. Writes only under .senior/.
tools: Read, Grep, Glob, Bash, Write, Edit
model: opus
effort: high
maxTurns: 30
color: purple
---

You are a principal engineer writing design artifacts for a team of parallel implementers who cannot ask you questions.

Rules:
- Write ONLY inside `.senior/<slug>/` (spec.md, adr/, plan.md, wp/). Never modify source code, configs or lockfiles.
- Use Bash only for read-only inspection (ls, git log/show/diff, running the existing test/lint command to learn baseline). No installs.
- Prefer boring, reversible designs that match existing conventions. Every non-obvious choice gets an ADR with options and consequences.
- Requirements must be testable; contracts must be exact (types, signatures, routes, schemas).
- Decompose for parallelism: disjoint owned_files, hotspots isolated in WP-0, contracts defined before consumers, DAG waves, WP ≤ ~300 changed lines.
- Fill model/effort/agent per the routing policy text you are given; justify any deviation in one line.
- Flag uncertainty explicitly under "Open questions" rather than guessing silently.

Finish with:
ARCH-RESULT
{"files_written":["..."],"wp_count":n,"waves":k,"high_risks":["R-2"],"open_questions":["..."]}
```

### `agents/explorer.md`

```markdown
---
name: explorer
description: Fast, cheap, read-only codebase explorer for senior-mode. Use for file discovery, pattern finding, build/test command discovery, and hotspot mapping.
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit, NotebookEdit
model: haiku
effort: low
maxTurns: 20
color: cyan
---

You answer one exploration question precisely and cheaply.

- Read-only. Bash only for read-only commands: ls, find, git log/show/grep, cat of manifests, running `--help`. Never install, write, or delete.
- Search before reading: Glob/Grep to locate, then Read only the relevant ranges.
- Report facts with file paths; no design proposals.
- Stop as soon as the question is answered; do not exhaustively read the repo.
- Return exactly the EXPLORE-RESULT format given in your task. Keep it under 80 lines.
```

### `agents/implementer-complex.md`

```markdown
---
name: implementer-complex
description: Senior implementer for complex or risky work packages (new abstractions, cross-module changes, concurrency, state, security-sensitive code). Works in an isolated git worktree and commits there.
tools: Read, Grep, Glob, Edit, Write, Bash
model: sonnet
effort: medium
maxTurns: 40
isolation: worktree
color: blue
---

You implement exactly one work package to production quality.

Process:
1. Verify base commit as instructed in the task (merge-base check; `git checkout -B` to BASE_SHA if needed) before any edit.
2. Read the WP, its contracts and the patterns it names. Plan briefly (≤ 8 bullets) in your head; do not write plan files.
3. Write tests for the acceptance criteria first when practical; then implement.
4. Edit only owned_files. Needing another file = stop and report status "blocked" with the reason.
5. Run the WP test command plus lint/typecheck if given. Iterate until green or until you can prove the failure is pre-existing/out of scope.
6. Commit in your worktree (`git add -A && git commit -m "<WP-id>: <title>"`). Never push, never merge, never rewrite history outside your worktree branch.

Quality bar: match existing conventions; handle error paths; no debug leftovers; no new dependencies unless the WP allows it.
Return the RESULT JSON block exactly as specified in your task.
```

### `agents/implementer-simple.md`

```markdown
---
name: implementer-simple
description: Low-cost implementer for mechanical work packages that follow an existing pattern (boilerplate, config, renames, glue code, simple CRUD). Works in an isolated git worktree.
tools: Read, Grep, Glob, Edit, Write, Bash
model: haiku
effort: low
maxTurns: 20
isolation: worktree
color: green
---

You perform a mechanical change by copying an existing pattern exactly.

- First verify the base commit as instructed in the task.
- Find the reference pattern named in the WP; mirror its structure, naming and error handling.
- Edit only owned_files. If the task needs design decisions or other files, stop with status "blocked" — do not improvise.
- Run the WP test command. If it fails twice for reasons you don't understand, stop with status "partial" and paste the failing output.
- Commit in your worktree: `git add -A && git commit -m "<WP-id>: <title>"`. Never push or merge.
- Return the RESULT JSON block exactly as specified.
```

### `agents/test-writer.md`

```markdown
---
name: test-writer
description: Writes and repairs tests for senior-mode work packages - unit test scaffolding by default; integration/property tests when the orchestrator escalates the model. Works in an isolated worktree.
tools: Read, Grep, Glob, Edit, Write, Bash
model: haiku
effort: low
maxTurns: 25
isolation: worktree
color: yellow
---

You write tests that would FAIL if the code were wrong.

- Verify the base commit as instructed.
- Map each acceptance criterion to ≥ 1 test; name tests after the behaviour (`returns_404_when_user_missing`).
- Cover edge cases listed in the WP: empty, boundary, invalid input, error paths.
- Use the project's existing framework, fixtures and layout; no new test dependencies unless allowed.
- Never weaken assertions or skip tests to get green. If production code is wrong, report it under `risks` with the failing test name.
- Edit only owned test files. Run them; commit in your worktree; return the RESULT block.
```

### `agents/reviewer-adversarial.md`

```markdown
---
name: reviewer-adversarial
description: Adversarial, evidence-driven code reviewer for senior-mode. Use after work packages complete to try to break them against the spec and acceptance tests. Read-only.
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit, NotebookEdit
model: opus
effort: high
maxTurns: 25
color: red
---

Your job is to find real defects before users do. Assume the code is wrong until evidence says otherwise, but report only what you can support.

- Read-only. Bash for: git diff/log/show, running tests and small ad-hoc checks (e.g. a one-off script via the project's runtime in a temp dir). Never edit tracked files, never commit.
- For each acceptance test: attempt to construct a counterexample input; run it when cheap.
- Apply the checklist you are given (correctness, edge cases, contracts, test strength, scope, errors, conventions, cross-WP integration).
- Severity: blocker (wrong/unsafe, must fix), major (likely bug or missing AT), minor (quality), nit (style).
- Every blocker/major needs evidence: a failing input, command output, or precise line-level reasoning. No evidence → downgrade.
- Do not rewrite the code; give a concrete fix suggestion per finding.
Return the REVIEW JSON block exactly as specified.
```

### `agents/security-reviewer.md`

```markdown
---
name: security-reviewer
description: Read-only security reviewer for senior-mode diffs touching auth, input parsing, file/OS calls, secrets, dependencies or network code.
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit, NotebookEdit
model: sonnet
effort: medium
maxTurns: 20
color: orange
---

Review only the given diff range for exploitable issues.

Check: injection (SQL/command/path/template), authn/authz gaps and IDOR, input validation and deserialization, secrets in code/logs/tests, unsafe defaults, SSRF/open redirects, crypto misuse, dependency additions (pin, license, known-bad), error messages leaking internals, resource exhaustion.
- Read-only; Bash only for git diff/log and dependency listing commands. Never fetch from the network.
- Report each issue with: severity (blocker/major/minor), file:line, attack scenario in one sentence, evidence, fix.
- If nothing material is found, say so explicitly — do not pad.
Return the REVIEW JSON block exactly as specified in your task.
```

### `agents/docs-writer.md`

```markdown
---
name: docs-writer
description: Low-cost documentation writer for senior-mode (README sections, usage docs, changelog entries, docstrings). Works in an isolated worktree.
tools: Read, Grep, Glob, Edit, Write, Bash
model: haiku
effort: low
maxTurns: 15
isolation: worktree
color: pink
---

Write accurate, concise docs for what was actually built.

- Verify base commit as instructed. Read the spec contracts and the implemented code; document reality, not intent. If they differ, note it under `risks`.
- Match the repo's doc style; prefer runnable examples copied from tests.
- Edit only owned doc files. Commit in your worktree; return the RESULT block.
```

### `agents/integrator.md`

```markdown
---
name: integrator
description: Integration engineer for senior-mode. Merges work-package branches into the senior branch in order, resolves mechanical conflicts, runs the full suite, and reports regressions.
tools: Read, Grep, Glob, Edit, Write, Bash
model: sonnet
effort: medium
maxTurns: 30
color: purple
---

You work in the main checkout on the `senior/<slug>` branch only.

- Start: `git switch senior/<slug>`; require a clean status.
- Merge in the given order with `git merge --no-ff <branch> -m "merge <WP-id>: <title>"`.
- Conflicts: resolve only mechanical ones (imports, adjacent non-overlapping edits, lockfile regeneration via the project's tool). For semantic conflicts run `git merge --abort` and report both intents.
- After merging: run build, lint, typecheck, full tests. Compare against the provided baseline; list only new failures as regressions.
- Never push, never force, never reset, never merge into the base branch, never delete branches.
Return the INTEGRATION JSON block exactly as specified.
```

### `hooks/hooks.json`

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/trigger-phrase.sh", "timeout": 5 }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/guard-bash.sh", "timeout": 10 }
        ]
      }
    ],
    "SubagentStart": [
      {
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/log-subagent.sh", "timeout": 5 }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/log-subagent.sh", "timeout": 5 }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/stop-gate.sh", "timeout": 10 }
        ]
      }
    ]
  }
}
```

### `scripts/trigger-phrase.sh`

```bash
#!/usr/bin/env bash
# UserPromptSubmit: make "build like a senior" deterministic by injecting an instruction.
set -euo pipefail
input="$(cat)"
prompt="$(printf '%s' "$input" | jq -r '.prompt // .user_prompt // empty')"   # field name: see Verified facts
[ -z "$prompt" ] && exit 0
case "$prompt" in /*) exit 0 ;; esac   # explicit slash commands need no help
if printf '%s' "$prompt" | grep -Eiq 'build (it )?like a senior|senior[- ]mode|senior build|plan and fan out|ultracode-lite'; then
  jq -n '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",
    additionalContext:"The user requested senior mode. Invoke the senior-build skill (Skill tool) with the user prompt as its arguments and follow it exactly, starting at phase 00."}}'
fi
exit 0
```

### `scripts/guard-bash.sh`

```bash
#!/usr/bin/env bash
# PreToolUse(Bash): deny destructive or exfiltrating commands. Applies to main session AND subagents.
set -euo pipefail
input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
[ -z "$cmd" ] && exit 0

deny() {
  jq -n --arg r "senior-mode guard: $1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

shopt -s nocasematch
[[ "$cmd" =~ rm[[:space:]]+(-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r|--recursive)[[:space:]]+(/|~|\$HOME|\*|\.\.?)([[:space:]]|$) ]] && deny "recursive delete of root/home/cwd"
if [[ "${SENIOR_ALLOW_PUSH:-0}" != "1" && "$cmd" =~ git[[:space:]]+push ]]; then deny "git push is disabled (set SENIOR_ALLOW_PUSH=1 to allow)"; fi
[[ "$cmd" =~ git[[:space:]]+reset[[:space:]]+--hard ]] && deny "git reset --hard (use git checkout -B in a worktree instead)"
[[ "$cmd" =~ git[[:space:]]+clean[[:space:]]+-[a-z]*f ]] && deny "git clean -f"
[[ "$cmd" =~ git[[:space:]]+branch[[:space:]]+-D ]] && deny "force branch delete"
[[ "$cmd" =~ (curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z)?sh ]] && deny "pipe-to-shell"
[[ "$cmd" =~ (^|[[:space:];&|])sudo[[:space:]] ]] && deny "sudo"
[[ "$cmd" =~ chmod[[:space:]]+-R[[:space:]]+777 ]] && deny "chmod -R 777"
[[ "$cmd" =~ (mkfs|dd[[:space:]]+if=|:\(\)\{) ]] && deny "disk/fork-bomb command"
[[ "$cmd" =~ (cat|less|head|tail)[[:space:]].*\.env([[:space:]]|$) ]] && deny "reading .env secrets"
exit 0
```

### `scripts/log-subagent.sh`

```bash
#!/usr/bin/env bash
# SubagentStart / SubagentStop: append one JSON line per event to .senior/run-log.jsonl
set -euo pipefail
input="$(cat)"
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
mkdir -p "$root/.senior"
printf '%s' "$input" | jq -c --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{
  ts:$ts,
  event:(.hook_event_name // "unknown"),
  agent_type:(.agent_type // null),
  agent_id:(.agent_id // null),
  effort:(.effort // null),
  session_id:(.session_id // null),
  transcript:(.agent_transcript_path // null)
}' >> "$root/.senior/run-log.jsonl"
exit 0
```

### `scripts/stop-gate.sh`

```bash
#!/usr/bin/env bash
# Stop: if a senior-mode run is mid-execution and the gate hasn't passed, block ONCE with a reminder.
set -euo pipefail
input="$(cat)"
[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
state="$(ls -t "$root"/.senior/*/state.json 2>/dev/null | head -n1 || true)"
[ -z "$state" ] && exit 0
phase="$(jq -r '.phase // ""' "$state")"
gate="$(jq -r '.gate // "pending"' "$state")"
marker="$(dirname "$state")/.stop-reminded"
case "$phase" in
  execute|review|integrate)
    if [ "$gate" != "passed" ] && [ ! -f "$marker" ]; then
      touch "$marker"
      jq -n --arg p "$phase" '{decision:"block",
        reason:("senior-mode: run is in phase \"" + $p + "\" and the verification gate has not passed. Either continue (run tests / review per playbook 06), or if you are deliberately pausing for the human, set state.json phase to \"awaiting-approval\" and present a STOP checkpoint.")}'
      exit 0
    fi ;;
  *) rm -f "$marker" ;;
esac
exit 0
```

### `extras/settings.recommended.json`

```json
{
  "worktree": { "baseRef": "head" },
  "permissions": {
    "allow": [
      "Bash(git status *)", "Bash(git diff *)", "Bash(git log *)", "Bash(git show *)",
      "Bash(git add *)", "Bash(git commit *)", "Bash(git switch *)", "Bash(git merge *)",
      "Bash(git worktree list *)", "Bash(git rev-parse *)", "Bash(git merge-base *)",
      "Edit(.senior/**)", "Write(.senior/**)"
    ],
    "ask": ["Bash(git merge * main)", "Bash(git merge * master)", "Bash(git worktree remove *)"],
    "deny": [
      "Bash(git push *)", "Bash(rm -rf *)", "Bash(sudo *)", "Bash(curl * | sh)",
      "Read(./.env)", "Read(./.env.*)", "Read(./secrets/**)"
    ]
  },
  "env": {
    "CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH": "1"
  }
}
```

Two notes on this file. `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH: "1"` turns nesting off globally as a belt-and-braces measure, and it only applies once the file is merged into `.claude/settings.json`. Add your project's test commands, such as `Bash(npm test *)` or `Bash(pytest *)`, to `allow` as well. Otherwise background subagents will keep surfacing permission prompts.

### `extras/settings.manual-hooks.json` (manual install only; merge into `.claude/settings.json`)

```json
{
  "hooks": {
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "\"${CLAUDE_PROJECT_DIR}\"/.claude/hooks/senior-mode/trigger-phrase.sh", "timeout": 5 }] }],
    "PreToolUse": [{ "matcher": "Bash", "hooks": [{ "type": "command", "command": "\"${CLAUDE_PROJECT_DIR}\"/.claude/hooks/senior-mode/guard-bash.sh", "timeout": 10 }] }],
    "SubagentStart": [{ "hooks": [{ "type": "command", "command": "\"${CLAUDE_PROJECT_DIR}\"/.claude/hooks/senior-mode/log-subagent.sh", "timeout": 5 }] }],
    "SubagentStop": [{ "hooks": [{ "type": "command", "command": "\"${CLAUDE_PROJECT_DIR}\"/.claude/hooks/senior-mode/log-subagent.sh", "timeout": 5 }] }],
    "Stop": [{ "hooks": [{ "type": "command", "command": "\"${CLAUDE_PROJECT_DIR}\"/.claude/hooks/senior-mode/stop-gate.sh", "timeout": 10 }] }]
  }
}
```

### `extras/workflows/senior-fanout.js` (optional, for true script-driven fan-out)

To use it, copy the file to `.claude/workflows/senior-fanout.js`. It requires dynamic workflows to be on; on Pro, turn them on from `/config`. After STOP-2, ask Claude: "run /senior-fanout with args from .senior/<slug>/plan.md JSON". The script only covers execute → review → bounded fix, because workflows can't take mid-run human input. Merging (STOP-3) stays in the skill.

```javascript
export const meta = {
  name: 'senior-fanout',
  description: 'senior-mode: execute approved work packages in parallel, adversarially review, bounded fix loop',
  phases: ['Execute', 'Review', 'Fix'],
}

// args (passed by Claude from plan.md JSON block):
// { slug, baseSha, maxFixRounds?: 2, wps: [{ id, title, agent, model, effort, wpText, testCommand }] }
// NOTE: Date.now()/Math.random() throw inside workflows - do not use them.
const A = args || {}
const maxFix = A.maxFixRounds ?? 2

const resultSchema = {
  type: 'object',
  required: ['wp', 'status', 'branch', 'tests'],
  properties: {
    wp: { type: 'string' },
    status: { type: 'string', enum: ['done', 'partial', 'blocked'] },
    branch: { type: 'string' },
    head_sha: { type: 'string' },
    files_changed: { type: 'array', items: { type: 'string' } },
    tests: { type: 'object', properties: { command: { type: 'string' }, passed: { type: 'boolean' }, summary: { type: 'string' } } },
    deviations: { type: 'array', items: { type: 'string' } },
  },
}

const reviewSchema = {
  type: 'object',
  required: ['verdict', 'findings'],
  properties: {
    verdict: { type: 'string', enum: ['approve', 'request_changes', 'block'] },
    findings: { type: 'array', items: { type: 'object', properties: {
      id: { type: 'string' }, severity: { type: 'string' }, wp: { type: 'string' },
      file: { type: 'string' }, claim: { type: 'string' }, evidence: { type: 'string' }, fix: { type: 'string' } } } },
  },
}

const wpPrompt = (wp, extra = '') => `You are executing ONE work package (${wp.id}) for senior-mode run "${A.slug}".
Act as the "${wp.agent}" role. BASE_SHA: ${A.baseSha}
First run: git merge-base --is-ancestor ${A.baseSha} HEAD || git checkout -B "$(git rev-parse --abbrev-ref HEAD)" ${A.baseSha}
Edit ONLY the owned files listed. Run: ${wp.testCommand}. Commit your work in your worktree. Never push or merge.
WORK PACKAGE:
${wp.wpText}
${extra}
Return JSON matching the schema.`

phase('Execute')
log(`senior-fanout: ${A.wps.length} work packages`)
let results = await pipeline(A.wps, wp =>
  agent(wpPrompt(wp), {
    label: wp.id,                 // documented in the workflows example
    schema: resultSchema,         // documented
    model: wp.model,              // UNVERIFIED option name: docs say "a model the script names for a stage" counts as per-invocation model
    effort: wp.effort,            // UNVERIFIED option
    isolation: 'worktree',        // UNVERIFIED on the workflows page (mentioned in hooks docs/changelog); remove if rejected
  }),
)
results = results.filter(Boolean)

phase('Review')
const review = await agent(
  `Adversarially review these senior-mode WP branches against their acceptance criteria. Read-only: use git diff ${A.baseSha}..<branch>.
Branches: ${JSON.stringify(results.map(r => ({ wp: r.wp, branch: r.branch, tests: r.tests })))}
Every blocker/major finding needs concrete evidence.`,
  { label: 'adversarial-review', schema: reviewSchema, model: 'opus', effort: 'high' }, // model/effort: UNVERIFIED option names
)

phase('Fix')
let open = (review?.findings || []).filter(f => f.severity === 'blocker' || f.severity === 'major')
for (let round = 1; round <= maxFix && open.length > 0; round++) {
  const byWp = [...new Set(open.map(f => f.wp))]
  const fixes = await pipeline(byWp, id => {
    const wp = A.wps.find(w => w.id === id)
    const r = results.find(x => x.wp === id)
    if (!wp || !r) return null
    return agent(
      wpPrompt(wp, `FIX ROUND ${round}. Work on branch ${r.branch} (git switch ${r.branch}). Fix ONLY these findings:\n${JSON.stringify(open.filter(f => f.wp === id))}`),
      { label: `${id}-fix-${round}`, schema: resultSchema, model: wp.model },
    )
  })
  log(`fix round ${round}: ${fixes.filter(Boolean).length} WPs updated`)
  const recheck = await agent(
    `Re-check ONLY these previously reported findings on the updated branches and report which remain: ${JSON.stringify(open)}`,
    { label: `recheck-${round}`, schema: reviewSchema, model: 'opus', effort: 'high' },
  )
  open = (recheck?.findings || []).filter(f => f.severity === 'blocker' || f.severity === 'major')
}

return { slug: A.slug, results, openFindings: open, gate: open.length === 0 && results.every(r => r.tests?.passed) ? 'passed' : 'failed' }
```

---

## How to test the kit

**Sample project.** Create a tiny Python CLI, `tasklite`, of about 150 lines: `tasklite/models.py`, `storage.py` (a JSON file) and `cli.py` (argparse with `add` and `list`), plus `tests/` using pytest. Commit it on `main`.

**Run this prompt:**
```text
build like a senior: add tags, due dates, and `list --overdue` to tasklite, plus `export --json`
```

**Expected behaviour:**
1. The skill triggers (watch for the skill load line). If it doesn't, the `UserPromptSubmit` hook injects the instruction.
2. STOP-1 asks a few questions with defaults, such as the date format and whether tags are case-sensitive.
3. One or two `explorer` runs on Haiku (check the model and effort with `/tasks`).\[1\]
4. `architect-planner` on Opus/high writes `spec.md`, one or two ADRs (for example "ISO-8601 dates in storage"), and about four WPs:
   - WP-0: model/storage schema (foundation, sonnet)
   - WP-1: CLI flags (sonnet)
   - WP-2: JSON export (haiku)
   - WP-3: README (haiku)
5. STOP-2 shows the waves (WP-0 first, then WP-1, WP-2 and WP-3 in parallel), the cost estimate, and no file owned twice.
6. Parallel worktree agents appear. `git worktree list` shows them, and `.senior/run-log.jsonl` gets start/stop lines.
7. `reviewer-adversarial` produces at least one evidence-backed finding (an invalid date or timezone edge case), followed by a single fix round.
8. The integrator merges into `senior/<slug>`, then STOP-3 with a diffstat and a green suite. Finally `report.md` is written.

**Guardrail checks:**
- Ask Claude to `git push`; the hook should deny it.
- Interrupt during execute and try to end the turn; the Stop hook should remind you once.

**Lightweight comparison with `/effort ultracode`:**
1. Make two clean clones of `tasklite`, each at the same commit.
2. In clone A, run the prompt above. In clone B, run `/effort ultracode` and then `ultracode: <same goal>`.
3. Record for each run:
   - wall-clock time, from your clock;
   - `/usage` before and after (`/cost` is an alias);
   - agent count (`/tasks` for A, `/workflows` for B);
   - human interventions.
4. Score each result on a 10-point checklist: all ATs pass, overdue edge cases handled (no due date, today, timezone), no file churn outside scope, tests fail when the code is broken, README updated, no new dependencies, clean commit history, ADR or decision trail present, no regressions, reviewer findings resolved.
5. Run each variant three times, because single runs are noisy.

---

## Verified facts & version notes (checked against code.claude.com/docs, October 2026)

| Claim used by the kit | Source | Status |
|---|---|---|
| Skills live in `~/.claude/skills/<name>/SKILL.md`, `.claude/skills/<name>/SKILL.md`, or `<plugin>/skills/<name>/SKILL.md` (namespaced `/plugin-name:skill-name`)\[4\] | https://code.claude.com/docs/en/skills | Verified\[3\] |
| `.claude/commands/*.md` merged into skills; same frontmatter except `name`/`paths`\[4\] | skills doc | Verified\[3\] |
| Skill fields incl. `when_to_use`, `argument-hint`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `model`, `effort`, `context: fork`, `agent`, `background`, `hooks`, `paths`; unknown fields silently ignored; 1,536-char listing cap\[4\] | skills doc | Verified |
| `$ARGUMENTS`, `$N`, `${CLAUDE_SKILL_DIR}`, `${CLAUDE_PROJECT_DIR}`, `${CLAUDE_PLUGIN_ROOT}` substitutions\[4\] | skills doc | Verified |
| Supporting files load only when Claude reads them via references in SKILL.md; keep SKILL.md < 500 lines | skills doc (via research subagent) | Verified |
| Skill `model` override lasts only for the current turn\[4\] | skills doc | Verified (why the kit sets models on agents, not on the skill) |
| Subagent fields incl. `effort`, `maxTurns`, `isolation: worktree`, `skills`, `memory`, `background`, `omitClaudeMd`, `color`\[1\] | https://code.claude.com/docs/en/sub-agents | Verified\[3\] |
| Model aliases `sonnet`/`opus`/`haiku`/`fable`/`inherit`; resolution order per-call → frontmatter → `CLAUDE_CODE_SUBAGENT_MODEL` → main model\[1\] | sub-agents doc | Verified |
| Agent tool inputs `description`, `prompt`, `subagent_type`, `model`, `effort`, `run_in_background`, `name`, `isolation`; result has `worktreePath`/`worktreeBranch` | https://code.claude.com/docs/en/agent-sdk/python | Verified (SDK reference; the CLI tools-reference page couldn't be fetched) |
| Per-invocation `effort` parameter requires v2.1.292+\[1\] | sub-agents doc | Verified |
| Plugin subagents ignore `hooks`, `mcpServers`, `permissionMode` | sub-agents doc | Verified |
| Nesting allowed to depth 3 by default (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`); omit `Agent` from `tools` to block\[1\] | sub-agents doc | Verified |
| Concurrent subagent cap of 20 (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`); not enforced with ultracode on\[2\]\[10\] | sub-agents doc snippets + workflows doc | Partly verified (the number comes from search snippets and changelog-based articles) |
| Subagents never get `AskUserQuestion`; background subagents have a reduced tool set\[1\] | sub-agents doc | Verified |
| Worktrees branch from the default branch unless `worktree.baseRef: "head"`; unchanged worktrees auto-removed\[6\] | sub-agents + https://code.claude.com/docs/en/worktrees | Verified |
| Parent merge strategy for worktree branches | — | Not documented: the kit's `git merge --no-ff` is a design choice |
| Effort levels low/medium/high/xhigh/max; Opus 5.5, Sonnet 5.5, Haiku 5.5 support all five; unsupported levels fall back\[8\] | https://code.claude.com/docs/en/model-config | Verified |
| On the Anthropic API, `opus`→Opus 5.5, `sonnet`→Sonnet 5.5, `haiku`→Haiku 5.5; other providers differ\[8\] | model-config | Verified |
| `best` = Fable where available; Fable can bill usage credits\[8\] | model-config | Verified |
| Opus 5.5 defaults to medium effort\[11\] | claudefa.st (secondary) | Unverified in official docs |
| Ultracode: session setting, `/effort ultracode`, `claude --effort ultracode` (v2.1.203+, sets xhigh), keyword only in human-typed prompts | https://code.claude.com/docs/en/workflows | Verified |
| Workflows: JS with `meta` first, `agent()`/`pipeline()`/`parallel()`/`phase()`/`log()`/`args`; 16 concurrent, 1,000 per run; no mid-run input; `schema`, `label`, `stallMs` options | workflows doc | Verified |
| `agent()` options `model`, `effort`, `isolation`; exact `parallel()` signature | — | Unverified (marked in the JS) |
| Plugin manifest at `.claude-plugin/plugin.json`, only `name` required; components at plugin root; `hooks/hooks.json` with top-level `"hooks"` wrapper; plugin `settings.json` honours only `agent`/`subagentStatusLine`\[12\] | https://code.claude.com/docs/en/plugins-reference | Verified |
| `marketplace.json` requires `name`, `owner`, `plugins[]` with `name`+`source`; `"source": "./"` for same-repo\[13\]\[14\] | https://code.claude.com/docs/en/plugins/publish, /plugin-marketplaces | Verified |
| Install via `/plugin marketplace add owner/repo` then `/plugin install name@marketplace`; `claude plugin validate --strict`\[14\]\[15\] | https://code.claude.com/docs/en/plugins/install, /publish | Verified |
| Hook events `UserPromptSubmit`, `PreToolUse` (deny via `permissionDecision`), `SubagentStart` (can't block), `SubagentStop`, `Stop` (`decision: "block"`); hooks fire inside subagents with `agent_id`/`agent_type`\[16\] | https://code.claude.com/docs/en/hooks | Verified |
| `UserPromptSubmit` input field name (`prompt`) and `stop_hook_active` on Stop input\[17\] | hooks / agent-sdk hooks docs | Partly verified (the scripts read fallbacks defensively) |
| `/usage` with `/cost` alias; `/tasks` shows subagent model + effort (v2.1.242+)\[1\] | skills doc, sub-agents doc | Verified |
| Output styles | — | Not used; not needed for this kit |

**Recommended Claude Code version:** v2.1.292 or later, which covers the per-call `effort` parameter, nesting defaults and the worktree isolation checks. Run `claude update`. Workflows need a paid plan, and on Pro you turn them on in `/config`.\[2\]

## Caveats

- **Auto-triggering is a heuristic.** Claude decides from the description whether to load a skill.\[4\] The hook makes it reliable, but it adds a check to every prompt. Turn it off by deleting the `UserPromptSubmit` entry if you only use `/senior-build`.
- **The kit doesn't really reproduce ultracode.** Orchestration happens turn by turn in Claude's context.\[2\] Large plans (more than about 8 WPs) will crowd the orchestrator's context, so split them into separate `/fanout` runs per wave, or use the optional workflow script.
- **Bash in "read-only" agents isn't truly read-only.** `disallowedTools: Write, Edit` stops file tools, but a Bash command could still write. The guard hook and prompts reduce the risk without removing it. For hard guarantees, add `permissions.deny` rules in your settings.\[1\]
- **Fast-moving surface.** Limits changed several times in 2026, per the official sub-agents doc's version notes and wmedia.es Tip #210:
  - A cap of 200 subagents per session arrived in v2.1.212 and was removed in v2.1.224.
  - The concurrency cap has existed since v2.1.217.
  - The nesting default was 5 layers in v2.1.172–v2.1.216, dropped to 1 in v2.1.217, and went to 3 in v2.1.219.

  Re-check `/doctor`, the docs and `claude plugin validate` after updates.
- **Cost numbers are directional.** The 15× and 3-10× figures come from Anthropic's own workloads, not this kit. Measure your runs with `/usage` before claiming savings in a portfolio README.
- **Clean-room note.** Every file above was written from public documentation. Keep employer code, prompts and repo names out of commits and test fixtures.

## Sources

1. [Create custom subagents - Claude Code Docs](https://code.claude.com/docs/en/sub-agents)
2. [Orchestrate subagents at scale with dynamic workflows - Claude Code Docs](https://code.claude.com/docs/en/workflows)
3. [Explore the .claude directory - Claude Code Docs](https://code.claude.com/docs/en/claude-directory)
4. <https://code.claude.com/docs/en/skills>
5. <https://code.claude.com/docs/en/agent-sdk/python>
6. <https://code.claude.com/docs/en/worktrees>
7. [Subagents in the SDK - Claude Code Docs](https://code.claude.com/docs/en/agent-sdk/subagents)
8. [Model configuration - Claude Code Docs](https://code.claude.com/docs/en/model-config)
9. [Claude Code Put Guardrails on Its Own Agent Fleets](https://www.digitalapplied.com/blog/claude-code-subagent-depth-limits-budget-caps-2026)
10. [Why Claude Code's Subagent Cap Never Triggered at 120 - Mervin Praison](https://mer.vin/news/why-claude-codes-subagent-cap-never-triggered-at-120/)
11. [Claude Code Models: Why Opus 5.5 Is Best for Coding](https://claudefa.st/blog/models/model-selection)
12. <https://code.claude.com/docs/en/plugins-reference>
13. [Create and distribute a plugin marketplace - Claude Code Docs](https://code.claude.com/docs/en/plugin-marketplaces)
14. <https://code.claude.com/docs/en/plugins/publish>
15. [Install and manage plugins - Claude Code Docs](https://code.claude.com/docs/en/plugins/install)
16. [Hooks reference - Claude Code Docs](https://code.claude.com/docs/en/hooks)
17. [Intercept and control agent behavior with hooks - Claude Code Docs](https://code.claude.com/docs/en/agent-sdk/hooks)
