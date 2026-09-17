# Changelog

## 0.1.0 (unreleased)

First release: `iam-expand`, `iam-shrink`, `iam-convert`, `iam-truth` skills, one per tool and owned by the tool's repository, plus the `iam-tools` routing skill. Tools run as `npx -y @actsecurity/<tool>@latest` with nothing installed; a stale cached catalog is detected from the tools' own warning and refreshed on demand.

Verified against `iam-expand` 0.11.85, `iam-shrink` 0.1.91, `iam-convert` 0.1.89, `iam-truth` 0.1.17.
