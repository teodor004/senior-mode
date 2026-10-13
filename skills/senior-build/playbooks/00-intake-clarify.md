# 00 — Intake & Clarify

Purpose: turn a one-line goal into an unambiguous problem statement before spending tokens.

## Steps
1. Parse $ARGUMENTS: flags (`--auto`, `--max-parallel N`) and the goal text. Derive `slug` (kebab-case, ≤ 5 words).
2. Preflight (run, don't guess):
   - `git rev-parse --is-inside-work-tree` — if not a git repo, STOP: worktree isolation needs git; offer `git init` + initial commit.
   - Path letter case — run:
     `here="$(pwd -W 2>/dev/null || pwd)/"; top="$(git rev-parse --show-toplevel)/"; [[ "$here" == "$top"* ]] || { shopt -s nocasematch; [[ "$here" == "$top"* ]] && echo "PATH-CASE MISMATCH: $top"; }`
     If it prints a mismatch, STOP: Claude Code refuses to create worktrees when the session's path differs in letter case from the folder on disk (e.g. `work` vs `Work` on Windows or macOS), so every implementer would fail. Ask the user to restart Claude Code from the path git printed.
   - Kit files must never dirty the tree: run `git check-ignore -q .senior/x` and `git check-ignore -q .claude/worktrees/x` (one path per call). For each that isn't ignored, append its pattern (`.senior/` or `.claude/worktrees/`) to `$(git rev-parse --path-format=absolute --git-path info/exclude)` — local to this clone, never committed — and tell the user you did.
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
