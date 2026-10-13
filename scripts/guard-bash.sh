#!/usr/bin/env bash
# PreToolUse(Bash): deny destructive or exfiltrating commands. Applies to main session AND subagents.
# Plain bash/grep/sed (no jq), so the guard is never silently off for lack of a dependency.
set -euo pipefail
input="$(cat)"

# json_str KEY [FILE]: first string value of "KEY" in the hook input (or FILE), still JSON-escaped.
json_str() {
  { if [ -n "${2:-}" ]; then cat "$2"; else printf '%s' "$input"; fi; } | tr -d '\r\n' \
    | grep -oE '"'"$1"'"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' | head -n1 \
    | sed -E 's/^"'"$1"'"[[:space:]]*:[[:space:]]*"//; s/"$//' || true
}

# unescape \n \r \t (as spaces), \" and \\ so the rules see the command as typed
cmd="$(json_str command | sed -E 's/\\[nrt]/ /g; s/\\"/"/g; s/\\\\/\\/g')"
[ -z "$cmd" ] && exit 0

deny() {
  # reasons are fixed strings with no quotes or backslashes, so they need no JSON escaping
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"senior-mode guard: %s"}}\n' "$1"
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
