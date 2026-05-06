# Agent autonomy matrix

> Purpose: fewer unnecessary pauses while keeping approval gates for sensitive work.

## Decision matrix

| Task type | Execute directly | Plan first | Needs explicit approval | Output mode |
|---|---:|---:|---:|---|
| Docs typo, headings, Markdown formatting | yes | no | no | compact |
| Internal links, repo-map/index updates | yes | no | no | compact |
| Add `STALE` or `SUPERSEDED` banner to dated historical docs | yes, when current inventory clearly supersedes it | no | no | compact |
| Repo-only hygiene scan | yes | no | no | compact summary |
| Docs-only local commit | yes, after diff and checks | no | no | compact |
| Push to GitHub | no | yes | yes | compact |
| Read-only local host audit | yes | brief plan if non-trivial | no | compact evidence |
| Read-only SSH audit on managed host | yes, after host verification | brief plan if non-trivial | no | compact evidence |
| Runtime verification from Codex Cloud | no | no | blocked | one-line block |
| Privileged system changes | no | yes | yes | exact approval block |
| Docker service changes | no | yes | yes | exact approval block |
| DNS, firewall, UniFi, UDR, HAOS runtime changes | no | yes | yes | exact approval block |
| Sensitive material or raw runtime configs | no | no | blocked | do not print |

## Safe auto-fix lane

Agents may run these without approval when the work is repo-only and does not touch runtime state:

- Fix Markdown formatting, headings, tables, and internal links.
- Update `README.md`, `docs/repo-map.md`, and index-style files when the target file already exists.
- Add stale/superseded banners to historical docs when current inventory clearly wins.
- Run read-only repo checks such as `git status --short --branch`, `rg`, and Markdown link checks.
- Create a docs-only commit after showing a compact diff summary and passing checks.

Approval is still needed for push, privileged host work, writes outside the repo, runtime service changes, network/DNS/firewall changes, and sensitive material.

## Stop only when needed

Stop and ask for operator input only when there is a real blocker: unclear host identity, unclear source-of-truth, approval-required work, local runtime access needed from a cloud-only environment, or sensitive material risk.

Do not stop for safe docs-only cleanup, link fixes, compact repo audits, or read-only host checks covered by `AGENTS.md`.
