#!/usr/bin/env bash
# SubagentStart / SubagentStop: append one JSON line per event to .senior/run-log.jsonl (senior-mode runs only)
set -euo pipefail
input="$(cat)"
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
in_senior_run || exit 0
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
mkdir -p "$root/.senior"

# field KEY [DEFAULT]: the value as a JSON string, else DEFAULT, else null. Values are still escaped, so they embed safely.
field() {
  local v
  v="$(json_str "$1")"
  if [ -n "$v" ]; then printf '"%s"' "$v"; elif [ -n "${2:-}" ]; then printf '"%s"' "$2"; else printf 'null'; fi
}

printf '{"ts":"%s","event":%s,"agent_type":%s,"agent_id":%s,"effort":%s,"session_id":%s,"transcript":%s}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(field hook_event_name unknown)" "$(field agent_type)" "$(field agent_id)" \
  "$(field effort)" "$(field session_id)" "$(field agent_transcript_path)" >> "$root/.senior/run-log.jsonl"
exit 0
