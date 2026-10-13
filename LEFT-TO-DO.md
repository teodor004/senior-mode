# Left to do

Status on 2026-10-13: the kit is built, passes `claude plugin validate --strict`, its hooks pass 36 local checks, and the five blockers from the first walkthrough are fixed. It has **never run end to end** in a real Claude Code session. Run the `tasklite` walkthrough in `PROMPT.md` once before telling anyone to install it.

## Already confirmed locally

- Claude Code loads all 5 skills, 9 agents and 5 hooks (`claude --plugin-dir . plugin details senior-mode`). Installing the plugin adds about 750 tokens to every session.
- Agents are named `senior-mode:<agent>`, which matches rule 4 in `skills/senior-build/SKILL.md`.
- Claude only sees `senior-build` and `senior-plan`. `fanout`, `senior-review` and `retro` are slash-command only (`disable-model-invocation`), as designed.
- Hooks run inside real Claude Code on native Windows (through Git Bash). In a project with an active run, the guard blocked a command and the Stop hook fired its one-time reminder.
- A worktree agent that commits its work keeps its worktree and branch, and the Agent result returns `worktreePath` and `worktreeBranch`.
- The `haiku` alias resolved and ran on the machine this was built on.
- The path-case check in playbook 00 catches a `work`/`Work` mismatch and stays quiet in a correctly-cased subfolder.

## Fixed on 2026-10-13

1. The guard and the logger only act during senior-mode runs: when the call comes from a `senior-mode:` agent, or when the project has a `state.json` that isn't `done`/`aborted`. Elsewhere they do nothing.
2. Playbook 00 stops early if the session's path differs from the folder on disk only in letter case. `/fanout` and `/senior-review --fix` run the same check.
3. `allowed-tools` in `senior-build/SKILL.md` is now a YAML list.
4. Fix agents work in the WP's existing worktree: playbook 05 records its path in `state.json`, and playbook 06 and `/senior-review --fix` `cd` there.
5. Every run makes sure `.senior/` and `.claude/worktrees/` are git-ignored (adding them to `.git/info/exclude` if needed). `.senior/` is no longer committed at STOP-2.

## Must check in a real run (`tasklite` walkthrough)

Start Claude Code from a correctly-cased path, on the account and provider you'll really use, in the **default** permission mode.

- [ ] **Permission prompts in background agents.** This is undocumented. Implementers need Write/Edit, test commands and `git commit`. Do they prompt you, wait, or get denied? If they're denied, every work package fails.
- [ ] **Hook input inside plugin agents.** The scoping in fix 1 assumes it includes `agent_type` starting with `senior-mode:`. If it doesn't, the guard and logger still work during runs (through `state.json`), but not for agents used outside a run, such as `/senior-review`'s reviewers.
- [ ] **`CLAUDE_PROJECT_DIR` inside worktree agents** points to the main checkout. The state lookup and the logger rely on it.
- [ ] **Stop gate vs. waiting.** In the probe, the main agent ended its turn while its background agent was still working. So the Stop hook will probably fire mid-wave and push the orchestrator to "continue" when it should just wait. Watch for polling or a review that starts early. A possible fix is to skip the gate while any WP has status `running`.
- [ ] **Routing actually applies.** `/tasks` should show each worker's model and effort from its frontmatter, not the session's (e.g. `xhigh`). The docs don't say which wins.
- [ ] **`worktree.baseRef: "head"`** makes workers branch from `senior/<slug>`. The default (`fresh`) branches from the default branch, and the fallback (the base-commit check) must then kick in.
- [ ] **Gitignored dependencies in worktrees.** `node_modules`, `.venv` and `.env` aren't in a new worktree, so tests can fail there. Claude Code supports a `.worktreeinclude` file for this. Document it, and have the explorer report what tests need.
- [ ] **Model aliases.** `haiku` worked here; check `sonnet` and `opus` too. On Bedrock, Vertex and Foundry, the aliases depend on provider config.
- [ ] **Trigger finds the skill.** The injected text says "senior-build", but the real name is `senior-mode:senior-build`.
- [ ] **Bare `/senior-build` works**, as the README claims (otherwise only `/senior-mode:senior-build` does).
- [ ] **`when_to_use` is honoured.** The docs check didn't find it documented. If it's ignored, its trigger phrases are lost; move them into `description`.
- [ ] **`${CLAUDE_SKILL_DIR}` inside playbooks.** `02-spec.md` says it is only expanded in SKILL.md; the docs check says supporting files are substituted too. Confirm which is true and fix the wording.
- [ ] **Cost.** Count the agents and compare `/usage` before and after. The "flag if more than 12 agents" line is easy to pass: explorers + 2 architect calls + WPs + a reviewer and integrator per wave + fixes.

## What could go wrong (known weak spots)

- **The guard is a speed bump, not a sandbox.** Commands it lets through include `rm -rf ~/`, `rm -rf /*`, `rm -fr "$HOME"`, `git -C . push`, `source .env`, and anything run through Python or another language. It also blocks some harmless things, such as a commit message that mentions "git push". Real protection is `permissions.deny` in settings plus sandboxing.
- **An abandoned run** (phase left at `execute`) keeps the guard on in that project, and the stop gate reminds once per session, until `state.json` says `done` or `aborted`.
- **"Read-only" agents aren't read-only.** The explorer and both reviewers have Bash, and the architect stays inside `.senior/` only because the prompt says so.
- **The orchestrator is a model, not code.** It parses RESULT blocks and writes `state.json` itself. A malformed `state.json` can switch the stop gate off. Plans with more than about 8 WPs crowd its context.
- **Hand-written JSON parsing in the hooks** assumes the input shape Claude Code sends today. It's tested only against realistic samples.
- **Overlapping work packages** turn into semantic merge conflicts and STOPs, which cost human time.
- **Updates:** the version is still `0.1.0`. Bump it for every release, or installed copies may not update.
- **`PROMPT.md` has drifted** from the code (jq, guard, trigger, workflow script, `.senior/` tracking). The README and the code are the source of truth.

## Improvements (nice to have)

- Put the hook tests in the repo (`tests/hooks_test.py`). Add GitHub Actions to run `claude plugin validate --strict`, `bash -n`, `shellcheck` and those tests.
- Add `evals/` for `claude plugin eval`, covering prompts that should and shouldn't trigger, and agent routing.
- `retro`: set `model: haiku` and `effort: low` in its frontmatter instead of asking for it in prose.
- Align field names between plan.md's JSON (`test_command`, the WP file) and the workflow script's args (`testCommand`, `wpText`).
- README: native Windows works (hooks run through Git Bash), so "WSL2 only" is stricter than needed.
- Add a `CHANGELOG.md`. Move `PROMPT.md` to `docs/design-spec.md` and mark it as the original design.
- Add a "What's verified" section to the README so users know what has and hasn't been tested.

## Suggested order

1. Run the `tasklite` walkthrough as described above.
2. Fix whatever it shows.
3. Add the tests and CI, bump to `0.2.0`, then tell people to install it.
