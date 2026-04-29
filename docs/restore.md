# Pi DNS restore guide

This guide restores the Raspberry Pi DNS node from repo-held documentation and sanitized snapshots. It is a restore guide, not a forensic dump.

## 1. Scope and safety

Scope:

- Restore target: Raspberry Pi DNS node.
- Covered components: infra repo, Unbound config, AdGuard Home restore policy, and health timers.
- DNS target chain: client -> AdGuard Home (`192.168.1.55`) -> Unbound (`127.0.0.1:5335`) -> upstream.

Safety rules:

- Do not print, paste, commit, or broadly copy raw secrets.
- Do not print raw `AdGuardHome.yaml`.
- Do not print credentials, sessions, tokens, private keys, certificate private keys, password hashes, raw query logs, or raw backup contents.
- Do not restore from raw `state/backups/` without a separate restore task and explicit approval.
- Do not use blind copies over live runtime directories.

Command classes:

- **Read-only check:** safe to run during Phase 0.
- **Operator-only / approval required:** changes packages, `/etc`, systemd, service state, or live DNS behavior. Run only after Phase 1/2 approval.

## 2. Restore assumptions

Assumptions:

- The target is a new or repaired Raspberry Pi intended to become the DNS node.
- Network, SSH, and GitHub access are available.
- The operator has a separate secret source for AdGuard Home credentials and TLS certificate material if needed.
- The repo contains sanitized snapshots and Unbound config snapshots.
- The repo does not contain a full raw AdGuard Home restore source.
- The Pi remains DNS primary; do not add parallel DNS resolvers as part of restore.

Abort if any assumption is false and create a new Phase 0/1 plan before continuing.

## 3. Current backup posture

Current state after the Phase 0 backup/restore audit for issue #6:

- Pi DNS backups are a Pi-local safety net, not disaster-proof recovery.
- Backup artifacts live under ignored `state/backups/` and must stay local-only.
- Raw `AdGuardHome.yaml` exists only in local backup state or other operator-held material, not in Git.
- Git restore is partial for AdGuard Home because the repo contains sanitized summaries and policy, not raw runtime config.
- Git restore is useful for Unbound tracked snapshots, repo docs, scripts, systemd templates, and validation helpers.
- Full AdGuard Home restore requires operator-held raw backup/secret material and a separate approved restore task.
- The first off-Pi copy target is the Mac mini encrypted sparsebundle at `/Users/yasse/InfraBackups/pi-dns-backups.sparsebundle`.
- The first verified off-Pi Pi DNS backup is `dns-backup-20260429_030452`.
- A safe restore drill to `/tmp/pi-dns-restore-drill/` passed on 2026-04-29 without touching live services.

Before Opti/Proxmox expansion:

- Move or extend the interim Mac mini target to an external/off-Pi USB-SSD target.
- Record a completed restore-test result for Opti/Proxmox workload backups.
- Decide whether to apply DNS backup retention pruning after reviewing dry-run output.
- Decide long-term encryption/key handling policy for off-Pi backups.

## 4. Clone repo

Read-only until the clone itself; cloning writes only to the operator home directory.

```bash
mkdir -p ~/repos
cd ~/repos
git clone git@github.com:Donkens/Infra.git infra
cd ~/repos/infra
```

If `infra` already exists, do not overwrite it blindly. Inspect it first:

```bash
cd ~/repos/infra
git status --short --branch
git remote -v
```

## 5. Verify repo

Read-only checks:

```bash
git status --short --branch
git remote -v
test -f AGENTS.md
test -f docs/adguard-home-change-policy.md
test -f docs/raspberry-pi-baseline.md
test -f config/unbound/unbound.conf
test -d config/unbound/unbound.conf.d
find config/unbound/unbound.conf.d -maxdepth 1 -type f -name '*.conf' | sort
```

Expected:

- Branch is the intended restore branch, normally `main`.
- Remote points to `git@github.com:Donkens/Infra.git`.
- `AGENTS.md` exists and is treated as canonical policy.
- Unbound snapshot files exist under `config/unbound/`.

Do not continue if the repo is missing `AGENTS.md`, `docs/adguard-home-change-policy.md`, or Unbound snapshots.

