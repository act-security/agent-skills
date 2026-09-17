# Act Security agent skills

One [Agent Skill](https://agentskills.io), `iam-tools`, that lets your coding agent run the [Act Security Labs](https://github.com/act-security-labs) IAM tools on your machine. Your policies never leave it.

| Ask your agent | Tool it runs |
|---|---|
| "What does `s3:Get*Tagging` actually include?" or "is `iam:PassRoel` real?" | [iam-expand](https://github.com/act-security-labs/iam-expand) |
| "This action list is too long, make it smaller without granting more" | [iam-shrink](https://github.com/act-security-labs/iam-shrink) |
| "Turn this policy into Terraform / CloudFormation / CDK" | [iam-convert](https://github.com/act-security-labs/iam-convert) |
| "When does this SCP block us? Show me a table" | [iam-truth](https://github.com/act-security-labs/iam-truth) |

The skill picks the tool, fetches that tool's current guide from its repository, runs it as `npx -y @actsecurity/<tool>@latest`, and shows you the output as printed before adding its own reading. Results come from the current AWS action catalog in [`@actsecurity/iam-data`](https://github.com/act-security-labs/iam-data), updated daily.

## Install

Works with any agent that supports Agent Skills (Claude Code, Cursor, Codex, GitHub Copilot, and [more](https://agentskills.io/clients)).

```bash
npx skills add act-security-labs/agent-skills
```

Add `-a claude-code`, `-a cursor`, `-a codex`, or `-a '*'` to pick agents, and `-g` to install for your user instead of the current project. In Claude Code you can also type `/iam-tools`.

Each tool also ships its own skill at `skills/<tool>/SKILL.md` in its repository, for example `npx skills add act-security-labs/iam-expand`, if you want one tool without the router.

## What runs on your machine

Each tool runs as `npx -y @actsecurity/<tool>@latest`: downloaded into the npm cache on first use, nothing installed globally, no data sent anywhere but registry.npmjs.org for the download and raw.githubusercontent.com for the guide. If you already have a tool on your `PATH`, the agent uses it.

Requirements: Node.js 22 or newer with `npx`.

## Not covered

Evaluating a request against your real account (identity, resource, SCP and boundary policies together) needs your collected IAM data. That is [iam-lens](https://github.com/act-security-labs/iam-lens) over [iam-collect](https://github.com/act-security-labs/iam-collect); the skill points you there instead of guessing.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Syntax errors or a crash on the first run | Node.js older than 22. Install Node 22+ or select it with your version manager. |
| First run is slow | `npx` is downloading the package once; later runs use the cache. |
| `Warning: The data package is over five days old` | The npx cache holds the catalog from the tool's last release. The skill re-runs once with `npx -y -p @actsecurity/iam-data@latest -p @actsecurity/<tool>@latest <tool>`. |

## License

MIT. The tools the skill runs are separate packages with their own licenses.
