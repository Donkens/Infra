# Agent repo autopilot

> Purpose: safe, token-efficient repo cleanup without local runtime access.

## Scope

Allowed by default:

- docs-only cleanup
- Markdown formatting
- internal link fixes
- repo-map and README index updates
- stale/superseded banners for historical docs
- compact repo hygiene scans

Not allowed without explicit approval:

- push
- privileged host work
- runtime service changes
- writes outside the repo
- network, DNS, firewall, Docker, HAOS, Proxmox, or UDR runtime changes
- sensitive material or raw runtime config output

## Standard flow

```bash
git status --short --branch
python3 scripts/ci/check-markdown-links.py
rg -n "(TODO|FIXME|STALE|SUPERSEDED|CLOUD BLOCKED)" AGENTS.md README.md docs runbooks inventory scripts || true
rg -n "(latest\b|0\.0\.0\.0)" docs config runbooks inventory scripts || true
```

## If changes are needed

1. Edit only the specific docs/index files required.
2. Avoid runtime paths: `state/`, `logs/`, raw backups, real env files.
3. Run checks again.
4. Show compact changed-file summary.
5. Stage explicit files only.
6. Commit with `docs(agent): ...` or a more specific docs commit message.
7. Stop before push unless the operator explicitly requested push.

## Compact report template

```text
Status: PASS/WARN/FAIL

Changed:
- <file>: <short reason>

Verification:
- <command>: PASS/WARN/FAIL

Next:
- <single next step>
```