## 6. Install base packages

**Operator-only / approval required.** This changes system packages.

```bash
sudo apt update
sudo apt install -y git unbound dnsutils curl ca-certificates
```

Package purpose:

| Package | Purpose |
| --- | --- |
| `git` | Clone and inspect the infra repo. |
| `unbound` | Local recursive/cache resolver. |
| `dnsutils` | Provides `dig` for DNS smoke tests. |
| `curl` | Basic network/API checks when approved. |
| `ca-certificates` | TLS trust store for package/network tooling. |

Abort if package installation fails or if the host cannot reach the package repositories.

## 7. Restore Unbound from repo snapshots

Inputs from repo:

- `config/unbound/unbound.conf`
- `config/unbound/unbound.conf.d/*.conf`

Targets:

- `/etc/unbound/unbound.conf`
- `/etc/unbound/unbound.conf.d/`

**Operator-only / approval required.** The following writes to `/etc/unbound` and changes service state.

Create a timestamped local backup first if `/etc/unbound` exists:

```bash
TS=$(date +%Y%m%d-%H%M%S)
sudo cp -a /etc/unbound /etc/unbound.bak.$TS
```

Install repo snapshots:

```bash
sudo install -d -m 0755 /etc/unbound/unbound.conf.d
sudo install -m 0644 config/unbound/unbound.conf /etc/unbound/unbound.conf
sudo install -m 0644 config/unbound/unbound.conf.d/*.conf /etc/unbound/unbound.conf.d/
```

Validate before starting or restarting:

```bash
sudo /usr/sbin/unbound-checkconf /etc/unbound/unbound.conf
```

Enable and verify Unbound:

```bash
sudo systemctl enable --now unbound
systemctl is-active unbound.service
ss -tulpn | grep -E ':5335\b'
dig @127.0.0.1 -p 5335 cloudflare.com A +short
```

Expected:

- `/usr/sbin/unbound-checkconf` reports no errors.
- `unbound.service` is active.
- Unbound listens on `127.0.0.1:5335`.
- `dig` through port `5335` returns at least one A record.

Abort if `/usr/sbin/unbound-checkconf` fails. Do not start/restart Unbound with invalid config.

## 8. Restore AdGuard safely

AdGuard Home restore must follow `docs/adguard-home-change-policy.md`.

Rules:

- Install or recreate AdGuard Home separately from this repo restore.
- Prefer Web UI first.
- Prefer authenticated API second, only with non-logged secret input.
- Use YAML fallback only according to `docs/adguard-home-change-policy.md`.
- `config/adguardhome/AdGuardHome.summary.sanitized.yml` is a summary/counts reference, not a raw restore source.
- Raw `AdGuardHome.yaml` must not be printed, committed, or pasted.
- Blind copy of `/home/pi/AdGuardHome` is forbidden.

Sanitized target traits to recreate:

| Setting area | Expected restore target |
| --- | --- |
| Upstream DNS | Local Unbound at `127.0.0.1:5335`. |
| Plain DNS | Listen on port `53`. |
| UI | Listen on port `3000`. |
| TLS/HTTPS/DoT | Recreate only with operator-held certificate material. |
| Filtering | Recreate from policy/reference, not by pasting raw user rules. |
| Query log | Memory-only file logging policy as documented in baseline. |

**Operator-only / approval required** for any AdGuard install, config change, service restart, or YAML fallback.

AdGuard validation, after an approved restore:

```bash
systemctl is-active AdGuardHome.service
ss -tulpn | grep -E ':(53|853|3000|443)\b'
dig @127.0.0.1 cloudflare.com A +short
dig @192.168.1.55 cloudflare.com A +short
```

If YAML fallback is used, validate with the installed AdGuard Home binary before starting the service, as described in `docs/adguard-home-change-policy.md`.

## 9. Systemd health timers

Install or verify health timers only after Unbound and AdGuard Home are restored.

Health units in repo:

- `systemd/units/dns-health.service`
- `systemd/timers/dns-health.timer`
- `systemd/units/backup-health.service`
- `systemd/timers/backup-health.timer`

