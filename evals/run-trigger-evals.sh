#!/bin/sh
# Measures how reliably the skill set fires on evals/trigger-queries.json.
# Each query runs RUNS times through headless Claude Code inside a fresh sandbox that has every
# skill from skills/ installed and nothing else (project settings only, no MCP servers).
# A run counts as triggered when any of our skills was invoked or its SKILL.md read.
#   usage: run-trigger-evals.sh [runs]   (default 3)
#   needs: claude, jq
#   output: one JSON object per query to evals/trigger-results.json; PASS/MISS/OVER lines on stderr
set -eu
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"

RUNS="${1:-3}"
for cmd in claude jq; do command -v "$cmd" >/dev/null 2>&1 || { echo "$cmd is required" >&2; exit 1; }; done

BOX="$(mktemp -d)"; make_sandbox "$BOX"
trap 'rm -rf "$BOX"' EXIT

triggered() {
  out="$BOX/.last.jsonl"
  ( cd "$BOX" && claude -p "$1" --output-format stream-json --verbose --allowedTools "$ALLOWED" \
      --disallowedTools "$DISALLOWED" --setting-sources project \
      --strict-mcp-config --mcp-config "$EVALS_DIR/no-mcp.json" < /dev/null > "$out" 2>/dev/null ) || true
  used_skill "$out"
}

jq -c '.[]' "$EVALS_DIR/trigger-queries.json" | while IFS= read -r item; do
  query="$(printf '%s' "$item" | jq -r '.query')"
  should="$(printf '%s' "$item" | jq -r '.should_trigger')"
  triggers=0; i=0
  while [ "$i" -lt "$RUNS" ]; do
    if triggered "$query"; then triggers=$((triggers + 1)); fi
    i=$((i + 1))
  done
  jq -n --arg q "$query" --argjson should "$should" --argjson t "$triggers" --argjson r "$RUNS" \
    '{query: $q, should_trigger: $should, triggers: $t, runs: $r, trigger_rate: ($t / $r)}'
done | tee "$EVALS_DIR/trigger-results.json" | jq -r '
  if .should_trigger then
    (if .trigger_rate >= 0.8 then "PASS" else "MISS" end) + "  should fire  " + (.trigger_rate|tostring) + "  " + .query
  else
    (if .trigger_rate <= 0.2 then "PASS" else "OVER" end) + "  should stay  " + (.trigger_rate|tostring) + "  " + .query
  end' >&2
