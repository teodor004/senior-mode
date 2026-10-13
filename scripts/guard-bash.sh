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

# case-sensitive on purpose: -d (safe delete of merged branches, used by playbook 07) must stay allowed
[[ "$cmd" =~ git[[:space:]]+branch[[:space:]]+-D ]] && deny "force branch delete"

shopt -s nocasematch
[[ "$cmd" =~ rm[[:space:]]+(-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r|--recursive)[[:space:]]+(/|~|\$HOME|\*|\.\.?)([[:space:]]|$) ]] && deny "recursive delete of root/home/cwd"
if [[ "${SENIOR_ALLOW_PUSH:-0}" != "1" && "$cmd" =~ git[[:space:]]+push ]]; then deny "git push is disabled (set SENIOR_ALLOW_PUSH=1 to allow)"; fi
[[ "$cmd" =~ git[[:space:]]+reset[[:space:]]+--hard ]] && deny "git reset --hard (use git checkout -B in a worktree instead)"
[[ "$cmd" =~ git[[:space:]]+clean[[:space:]]+-[a-z]*f ]] && deny "git clean -f"
[[ "$cmd" =~ (curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z)?sh ]] && deny "pipe-to-shell"
[[ "$cmd" =~ (^|[[:space:];&|])sudo[[:space:]] ]] && deny "sudo"
[[ "$cmd" =~ chmod[[:space:]]+-R[[:space:]]+777 ]] && deny "chmod -R 777"
[[ "$cmd" =~ (mkfs|dd[[:space:]]+if=|:\(\)\{) ]] && deny "disk/fork-bomb command"
[[ "$cmd" =~ (cat|less|head|tail)[[:space:]].*\.env([[:space:]]|$) ]] && deny "reading .env secrets"
exit 0
