#!/bin/sh
# Shared helpers for the eval runners. Sourced, not executed.
#   make_sandbox <dir>  installs every skill from skills/ into <dir>/.claude/skills
#   used_skill <jsonl>  exit 0 when the transcript invoked any of our skills or read one of their SKILL.md files
# shellcheck disable=SC2034
EVALS_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_ROOT="$(cd "$EVALS_DIR/.." && pwd)/skills"
ALLOWED='Skill Read Bash(bash:*) Bash(sh:*) Bash(npx:*) Bash(cat:*) Bash(printf:*) Bash(echo:*) Bash(diff:*) Bash(sort:*) Bash(wc:*) Bash(jq:*) Bash(python3:*)'
DISALLOWED='Write Edit MultiEdit NotebookEdit WebFetch WebSearch Agent Task'

make_sandbox() {
  mkdir -p "$1/.claude/skills"
  # ${d%/}: with a trailing slash, BSD cp copies the directory's contents instead of the directory
  for d in "$SKILLS_ROOT"/*/; do cp -R "${d%/}" "$1/.claude/skills/"; done
}

skill_names_regex() {
  # iam-tools|iam-expand|... for jq
  names=""
  for d in "$SKILLS_ROOT"/*/; do
    n="$(basename "$d")"
    names="${names:+$names|}$n"
  done
  printf '%s' "$names"
}

used_skill() {
  names="$(skill_names_regex)"
  jq -s -e --arg names "$names" 'any(.. | objects | select(.type? == "tool_use");
      (.name == "Skill" and ((.input.skill // "") | test("^(" + $names + ")$"))) or
      (.name == "Read" and ((.input.file_path // "") | test("/(" + $names + ")/SKILL.md$"))))' "$1" >/dev/null 2>&1
}
