# AGENTS.md — Infra Repo
> Canonical agent policy for this repository.
> Updated: 2026-04-28

## CORE RULES
- Read this file before any task.
- Use Swedish for summaries, explanations, planning, and status.
- Keep commands, paths, config keys, code, errors, and technical terms in original language.
- Do not redesign architecture unless explicitly asked.

## TASK ROUTING
Trivial task = single-file local repo edit, docs/text only, no infra/network/cross-host impact.
- Trivial local task: execute immediately, verify, report briefly.
- Non-trivial local repo task: show brief plan, then execute.
- Trivial Pi read task: SSH read-only command with no sudo, no config/log/secret dump, no service impact (e.g. `uptime`, `df -h`, `free -h`, `systemctl is-active`, `git status`): execute immediately, report in one line. Session-cached host verification sufficient.
- Pi read-only audit: Phase 0 runs directly without pause — collect, interpret, report. Phase 1 / Phase 2 approval gates apply only if the audit yields a proposed change.
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

Session caching: A completed verification may be reused within the same session without re-running the commands. Re-verify if:
- target host changes between tasks
- 30+ minutes have passed since last verification
- an identity mismatch was found in the prior check
- the next action is a write, sudo, service change, or runtime change

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

## REPO STRUCTURE
- `inventory/`  — maskinläsbar infrastrukturdata (hosts, IP, VLAN, DNS, tjänster). Börja här vid diagnostik.
- `docs/`       — bakgrund, baselines, policy och historiska snapshots. Referensmaterial, inte operativt.
- `runbooks/`   — steg-för-steg operativa guider för specifika uppgifter (Opti-faser, restore m.m.).
- `scripts/`    — körbara scripts. Se `scripts/README.md` för inventering och iCloud-placering.
- `caddy/`      — Caddy route-map och config. Komplement till `inventory/services.md`.
- `config/`     — saniterade config-templates och summary-exports. Aldrig live-secrets.
- `state/`      — Pi-lokal runtime-state. Aldrig tracked utom `.gitkeep`. Skriv aldrig hit från Mac.
- `logs/`       — Pi-lokal runtime-logs. Aldrig tracked utom `.gitkeep`.

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


## TMUX POLICY
- Pi has a persistent tmux session named `infra`.
- Use tmux for long-running, interactive, or disconnect-sensitive Pi work.
- Do not use tmux for simple one-shot SSH commands unless needed.
- Prefer the existing `infra` session; do not create random sessions.
- If the session is missing, create it intentionally: `tmux new -d -s infra -n repo`.
- UDR-7 and HAOS should not be modified to use tmux.

## SSH BATCHING
- Batch independent read-only SSH commands into one call per logical group. Avoid multiple separate SSH sessions for the same runbook phase.
- Never batch writes or sudo together with discovery commands — writes always run in their own explicitly approved SSH call.
- Prefer: `ssh pi 'cmd1; cmd2; cmd3'` over three separate `ssh pi 'cmd'` calls.

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

## NETWORK SOURCE OF TRUTH ORDER

1. `AGENTS.md` = agent/operator policy.
2. `inventory/unifi-networks.md` = current UniFi networks/VLANs.
3. `inventory/unifi-firewall.md` = current custom firewall policy inventory.
4. `inventory/unifi-wifi.md` = current WLAN/SSID inventory.
5. `inventory/dhcp-reservations.md` = important fixed-IP reservations.
6. `inventory/dns-names.md` = important forward/PTR DNS names.
7. `docs/udr7-baseline.md` = gateway/controller baseline.
8. `docs/network-validation.md` = read-only validation commands.
9. `docs/open-network-checks.md` = known follow-up checks.
10. Dated docs are historical unless explicitly marked current.

Rules:
- If current inventory conflicts with dated historical docs, current inventory wins.
- Do not update historical docs except to add superseded/stale banners.
- Do not treat planned DNS names as live services without runtime validation.

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
