# Act Security agent skills

[Agent Skills](https://agentskills.io) that let your coding agent run the [Act Security Labs](https://github.com/act-security-labs) IAM tools on your machine. Your policies never leave it.

| Ask your agent | Skill | Tool |
|---|---|---|
| "What does `s3:Get*Tagging` actually include?" or "is `iam:PassRoel` real?" | `iam-expand` | [iam-expand](https://github.com/act-security-labs/iam-expand) |
| "This action list is too long, make it smaller without granting more" | `iam-shrink` | [iam-shrink](https://github.com/act-security-labs/iam-shrink) |
| "Turn this policy into Terraform / CloudFormation / CDK" | `iam-convert` | [iam-convert](https://github.com/act-security-labs/iam-convert) |
| "When does this SCP block us? Show me a table" | `iam-truth` | [iam-truth](https://github.com/act-security-labs/iam-truth) |
| Any of the above, without naming a tool | `iam-tools` routes to the right one | |

The agent shows you the tool's output as printed, then its own reading in a separate section. Results come from the current AWS action catalog in [`@actsecurity/iam-data`](https://github.com/act-security-labs/iam-data), updated daily.

## Install

Works with any agent that supports Agent Skills (Claude Code, Cursor, Codex, GitHub Copilot, and [more](https://agentskills.io/clients)).

```bash
npx skills add act-security-labs/agent-skills --all
```

Add `-a claude-code`, `-a cursor`, `-a codex`, or `-a '*'` to pick agents, `-g` to install for your user instead of the current project, and `--skill iam-expand` to take one skill only. Refresh later with `npx skills update`. In Claude Code you can also type `/iam-tools` or `/iam-expand` to load a skill explicitly.

## What runs on your machine

Each tool runs as `npx -y @actsecurity/<tool>@latest`: downloaded into the npm cache on first use, nothing installed globally, no data sent anywhere but registry.npmjs.org for the download. If you already have a tool on your `PATH`, the agent uses it.

Requirements: Node.js 22 or newer with `npx`. The scripts in this repo are POSIX `sh`; on Windows use Git Bash or WSL.

## Where the skills live

Each tool's skill is owned by its own repository at `skills/<tool>/` and changes together with the tool. This repository mirrors them daily (`.github/workflows/sync-tool-skills.yml`) and adds the `iam-tools` routing skill, so one install line gets the whole set.

## Not covered

Evaluating a request against your real account (identity, resource, SCP and boundary policies together) needs your collected IAM data. That is [iam-lens](https://github.com/act-security-labs/iam-lens) over [iam-collect](https://github.com/act-security-labs/iam-collect); the skills point you there instead of guessing.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Syntax errors or a crash on the first run | Node.js older than 22. Install Node 22+ or select it with your version manager. |
| First run is slow | `npx` is downloading the package once; later runs use the cache. |
| `Warning: The data package is over five days old` | The npx cache holds the catalog from the tool's last release. The skill re-runs once with `npx -y -p @actsecurity/iam-data@latest -p @actsecurity/<tool>@latest <tool>`; for a global install run `npm update -g @actsecurity/iam-data`. |
| `Invalid invalidActionBehavior: undefined` | A locally installed `iam-expand` older than 0.11.85. Update it, or pass `--invalid-action-behavior remove`. |

## Development

```bash
scripts/check.sh              # format validator, shellcheck, fixtures, live smoke of the four CLIs
scripts/check.sh --no-live    # same without network
evals/run-trigger-evals.sh    # does the skill set fire on the right prompts? (needs claude, jq)
evals/run-output-evals.sh     # with-skill vs without-skill transcripts for grading
```

`evals/scenarios/` holds four invented policies and conversation flows for testing by hand. Skill text follows [writing-for-agents](https://github.com/mattpocock/skills/tree/main/skills/productivity/writing-for-agents) and the [Agent Skills best practices](https://agentskills.io/skill-creation/best-practices): steps with completion criteria, gotchas the tools' `--help` does not say, nothing that it does.

## License

The skills are MIT licensed. The tools they run are separate packages with their own licenses (AGPL-3.0 for the four CLIs, MIT for `iam-data`).
