# senior-mode — ultracode-lite for Claude Code

Type **`build like a senior: <goal>`** (or `/senior-build <goal>`) and Claude Code runs a
staff-engineer process: clarify → explore → spec → plan with work packages → **routed parallel
subagents** (right model + effort per task, git-worktree isolation) → adversarial review + test
gate → merge → report. It stops for your approval after the plan and before merge.

Built only from markdown skills/subagents + a few hook scripts. Clean-room, MIT.

## Install

### A. As a plugin (recommended)
```text
/plugin marketplace add teodor004/senior-mode
/plugin install senior-mode@senior-mode-market
/reload-plugins
```
Shell equivalent: `claude plugin marketplace add teodor004/senior-mode && claude plugin install senior-mode@senior-mode-market`.
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
