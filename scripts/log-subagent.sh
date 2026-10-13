#!/usr/bin/env bash
# SubagentStart / SubagentStop: append one JSON line per event to .senior/run-log.jsonl
set -euo pipefail
input="$(cat)"
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
mkdir -p "$root/.senior"
printf '%s' "$input" | jq -c --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{
  ts:$ts,
  event:(.hook_event_name // "unknown"),
  agent_type:(.agent_type // null),
  agent_id:(.agent_id // null),
  effort:(.effort // null),
  session_id:(.session_id // null),
  transcript:(.agent_transcript_path // null)
}' >> "$root/.senior/run-log.jsonl"
exit 0
