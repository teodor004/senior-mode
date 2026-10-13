#!/usr/bin/env bash
# UserPromptSubmit: make "build like a senior" deterministic by injecting an instruction.
set -euo pipefail
input="$(cat)"
prompt="$(printf '%s' "$input" | jq -r '.prompt // .user_prompt // empty')"   # field name: see Verified facts
[ -z "$prompt" ] && exit 0
case "$prompt" in /*) exit 0 ;; esac   # explicit slash commands need no help
# "senior mode" only as a command ("senior mode on", "senior mode: X") so prompts naming the senior-mode plugin don't trigger a run
if printf '%s' "$prompt" | grep -Eiq 'build (it )?like a senior|senior mode( on|:)|senior build|plan and fan out|ultracode-lite'; then
  jq -n '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",
    additionalContext:"The user requested senior mode. Invoke the senior-build skill (Skill tool) with the user prompt as its arguments and follow it exactly, starting at phase 00."}}'
fi
exit 0
