#!/bin/sh
# Runs every case in evals/evals.json twice through headless Claude Code: with the skill set
# (a sandbox with every skill from skills/ installed) and without (an empty directory).
# Fixtures are copied to a neutral directory and {{FILES}} in prompts is replaced with its path.
# Transcripts land in evals/workspace/<iteration>/<id>/{with_skill,without_skill}.jsonl for grading.
#   usage: run-output-evals.sh [iteration-name]   (default: iteration-<timestamp>)
#   needs: claude, jq
set -eu
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"

ITER="${1:-iteration-$(date +%Y%m%d-%H%M%S)}"
OUT="$EVALS_DIR/workspace/$ITER"
for cmd in claude jq; do command -v "$cmd" >/dev/null 2>&1 || { echo "$cmd is required" >&2; exit 1; }; done
mkdir -p "$OUT"

BOX="$(mktemp -d)"; make_sandbox "$BOX"
BARE="$(mktemp -d)"
FIXTURES="$(mktemp -d)"; cp "$EVALS_DIR"/files/* "$FIXTURES/"
trap 'rm -rf "$BOX" "$BARE" "$FIXTURES"' EXIT

run_case() {
  # $1 id, $2 prompt, $3 label, $4 cwd
  mkdir -p "$OUT/$1"
  ( cd "$4" && claude -p "$2" --output-format stream-json --verbose --allowedTools "$ALLOWED Write" \
      --disallowedTools 'WebFetch WebSearch Agent Task' --setting-sources project \
      --strict-mcp-config --mcp-config "$EVALS_DIR/no-mcp.json" \
      < /dev/null > "$OUT/$1/$3.jsonl" 2>"$OUT/$1/$3.stderr" ) || true
  printf '%s %s: %s tool calls, skill %s\n' "$1" "$3" \
    "$(jq -s '[.. | objects | select(.type? == "tool_use")] | length' "$OUT/$1/$3.jsonl" 2>/dev/null || echo '?')" \
    "$(used_skill "$OUT/$1/$3.jsonl" && echo used || echo unused)"
}

jq -c '.evals[]' "$EVALS_DIR/evals.json" | while IFS= read -r item; do
  id="$(printf '%s' "$item" | jq -r '.id')"
  prompt="$(printf '%s' "$item" | jq -r --arg f "$FIXTURES" '.prompt | gsub("\\{\\{FILES\\}\\}"; $f)')"
  run_case "$id" "$prompt" with_skill "$BOX"
  run_case "$id" "$prompt" without_skill "$BARE"
done

echo "transcripts: $OUT"
echo "grade each pair against expected_output in evals.json; record PASS/FAIL with quoted evidence in $OUT/grading.md"
