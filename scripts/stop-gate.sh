#!/usr/bin/env bash
# Stop: if a senior-mode run is mid-execution and the gate hasn't passed, block ONCE with a reminder.
set -euo pipefail
input="$(cat)"
active='"stop_hook_active"[[:space:]]*:[[:space:]]*true'
[[ "$input" =~ $active ]] && exit 0

# json_str KEY [FILE]: first string value of "KEY" in the hook input (or FILE), still JSON-escaped.
json_str() {
  { if [ -n "${2:-}" ]; then cat "$2"; else printf '%s' "$input"; fi; } | tr -d '\r\n' \
    | grep -oE '"'"$1"'"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' | head -n1 \
    | sed -E 's/^"'"$1"'"[[:space:]]*:[[:space:]]*"//; s/"$//' || true
}

root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
state="$(ls -t "$root"/.senior/*/state.json 2>/dev/null | head -n1 || true)"
[ -z "$state" ] && exit 0
phase="$(json_str phase "$state")"
gate="$(json_str gate "$state")"
gate="${gate:-pending}"
marker="$(dirname "$state")/.stop-reminded"
case "$phase" in
  execute|review|integrate)
    if [ "$gate" != "passed" ] && [ ! -f "$marker" ]; then
      touch "$marker"
      # $phase can only be one of the three literals above, so it embeds without escaping
      printf '{"decision":"block","reason":"senior-mode: run is in phase \\"%s\\" and the verification gate has not passed. Either continue (run tests / review per playbook 06), or if you are deliberately pausing for the human, set state.json phase to \\"awaiting-approval\\" and present a STOP checkpoint."}\n' "$phase"
      exit 0
    fi ;;
  *) rm -f "$marker" ;;
esac
exit 0
