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

## HOST VERIFICATION
Before any audit or write, verify the current host:
```bash
hostname; whoami; id; echo "$HOME"; uname -a
cat ~/.machine-identity 2>/dev/null || echo "no identity file"
```
Cross-check against `inventory/identity-map.md`. If values conflict, stop and report.

Rules:
1. Read `~/.machine-identity` if it exists.
2. Never assume identity from path alone — `/Users/hd` does not prove MacBook, `/Users/yasse` does not prove Mac mini.
3. If target host differs from current host, SSH and verify remote too.
4. UDR-7 SSH user is `root` (not `ubnt`). UDR hostname is `udrhomelan`.
5. Pi repo path is lowercase: `/home/pi/repos/infra`.
6. Workspace/sandbox path is not the target host.
7. If `~/.machine-identity` conflicts with `inventory/identity-map.md`, stop and report mismatch.
8. No writes until Phase 2 approval.

See `docs/agent-host-verification.md` for the full runbook.

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

## OPTI / PROXMOX WORKSPACE
- Opti/Proxmox material in this repo is documentation/templates only until an explicit implementation task says otherwise.
- Use Phase 0/1/2 for Opti, Proxmox, HAOS, Docker, firewall, backup, or remote-access work:
  - Phase 0 = read-only discovery.
  - Phase 1 = plan with exact files/commands/blast radius.
  - Phase 2 = apply only after explicit `GO`.
- Never print or commit secrets, private keys, tokens, cookies, raw backups, or real `.env` files.
- Use only `env.example`, `.env.example`, `compose.example.yaml`, `Caddyfile.example`, and other clearly marked examples.
- No WAN port forwards.
- No `0.0.0.0` binds without approval.
- Every new service plan should include DNS name, Caddy plan where relevant, Uptime Kuma check plan, restart policy, and log limits.
- No `latest` image tags in production examples unless the exception is documented.
- Take a HAOS backup before HAOS changes.
- Back up compose and env material before Docker stack changes.
- No long-lived Proxmox snapshots; use `take -> test -> delete`.
- Mac GUI automation stays on Mac.
- Pi remains DNS primary.
- UDR-7 remains gateway/VLAN/firewall/WireGuard authority.
- 32 GB RAM is the Opti target profile.
- If host RAM is below 32 GB, use the low-RAM bootstrap profile and skip heavy workloads.
- Do not add Tailscale initially; document it only as a later optional path.
- Do not add Jellyfin initially.
- Do not add Vaultwarden until backup destination, backup process, and restore-test are documented and completed.

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
- Use `scripts/maintenance/prune-dns-backups.sh` for DNS backup retention.
- DNS backup retention defaults to dry-run, keeps 45 days, and preserves at least the newest 10 backup directories.
- Applying DNS backup retention requires explicit `--apply`; never use `git clean` for Pi runtime/backups.

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
