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
