#!/bin/sh
# Quality gate for every skill in skills/. Run before a release and weekly in CI.
#   usage: scripts/check.sh [--no-live]
#   --no-live skips the network smoke of the four CLIs
#   needs: uvx (Agent Skills validator), shellcheck, jq, node 22+
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

chk() { label="$1"; shift; if "$@" >/dev/null 2>&1; then printf 'ok    %s\n' "$label"; else printf 'FAIL  %s\n' "$label"; fail=1; fi; }
chk_not() { label="$1"; shift; if "$@" >/dev/null 2>&1; then printf 'FAIL  %s\n' "$label"; fail=1; else printf 'ok    %s\n' "$label"; fi; }
chk_eq() { if [ "$2" = "$3" ]; then printf 'ok    %s\n' "$1"; else printf 'FAIL  %s (expected %s, got %s)\n' "$1" "$2" "$3"; fail=1; fi; }

# 1. Every skill: format, frontmatter limits, size
total_desc=0
for d in "$ROOT"/skills/*/; do
  name="$(basename "$d")"
  chk "$name: agentskills validate" uvx --from skills-ref agentskills validate "$d"
  desc_len="$(awk '/^description:/{print length($0)-13; exit}' "$d/SKILL.md")"
  chk "$name: description $desc_len/1024" [ "$desc_len" -le 1024 ]
  total_desc=$((total_desc + desc_len))
  lines="$(wc -l < "$d/SKILL.md" | tr -d ' ')"
  chk "$name: SKILL.md $lines/500 lines" [ "$lines" -le 500 ]
done
# The five descriptions are always in the agent's context; keep the sum honest.
chk "all descriptions together $total_desc/2500 chars" [ "$total_desc" -le 2500 ]

# 2. The routing skill names every tool skill, and only existing ones
for d in "$ROOT"/skills/iam-*/; do
  name="$(basename "$d")"
  [ "$name" = "iam-tools" ] && continue
  chk "iam-tools routes to $name" grep -q "\`$name\`" "$ROOT/skills/iam-tools/SKILL.md"
done

# 3. Scripts and workflows
chk "shellcheck" shellcheck -x "$ROOT"/scripts/*.sh "$ROOT"/evals/*.sh
for s in "$ROOT"/scripts/*.sh "$ROOT"/evals/*.sh; do chk "executable ${s#"$ROOT"/}" [ -x "$s" ]; done

# 4. Fixtures and eval definitions
for f in "$ROOT"/evals/*.json "$ROOT"/evals/files/*.json "$ROOT"/evals/scenarios/*.json; do chk "json ${f#"$ROOT"/}" jq -e . "$f"; done
chk "evals.json has 8+ cases" jq -e '.evals | length >= 8' "$ROOT/evals/evals.json"
chk "trigger-queries has 8+ positives" jq -e 'map(select(.should_trigger)) | length >= 8' "$ROOT/evals/trigger-queries.json"

# 5. Nothing that should not ship
chk_not "no stray logs or state" sh -c "find '$ROOT' -path '$ROOT/evals/workspace' -prune -o -path '$ROOT/.git' -prune -o \( -name '*.log' -o -name '.omc' -o -name '*.shrunk.*' \) -print | grep -q ."

# 6. Live smoke: the documented behaviors still hold on the published versions
if [ "${1:-}" != "--no-live" ]; then
  E="npx -y @actsecurity/iam-expand@latest"
  S="npx -y @actsecurity/iam-shrink@latest"
  C="npx -y @actsecurity/iam-convert@latest"
  T="npx -y @actsecurity/iam-truth@latest"
  chk_eq "expand s3:Get*Tagging is 5 actions" 5 "$($E 's3:Get*Tagging' 2>/dev/null | wc -l | tr -d ' ')"
  chk_eq "expand drops an unknown action silently (documented)" "s3:GetObject" "$($E s3:GetObject s3:GetObjekt 2>/dev/null)"
  chk_not "expand --invalid-action-behavior error exits non-zero" sh -c "$E --invalid-action-behavior error s3:GetObjekt"
  chk_eq "shrink drops a bare * on stdin (documented)" "s3:GetObject" "$(printf 's3:GetObject\n*\n' | $S 2>/dev/null)"
  chk_eq "shrink round-trip" 2 "$(printf 's3:GetObject\ns3:GetObjectTagging\n' | $S 2>/dev/null | $E 2>/dev/null | wc -l | tr -d ' ')"
  chk "convert cf" sh -c "printf '{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"s3:GetObject\",\"Resource\":\"*\"}]}' | $C --format cf | grep -q '^PolicyDocument:'"
  chk_not "convert rejects bad JSON" sh -c "printf '{not json' | $C"
  chk "truth md labels" sh -c "printf '{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Deny\",\"Action\":\"s3:PutObject\",\"Resource\":\"*\",\"Condition\":{\"StringNotEquals\":{\"aws:RequestedRegion\":\"us-east-1\"}}}]}' | $T --policy-type scp --output md | grep -q 'Not Denied'"
  chk "stale-data warning stays off stdout" sh -c "$E 's3:Get*Tagging' 2>/dev/null | grep -qv 'Warning'"
  echo "data: $($E --show-data-version 2>/dev/null | head -1)"
  echo "expand: $($E --version 2>/dev/null)  shrink: $($S --version 2>/dev/null)  convert: $($C --version 2>/dev/null)"
fi

if [ "$fail" -eq 0 ]; then echo "all checks passed"; else echo "checks failed"; exit 1; fi
