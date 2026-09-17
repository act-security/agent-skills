# Manual test flows

Four invented policies for a fictional company, Acme, and a conversation to run against each. Every "expect" line below was produced by the real tools on 2026-09-16 (`iam-data` 0.21.202609161); counts can drift by a few as AWS adds actions.

Setup: an isolated sandbox with every skill from this repo installed and nothing else, and the four policies copied to its root. Run from the repository root:

```bash
T=$(mktemp -d) && mkdir -p "$T/.claude/skills" \
&& cp -R skills/* "$T/.claude/skills/" \
&& cp evals/scenarios/*.json "$T/" \
&& cd "$T" && claude --setting-sources project --strict-mcp-config --mcp-config '{"mcpServers":{}}' \
  --allowedTools 'Skill Read Bash(bash:*) Bash(npx:*) Bash(cat:*) Bash(printf:*) Bash(echo:*) Bash(diff:*) Bash(sort:*) Bash(wc:*) Bash(jq:*)' \
  --disallowedTools 'Write Edit MultiEdit NotebookEdit WebFetch WebSearch Agent Task'
```

`/skills` inside the session should list exactly `iam-tools`, `iam-expand`, `iam-shrink`, `iam-convert`, `iam-truth`.

In every flow the first answer should be preceded by one sentence saying what will run and that the policy stays on your machine.

The sandbox blocks the `Write` and `Edit` tools, not shell redirection: the agent can still create files with `cat > file` through Bash. That is expected (the skill itself saves long outputs next to the input) and harmless, since the whole sandbox is a temp directory you delete afterwards. Check `ls` at the end of a flow; anything beyond the four policies and outputs derived from them is worth reporting.

---

## Flow 1. Rightsizing a CI role (`ci-deploy-policy.json`)

A deploy role written with wildcards. Exercises expand, shrink, convert in sequence.

**You:** Here's our CI role policy in ci-deploy-policy.json. What does it actually let the role do? I'm worried about the wildcards.

**Expect:** `iam-expand` in JSON mode. The policy comes back with every `Action` array expanded, plus a count. Real numbers: Artifacts 51, Images 16, Deploy 40, Logs 132, PassExecutionRole 1, so 240 actions from a 15-line policy. The point to notice: `s3:*Object*` is not "object read/write". It includes `s3:DeleteObject`, `s3:DeleteObjectVersion`, `s3:PutBucketObjectLockConfiguration`, `s3:UpdateObjectEncryption` and a dozen Object Lambda access-point actions.

**You:** Which of those 51 S3 actions can delete or overwrite something?

**Expect:** No new tool run is needed; the agent filters the list it already has. Roughly: 7 `Delete*`, 13 `Put*`, plus `ReplicateObject`, `RestoreObject`, `UpdateObjectEncryption`, `ObjectOwnerOverrideToBucketOwner`. If it re-runs expand instead, that is fine too.

**You:** OK. For S3 keep only the Get and List actions from that list, then give me the shortest safe action list. I'm close to the policy size limit.

**Expect:** `iam-shrink` on the 25 read actions, then the round-trip check from `references/shrink.md`. Result is three patterns:

```
s3:Get*Object*
s3:List*Object*
s3:ListBucket
```

and the sentence that the diff against the original 25 is empty. This is the moment to check the agent did not skip verification: a shrunk pattern is only safe because expand-back proved it.

**You:** Put that into the Artifacts statement and convert the whole policy to Terraform.

**Expect:** `iam-convert --format tf`, output in an `hcl` block starting with `data "aws_iam_policy_document"`. The other four statements are unchanged. If the agent notes the conversion is syntactic and does not re-validate meaning, that is the reference talking.

---

## Flow 2. Reviewing a region guardrail SCP (`region-guardrail-scp.json`)

Two Deny statements: everything outside the EU regions except a break-glass role and global services, and leaving the organization. Exercises truth tables and follow-ups that depend on the table.

**You:** When does the SCP in region-guardrail-scp.json block ec2:RunInstances? Show me a table.

**Expect:** `iam-truth --policy-type scp --action ec2:RunInstances --output md`. The table has two condition columns, `aws:RequestedRegion` and `aws:PrincipalArn`, and one row per combination of the tool's example values: four rows by default, six if the agent adds `-a` to show every listed region. Exactly one row is `Denied`:

| aws:RequestedRegion | aws:PrincipalArn | Result |
|---|---|---|
| eu-west-1 | ...role/acme-break-glass | Not Denied |
| eu-west-1 | ...role/OtherRole | Not Denied |
| us-other-2 | ...role/acme-break-glass | Not Denied |
| us-other-2 | ...role/OtherRole | Denied |

