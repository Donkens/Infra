# Pi SD card disaster restore

Scope: recover the Raspberry Pi DNS node after SD card failure or full OS rebuild.

This runbook is high-level by design. Do not paste raw secrets, raw backup contents, private keys, password hashes, cookies, tokens, or raw `AdGuardHome.yaml` into docs, issues, commits, or chat.

## What Git can restore

- Infra repo docs, scripts, runbooks, inventories, and systemd templates.
- Unbound tracked snapshots under `config/unbound/`.
- Sanitized AdGuard Home summary under `config/adguardhome/`.
- Validation helpers such as `scripts/maintenance/check-dns-authority.sh` and `scripts/maintenance/check-backups.sh`.

## What Git cannot restore

- Raw `AdGuardHome.yaml`.
- Raw AdGuard Home work data, query logs, sessions, or runtime directories.
- Secrets, private keys, TLS private material, credentials, or password hashes.
- Pi-local backup artifacts under `state/backups/`.

## Required external/operator-held material

- SSH access path for the rebuilt Pi.
- GitHub access for `git@github.com:Donkens/Infra.git`.
- Operator-held raw AdGuard Home backup material, handled outside Git.
- Any required TLS certificate/private-key material, handled outside Git.
- Backup destination or external copy if the Pi-local SD card is unavailable.
- Package/install notes for the target Pi OS version.

## High-level restore sequence

1. Reinstall Raspberry Pi OS and restore network/SSH access.
2. Clone the infra repo:

   ```bash
   mkdir -p ~/repos
   cd ~/repos
   git clone git@github.com:Donkens/Infra.git infra
   cd ~/repos/infra
   ```

3. Install required packages after an approved package-change plan.
4. Restore Unbound from tracked snapshots under `config/unbound/`.
5. Restore AdGuard Home from operator-held raw backup material according to `docs/adguard-home-change-policy.md`.
6. Reinstall required systemd timers/services from repo templates after an approved systemd plan.
7. Validate DNS and repo state before declaring the Pi authoritative again.

## Validation checklist

Run only after the relevant services/configs have been restored according to an approved Phase 2 plan.

```bash
sudo unbound-checkconf
scripts/maintenance/check-dns-authority.sh
scripts/maintenance/check-backups.sh
git status --short --branch
```

Expected:

- `unbound-checkconf` passes.
- DNS authority check passes.
- Backup health check passes or reports only expected local-only backup state.
- Git working tree is clean except intentionally ignored local state.

## Recovery gates

- Do not enable `infra-auto-sync` until repo sync, staging scope, credentials, and push behavior are verified.
- Do not deploy Opti/Proxmox heavy workloads or Vaultwarden until an off-Pi backup destination and completed restore drill are documented.
- Do not treat sanitized AdGuard summaries as a full restore source.
