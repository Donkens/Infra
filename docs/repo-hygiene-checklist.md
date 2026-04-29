# Repo hygiene checklist (offline)

> Purpose: quick local quality pass without requiring access to Pi/UDR/remote services.

## 1) Inventory consistency
- [ ] `inventory/` files have clear scope and updated date where relevant.
- [ ] Conflicts are resolved in favor of current inventory, not dated historical docs.
- [ ] Planned DNS names are marked as planned, not live.

## 2) Historical doc hygiene
- [ ] Dated docs include a `SUPERSEDED` or `STALE` banner near the top.
- [ ] Historical docs keep context but do not override current source-of-truth.

## 3) Safe examples only
- [ ] No secrets, tokens, cookies, private keys, or raw backups are present.
- [ ] Templates use `*.example` naming when appropriate.
- [ ] Production examples avoid `latest` tags unless explicitly justified.
- [ ] No `0.0.0.0` bind examples unless explicitly approved.

## 4) Scripts baseline
- [ ] Shell scripts use `#!/usr/bin/env bash` and `set -euo pipefail`.
- [ ] Script headers include a one-line purpose.
- [ ] New scripts follow shared `log`/`die` conventions where practical.

## 5) Git hygiene
- [ ] `git status --short --branch` reviewed before edits.
- [ ] Staging uses explicit files only (no `git add .` / `git add -A`).
- [ ] Commit message format follows `<type>(<scope>): <subject>`.

## Suggested local check commands
```bash
git status --short --branch
rg -n "(SUPERSEDED|STALE)" docs/*2026*.md
rg -n "(latest\b|0\.0\.0\.0)" docs config runbooks inventory
rg -n "(token|secret|private key|BEGIN .* PRIVATE KEY|AdGuardHome\.yaml)" docs config runbooks inventory scripts
```
