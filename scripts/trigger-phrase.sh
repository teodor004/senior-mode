#!/usr/bin/env bash
# UserPromptSubmit: make "build like a senior" deterministic by injecting an instruction.
set -euo pipefail
input="$(cat)"

# json_str KEY [FILE]: first string value of "KEY" in the hook input (or FILE), still JSON-escaped.
json_str() {
  { if [ -n "${2:-}" ]; then cat "$2"; else printf '%s' "$input"; fi; } | tr -d '\r\n' \
    | grep -oE '"'"$1"'"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' | head -n1 \
    | sed -E 's/^"'"$1"'"[[:space:]]*:[[:space:]]*"//; s/"$//' || true
}

prompt="$(json_str prompt)"
[ -z "$prompt" ] && prompt="$(json_str user_prompt)"   # field name: see Verified facts
[ -z "$prompt" ] && exit 0
case "$prompt" in /*) exit 0 ;; esac   # explicit slash commands need no help
# "senior mode" only as a command ("senior mode on", "senior mode: X") so prompts naming the senior-mode plugin don't trigger a run
if printf '%s' "$prompt" | grep -Eiq 'build (it )?like a senior|senior mode( on|:)|senior build|plan and fan out|ultracode-lite'; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"The user requested senior mode. Invoke the senior-build skill (Skill tool) with the user prompt as its arguments and follow it exactly, starting at phase 00."}}'
fi
exit 0