**Operator-only / approval required.** Installing units writes to `/etc/systemd/system` and changes systemd state.

```bash
sudo install -m 0644 systemd/units/dns-health.service /etc/systemd/system/dns-health.service
sudo install -m 0644 systemd/timers/dns-health.timer /etc/systemd/system/dns-health.timer
sudo install -m 0644 systemd/units/backup-health.service /etc/systemd/system/backup-health.service
sudo install -m 0644 systemd/timers/backup-health.timer /etc/systemd/system/backup-health.timer
sudo systemctl daemon-reload
sudo systemctl enable --now dns-health.timer backup-health.timer
```

Verify:

```bash
systemctl list-timers --all --no-pager
systemctl is-active dns-health.timer
systemctl is-active backup-health.timer
```

`infra-auto-sync.service` and `infra-auto-sync.timer` must be handled separately because they can commit and push to GitHub. Do not enable them during restore unless a separate approved plan explicitly covers auto-sync behavior, credentials, staging scope, and push risk.

## 10. DNS smoke tests

Run after Unbound and AdGuard Home are restored.

Read-only checks:

```bash
systemctl is-active AdGuardHome.service
systemctl is-active unbound.service
dig @127.0.0.1 -p 5335 cloudflare.com A +short
dig @127.0.0.1 cloudflare.com A +short
dig @192.168.1.55 cloudflare.com A +short
```

Expected:

- `AdGuardHome.service` is active.
- `unbound.service` is active.
- Unbound resolves through `127.0.0.1:5335`.
- AdGuard resolves through localhost port `53`.
- LAN-facing Pi DNS resolves through `192.168.1.55`.

Optional read-only checks:

```bash
ss -tulpn | grep -E ':(53|5335|853|3000|443)\b'
git status --short --branch
```

## 11. Rollback and abort criteria

Abort immediately if:

- `/usr/sbin/unbound-checkconf` fails.
- AdGuard Home config validation fails.
- Raw secrets risk being printed to terminal, logs, docs, shell history, or chat.
- A command would overwrite live runtime state without a timestamped local backup.
- A command would touch raw backups without a separate approved restore task.

Rollback principles:

- Use timestamped local backups created during this restore.
- Roll back Unbound by restoring the timestamped `/etc/unbound.bak.TIMESTAMP` copy.
- Roll back AdGuard only according to `docs/adguard-home-change-policy.md` and local operator-held backups.
- Do not roll back by blindly copying repo directories over live runtime directories.
- Do not use `git clean` for Pi runtime or backup state.

Example Unbound rollback, operator-only / approval required:

```bash
TS=$(date +%Y%m%d-%H%M%S)
sudo systemctl stop unbound
sudo mv /etc/unbound /etc/unbound.failed.$TS
sudo cp -a /etc/unbound.bak.TIMESTAMP /etc/unbound
sudo /usr/sbin/unbound-checkconf /etc/unbound/unbound.conf
sudo systemctl start unbound
```

Do not run rollback commands until the exact backup timestamp and blast radius are confirmed.

## 12. What not to restore

Do not restore these as part of the standard repo restore:

- Raw `state/backups/` content without a separate restore task.
- Raw query logs.
- Sessions, tokens, credentials, private keys, or password hashes.
- Certificate private keys.
- Blind `/home/pi/AdGuardHome` directory copies.
- Runtime sockets, locks, PID files, caches, or device state.
- Mac working-copy state.
- `infra-auto-sync.service/timer` without a separate auto-sync approval plan.

Do not run `git clean` against Pi runtime/backups.

## 13. Final success criteria

Restore is successful when:

- Repo is cloned and verified.
- `AGENTS.md` and restore-related docs are present.
- Unbound is active on `127.0.0.1:5335`.
- AdGuard Home is active on port `53`.
- DNS smoke tests pass through Unbound, local AdGuard, and `192.168.1.55`.
- `dns-health.timer` and `backup-health.timer` are active if installed.
- No secrets, raw AdGuard config, raw backups, raw logs, credentials, sessions, tokens, private keys, or certificate private keys were printed or committed.
- No commit or push happened as part of restore unless a separate approved Git task explicitly required it.
