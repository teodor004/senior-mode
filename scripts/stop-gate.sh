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