The interpretation must say that `Not Denied` means this SCP does not block it, not that the request is allowed. The values are synthetic examples the tool generated from the policy's condition values.

**You:** So the break-glass role can do anything anywhere? Check organizations:LeaveOrganization for it.

**Expect:** A second `iam-truth` run with `--action organizations:LeaveOrganization`. One row, `Denied`, no condition columns: the second statement has no condition, so the break-glass exemption in the first statement does not help. This is the answer the table gives that reading the JSON quickly does not.

**You:** And iam:CreateUser from us-east-1?

**Expect:** One row, `Not Denied`. `iam:*` is in the `NotAction` list, so the region statement never applies to it. The agent should say the region did not even appear as a column because it is irrelevant for this action.

---

## Flow 3. A data perimeter RCP (`data-perimeter-rcp.json`)

One Deny with `...IfExists` conditions. Exercises RCP mode and reading a table that has a non-obvious row.

**You:** We're rolling out data-perimeter-rcp.json. Under which conditions can someone still read arn:aws:s3:::acme-datalake/report.csv?

**Expect:** `iam-truth --policy-type rcp --action s3:GetObject --resources arn:aws:s3:::acme-datalake/report.csv`. Six rows:

| Principal Org ID | Is AWS Service Principal? | Result |
|---|---|---|
| o-acme7x9q2k | false | Not Denied |
| o-acme7x9q2k | true | Not Denied |
| o-otherorg | false | Denied |
| o-otherorg | true | Not Denied |
| None | false | Denied |
| None | true | Not Denied |

**You:** Why is the row with org o-otherorg and service principal true Not Denied? That looks like a hole.

**Expect:** An explanation grounded in the table: `BoolIfExists` on `aws:PrincipalIsAWSService` means any AWS service principal passes the second condition, and a Deny only fires when every condition matches. So service principals from any org are never denied by this RCP. Whether that is a hole or intended (CloudTrail, Config and similar need it) is your call; the agent should present it as the tool's finding, not fix the policy unasked.

---

## Flow 4. Typo hunt in an analyst policy (`analyst-readonly-policy.json`)

Two misspelled actions and a `NotAction` Deny. Exercises expand's invalid-action handling and `--invert-not-actions`.

**You:** Something in analyst-readonly-policy.json isn't working for the analysts. Is anything misspelled?

**Expect:** `iam-expand` with `--invalid-action-behavior include` or `error`. With `error` the tool stops at the first one: `Invalid action: s3:GetObjekt`. With `include` both survive unexpanded in the output: `s3:GetObjekt` and `athena:GetQueryExecutoin`. The best answer diffs `include` against `remove` and names both with the correct spellings in one pass, which is what `references/expand.md` now suggests. A weak answer only reports the first; if so, ask "is that the only one?" and it should switch modes.

**You:** The second statement denies everything that isn't an S3 read on the datalake. Rewrite it as an explicit Action list. How many actions is that?

**Expect:** `iam-expand --invert-not-actions`. The answer is 21,803 actions, and the agent writes the result to a file rather than pasting it, per `SKILL.md` step 4. The teaching point: a `NotAction` Deny is a deny on the entire AWS catalog minus a few reads, which is why the tool exists to make it visible.

**You:** Does that Deny actually stop an analyst from deleting datalake objects, given the first statement?

**Expect:** Reasoning over the expanded output, no new tool needed: the first statement never grants `s3:DeleteObject` (only reads), and the second denies it explicitly on `acme-datalake/*`, so deletion is blocked twice over. If the agent reaches for `iam-lens` here, that is also acceptable: evaluating allow plus deny together is a simulation question.

---

## Last headless run

2026-09-16, flows 2 to 4 as multi-turn `claude -p --resume` sessions in the sandbox above (Opus 5). Every turn used the skill, showed tool output verbatim under its own heading with the analysis separated, and left no files behind. Flow 3 turn 2 went further than the guide asks: it removed the `BoolIfExists` block, re-ran `iam-truth`, and showed the row disappear. Two defects found and fixed in the skill: `SKILL.md` implied every tool has `--show-data-version` (only expand and shrink do), and `expand.md` lacked the include-versus-remove diff for finding all typos at once.

## What a failed run looks like

- The agent answers from memory without running a tool: the skill did not fire. Type `/iam-tools` and repeat the question, then tell me the exact wording that missed.
- A shrink result without the round-trip sentence: the reference was not read.
- A truth table the agent rewrote instead of pasting: `references/truth.md` was not followed.
- Policy text or ARNs sent anywhere other than the local `npx` command: a real bug, stop and report it.
