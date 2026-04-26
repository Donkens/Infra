# AGENTS.md — Infra Repo
> Canonical agent policy for this repository.
> Updated: 2026-04-14

## CORE RULES
- Read this file before any task.
- Use Swedish for summaries, explanations, planning, and status.
- Keep commands, paths, config keys, code, errors, and technical terms in original language.
- Do not redesign architecture unless explicitly asked.

## TASK ROUTING
Trivial task = single-file local repo edit, docs/text only, no infra/network/cross-host impact.
- Trivial local task: execute immediately, verify, report briefly.
- Non-trivial local repo task: show brief plan, then execute.
- Infra / network / remote / system-service task: Phase 0 mandatory.
- Approval gate overrides all modes.

## EXECUTION CONTEXT
If running in Codex Cloud:
- No SSH.
- No runtime verification of DNS, network, services, or remote hosts.
- No Pi/UDR changes.
- If runtime access is required, stop and output:
`[CLOUD BLOCKED — requires local execution]`

If running locally (Codex desktop):
- Full local execution allowed within the rules below.
- SSH to managed hosts is allowed for read-only recon; show the exact command first.

## SAFETY
Hard blocked unless explicitly instructed:
`rm -rf *`
`git push --force`
`git reset --hard`
`sudo rm`
`DROP TABLE`
`TRUNCATE`
`git add -A`
`git add .`

Approval required before:
- `sudo`
- writes outside the repo
- `/etc/` or `LaunchAgents`
- push to remote
- `--force`, `-f`, `--hard`
- any change affecting a remote host on the network
- overwriting managed system files

Use exactly this block and wait for `GO`:
```text
[APPROVAL REQUIRED]
Action:   <what>
Reason:   <why>
Risk:     <what could go wrong>
Rollback: <how to undo>
Command:  <exact command>
```

## PHASES FOR INFRA / NETWORK / REMOTE
Phase 0 — Recon
- Read-only only.
- Collect: `hostname`, `uname -a`, `uname -m`, `git status --short --branch`, `brew --prefix`
- Output: current state + proposed action plan

Phase 1 — Plan
- Show exact commands and blast radius
- Do not execute writes or remote changes
- Wait for `GO`

Phase 2 — Execute
- Run approved steps
- Verify each step
- If verification fails, propose rollback

## GIT
- Run `git status` before any edit.
- Run `git diff HEAD -- <file>` before staging.
- Stage specific files only.
- Commit format: `<type>(<scope>): <subject>`
- Allowed types: `fix`, `feat`, `chore`, `refactor`, `docs`, `infra`
- Never amend published commits.
- Never push without instruction.
- No new branch unless asked.

## ENVIRONMENT
- Shell: `zsh`
- Scripts: `set -euo pipefail`
- Python: `python3`
- Prefer venv; use `--break-system-packages` only outside venv
- Scripts currently live in TWO iCloud locations (temporary split; do not assume a single path):
  - `~/Library/Mobile Documents/com~apple~CloudDocs/Projects/scripts/` — most infra scripts (audio, dns, host, maintenance, mcp, setup, udr)
  - `~/Library/Mobile Documents/com~apple~CloudDocs/Scripts/` — legacy root (timberborn, pi-monitor, game_*, open-xcode, Scripts/infra/*)
- Always verify actual file placement before editing; never assume a single script path.
- `~/bin` contains symlinks into those iCloud locations; do not duplicate or break them.
- Never hardcode brew paths; always use `$(brew --prefix)`

## SCRIPTING STANDARD
```bash
#!/usr/bin/env bash
# Purpose: <one line>
# Author:  codex-agent | Date: YYYY-MM-DD
set -euo pipefail
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log() { echo "[$(basename "$0")] $*" >&2; }
die() { log "ERROR: $*"; exit 1; }
```

## INFRA DEFAULTS
- DNS chain: client -> AdGuard (192.168.1.55) -> Unbound -> upstream
- Do not add parallel resolvers
- Debug order: routing -> firewall -> DNS -> application

Managed hosts:
- `ssh pi`   : Raspberry Pi
- `ssh mini` : Mac mini
- `ssh udr`  : UDR-7

## SOURCE OF TRUTH AND LOCAL STATE
- The Pi is the operational source of truth for live DNS service state.
- GitHub `Donkens/Infra` `main` is canonical for repo history, docs, scripts, and sanitized snapshots.
- The Pi produces nightly sanitized snapshots from live state.
- Mac repos are working copies and should stay clean except ignored tool state such as `.codex/`.
- Raw Pi runtime/backups are local sensitive state and must never be printed, tracked, committed, or pasted.
- The Pi repo may contain ignored local runtime files under `logs/` and `state/`.
- `state/backups/` is Pi-local backup state and may contain sensitive service configs.
- `state/backups/latest` is a Pi-local symlink to the newest backup.
- Never print, track, commit, or paste raw backup files such as `AdGuardHome.yaml`.

## ADGUARD API POLICY
- Use session-cookie auth via `POST /control/login`; do not assume Basic Auth works for `/control/*` endpoints.
- Never hardcode AdGuard credentials in prompts, shell history, scripts, or logs.
- Read API data as safe summaries and counts only.
- Never print raw clients, rewrites, upstreams, user rules, cookies, or config bodies.
- If credential input is echoed or leaks in terminal/chat, rotate the password.

## UNCERTAINTY
- State confirmed facts plainly.
- Mention uncertainty only when it is real and actionable.
- If a flag, path, or behavior is unclear, check `--help` or `man` first.
- Never invent.

## REPORTING
Default: compact, conclusions first, evidence second.

Diagnostic / analytic tasks:
- `## Summary`
- `## Recommended changes`
- `## Evidence`
- `## Uncertainties` only if needed
- `## Next step`

Non-trivial change tasks:
- `## Status`
- `## Summary`
- `## Actions`
- `## Evidence`
- `## Next step`
- `## Risks` only if needed

Trivial tasks:
- One-line confirmation only.
