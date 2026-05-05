# Agent Start Guide

Status: baseline
Purpose: fast entrypoint for Codex, Claude, and other agents working in this repo.

## Start here

Read this file first when you need a quick map of the infrastructure, repo layout, and safety rules.

If task-specific instructions conflict with this guide, prefer the stricter safety rule and stop before making writes.

## Core rules

1. Verify host identity before acting.
2. Phase 0 is read-only.
3. Phase 1 is plan/rollback.
4. Phase 2 writes only after explicit approval.
5. Never print or commit private keys, tokens, passwords, raw `.env`, raw `AdGuardHome.yaml`, HA `secrets.yaml`, Proxmox secrets, or raw backup archives.
6. Prefer sanitized docs and fingerprints over raw runtime dumps.
7. Keep `ForwardAgent no` unless a narrow documented flow explicitly needs it.
8. Do not use routers, HAOS, Pi, or Docker VM as jump hosts unless explicitly documented.

## Current host map

| Host | Role | User | Repo path | Notes |
|---|---|---|---|---|
| `mini` | Primary admin client / Mac mini | `yasse` | `/Users/yasse/repos/Infra` | Primary client for GitHub, scripts, DSP, UniFi/admin work. |
| `mbp` | Secondary admin client / MacBook Pro | `hd` | `/Users/hd/repos/Infra` | Intel/OCLP secondary admin client. |
| `pi` | DNS node | `pi` | `/home/pi/repos/infra` | Lowercase repo path. Runs AdGuard Home + Unbound. |
| `udr` | UDR-7 gateway/router | `root` | n/a | SSH target only; root user expected. |
| `opti` | Proxmox/compute host | `root` | n/a / future | Treat as sensitive host. |
| `ha` | HAOS SSH add-on | `hassio` | n/a | Admin target only; do not dump HA secrets/tokens. |
| `docker` | Docker VM | `yasse` | n/a | Docker VM 102. SSH alias is host-local; verify before use. On Mac mini, `ssh docker` may work if configured. On this MBP, `ssh docker` alias is stale/broken; use `ssh -i ~/.ssh/id_ed25519_mbp yasse@192.168.30.10`. |

## Which docs to read

| Task type | Read first |
|---|---|
| Security overview | `docs/security/README.md` |
| SSH/auth/key work | `docs/security/auth-baseline.md`, `docs/security/ssh-hardening.md` |
| Secrets handling | `docs/security/secrets-policy.md` |
| DNS / AdGuard / Unbound | `docs/security/dns-security.md` |
| Firewall / VLAN / UDR rules | `docs/security/firewall-baseline.md` |
| Docker VM SSH bootstrap | `runbooks/docker-vm-ssh-bootstrap.md`, `docs/security/docker-auth-side-verification-2026-05-04.md` |
| Pi cleanup | `docs/pi-cleanup-audit-2026-05-01.md` |
| Opti/Proxmox work | `docs/opti/` and related runbooks |
| Scripts | `scripts/README.md` if present, then inspect script headers before running |

## Known current state

| Area | State |
|---|---|
| Security docs | Auth, SSH hardening, secrets, DNS security, and firewall baseline are documented. |
| Mac mini GitHub auth | Uses dedicated `id_ed25519_github` key. |
| Pi GitHub auth | Dedicated Pi GitHub key works for repo sync. |
| Docker VM SSH | Live with host-local alias caveat. On Mac mini, `ssh docker` may work if configured. On this MBP, `ssh docker` alias is stale/broken. Verified MBP access path: `ssh -i ~/.ssh/id_ed25519_mbp yasse@192.168.30.10`. Agents must verify SSH alias before assuming it works. |
| UDR | SSH target only; no private client keys observed on router. |
| HAOS | SSH add-on/admin target only; no private SSH keys observed in checked shell context. |
| Opti | Proxmox host; local private host key exists and must remain local. |

## Safe sync command

Run from Mac mini:

```bash
cd ~/repos/Infra && \
git pull --ff-only && \
git log --oneline -5 && \
echo && echo "=== MBP ===" && \
ssh mbp 'cd ~/repos/Infra && git pull --ff-only && git log --oneline -3 && git status --short --branch' && \
echo && echo "=== PI ===" && \
ssh pi 'cd ~/repos/infra && git pull --ff-only && git log --oneline -3 && git status --short --branch' && \
echo && echo "=== MINI ===" && \
git status --short --branch
```

## Safe host verification snippets

Mac/Linux host:

```bash
hostname
whoami
echo "$HOME"
uname -a
pwd
git status --short --branch 2>/dev/null || true
```

SSH key-only check:

```bash
ssh -o BatchMode=yes -o NumberOfPasswordPrompts=0 -o ConnectTimeout=5 <host> 'hostname; whoami; uname -a'
```

SSH config check:

```bash
ssh -G <host> | awk '/^(hostname|user|port|identityfile|identitiesonly|forwardagent|passwordauthentication|pubkeyauthentication) / { print }'
```

## Phase model

### Phase 0 — read-only

Allowed:

- inspect files
- inspect Git state
- inspect service status
- run safe query/health commands
- collect sanitized fingerprints and metadata

Not allowed:

- edits
- restarts
- deletes
- firewall writes
- secret dumps
- raw config dumps with credentials

### Phase 1 — plan

Must include:

- exact target host
- exact files/rules/services affected
- rollback plan
- verification commands
- expected risk

### Phase 2 — apply

Only after explicit approval.

Must include:

- minimal change
- backup where appropriate
- verification
- doc update
- repo sync

## Common stop conditions

Stop and ask for approval if:

- command would modify firewall rules
- command would restart DNS/router/Proxmox/HAOS services
- command would delete files/backups
- command would print raw secrets
- host identity does not match expected role
- repo has uncommitted changes you did not create
- a task requires password/token input

## Secret hygiene quick scan

From repo root:

```bash
grep -R "BEGIN OPENSSH PRIVATE KEY\|BEGIN RSA PRIVATE KEY\|BEGIN PRIVATE KEY" . --exclude-dir=.git || true
grep -R "github_pat_\|ghp_\|gho_\|ghu_\|ghs_\|ghr_" . --exclude-dir=.git || true
find . -name '.env' -o -name '*secrets*.yaml' -o -name 'AdGuardHome.yaml'
```

Expected: no raw private keys or secret-bearing runtime files tracked in Git.

## Good agent behavior

- Keep commands in English.
- Keep status/analysis concise and structured.
- Prefer tables/checklists for audits.
- Cite or name the exact doc/runbook used.
- Do not assume Mac and Pi paths are identical.
- Do not treat a mounted workspace path as proof of target host.
- Verify before acting, then verify after acting.

## Related entrypoints

- `docs/security/README.md`
- `docs/security/auth-baseline.md`
- `docs/security/ssh-hardening.md`
- `docs/security/secrets-policy.md`
- `docs/security/dns-security.md`
- `docs/security/firewall-baseline.md`
- `runbooks/docker-vm-ssh-bootstrap.md`
