# Shared helpers for the senior-mode hook scripts. Sourced, not executed. Plain bash/grep/sed (no jq).

# json_str KEY [FILE]: first string value of "KEY" in $input (or FILE), still JSON-escaped.
json_str() {
  { if [ -n "${2:-}" ]; then cat "$2"; else printf '%s' "$input"; fi; } | tr -d '\r\n' \
    | grep -oE '"'"$1"'"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' | head -n1 \
    | sed -E 's/^"'"$1"'"[[:space:]]*:[[:space:]]*"//; s/"$//' || true
}

# latest_state: the most recently modified .senior/*/state.json in the project, or nothing.
latest_state() {
  ls -t "${CLAUDE_PROJECT_DIR:-$(pwd)}"/.senior/*/state.json 2>/dev/null | head -n1 || true
}

# in_senior_run: true for calls made by a senior-mode subagent, or while this project has a run that is
# not done/aborted. Keeps the guard and the logger out of sessions that aren't using senior-mode.
in_senior_run() {
  local by_agent='"agent_type"[[:space:]]*:[[:space:]]*"senior-mode:' state
  [[ "$input" =~ $by_agent ]] && return 0
  [ -d "${CLAUDE_PROJECT_DIR:-$(pwd)}/.senior" ] || return 1
  state="$(latest_state)"
  [ -n "$state" ] || return 1
  case "$(json_str phase "$state")" in done|aborted) return 1 ;; esac
  return 0
}
