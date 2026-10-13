#!/usr/bin/env bash
# Stop: if a senior-mode run is mid-execution and the gate hasn't passed, block ONCE with a reminder.
set -euo pipefail
input="$(cat)"
active='"stop_hook_active"[[:space:]]*:[[:space:]]*true'
[[ "$input" =~ $active ]] && exit 0
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

state="$(latest_state)"
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
