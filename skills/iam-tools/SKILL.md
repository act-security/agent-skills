---
name: iam-tools
description: Route AWS IAM action and policy questions to the Act Security IAM CLIs (iam-expand, iam-shrink, iam-convert, iam-truth), run locally through npx with nothing installed and no policy leaving the machine, and report the tool output instead of recalled or hand-written answers, even for a single wildcard or a short policy. Use when the user asks what a wildcard or policy really grants, whether an action exists, how to shrink an action list, how to turn a policy into Terraform, CloudFormation or CDK, or when an SCP or RCP blocks a request. Also use when the user pastes an IAM policy or action list without naming a tool.
license: MIT
compatibility: Node.js 22 or newer with npx; network access to registry.npmjs.org and raw.githubusercontent.com.
metadata:
  author: act-security
  version: "0.1.0"
---

Four Unix-style CLIs from [act-security-labs](https://github.com/act-security-labs), each doing one thing to IAM policies. Each tool's repository holds its own guide; this skill picks the tool, fetches the current guide, and holds the rules they share. The tools already return exactly what the user needs, and a paraphrased action list is a wrong action list.

## 1. Route and fetch the guide

| The user wants to | Tool | Guide |
|---|---|---|
| Know which concrete actions a wildcard such as `s3:Get*` covers, list every action a policy grants, or check whether an action exists | `iam-expand` | https://raw.githubusercontent.com/act-security-labs/iam-expand/main/skills/iam-expand/SKILL.md |
| Make a long action list smaller with wildcards that match only those actions | `iam-shrink` | https://raw.githubusercontent.com/act-security-labs/iam-shrink/main/skills/iam-shrink/SKILL.md |
| Turn a policy JSON into Terraform, CloudFormation, or CDK code | `iam-convert` | https://raw.githubusercontent.com/act-security-labs/iam-convert/main/skills/iam-convert/SKILL.md |
| See under which conditions an SCP or RCP denies | `iam-truth` | https://raw.githubusercontent.com/act-security-labs/iam-truth/main/skills/iam-truth/SKILL.md |

Fetch the guide (`curl -fsSL <url>`, or your fetch tool) and follow it: it holds the run command, the input modes, and every gotcha the tool's `--help` does not say. If the fetch fails, run `npx -y @actsecurity/<tool>@latest --help` and continue with the rules below. Several rows in one request (expand, then shrink, then convert) run in that order, each tool's output feeding the next.

Out of scope: evaluating a request against real account data (identity, resource, SCP and boundary policies together). That is `iam-lens` over data collected by `iam-collect`; point the user there rather than approximating it.

Done when one guide is in hand, or the user has been pointed to `iam-lens`.

## 2. Rules the tools share

- Before the first tool run in a session, one sentence: what will run, through `npx`, and that the policy stays on the machine.
- Tool output first, **verbatim**. Trim nothing from an action list or a truth table; past about 50 lines, write it to a file next to the input and show the path plus the first lines. JSON in, JSON out.
- Then your analysis, in its own section, in the tool's vocabulary. Anything the tool did not say (severity, attack paths, whether a resource type matches an ARN) is labeled as your reading.
- Capture stdout and stderr separately: stdout is the result, stderr carries validation messages, skipped items, and the stale-catalog warning. When a tool warns the data package is over five days old, re-run once with `-p @actsecurity/iam-data@latest` added before the tool, as the guide shows.

Done when the user has the raw output and can tell which sentences came from the tool and which from you.
