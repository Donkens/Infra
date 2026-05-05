# Pi Sudo Wrapper Model

Status: planned repo source, pending live install
Updated: 2026-05-05

## Summary

`pi` must not have broad sudo. Infra operations that require root should go through root-owned, fixed-argument wrappers in `/usr/local/sbin/`, with exact sudoers allowlist entries. This keeps agent and operator commands predictable, auditable, and narrow.

This model implements GitHub issue #14 and preserves the issue #13 boundary: Cockpit administration should use a separate admin user such as `cockpitadmin`, not broad sudo for `pi`.

Live install requires a root/admin path because `pi` intentionally cannot install its own sudo allowlist. Use [Pi sudo wrapper live install](../../runbooks/pi-sudo-wrapper-live-install.md) for the manual install procedure.

## Policy

Allowed:

- `pi ALL=(root) NOPASSWD: /usr/local/sbin/infra-dns-status`
- `pi ALL=(root) NOPASSWD: /usr/local/sbin/infra-unbound-validate-reload`
- `pi ALL=(root) NOPASSWD: /usr/local/sbin/infra-dns-reload`
- `pi ALL=(root) NOPASSWD: /usr/local/sbin/infra-dns-restart`
- `pi ALL=(root) NOPASSWD: /usr/local/sbin/infra-adguard-safe-restart`
- `pi ALL=(root) NOPASSWD: /usr/local/sbin/infra-health-report`
- `pi ALL=(root) NOPASSWD: /usr/local/sbin/infra-backup-health-check`
- `pi ALL=(root) NOPASSWD: /usr/local/sbin/infra-restore-drill-check`

Preserved existing wrapper:

- `/usr/local/sbin/infra-backup-dns-export`

Never allow:

- `pi ALL=(ALL) NOPASSWD: ALL`
- `pi ALL=(ALL) ALL`
- `systemctl *`
- `journalctl *`
- `apt *`
- `chmod *`
- `chown *`
- editors against `/etc/*`
- unrestricted `iptables`, `nft`, or `ufw`
- direct raw access patterns that print `/home/pi/AdGuardHome/AdGuardHome.yaml`

## Legacy Risks

Phase 0 on 2026-05-05 showed these direct sudo rules still present for `pi`:

- `/bin/systemctl restart AdGuardHome`
- `/bin/systemctl restart unbound`
- `/usr/local/bin/unbound-control flush_zone *`
- `/usr/local/bin/unbound-control flush *`

These are legacy/risk rules. The installer reports them as `WARN` and tells the operator to migrate usage to the new wrappers. It does not silently remove them, because sudoers cleanup is a separate live security change requiring explicit approval.

## Wrapper Inventory

| Wrapper | Purpose | Risk | Live verification policy |
|---|---|---:|---|
| `infra-dns-status` | Compact DNS/service/timer/log/disk status | Low | Safe after install |
| `infra-unbound-validate-reload` | `unbound-checkconf`, reload `unbound`, verify active, optional local DNS probes | Medium | Safe after install with approval |
| `infra-dns-reload` | Validate Unbound, reload Unbound, verify AdGuard/Unbound and DNS smoke tests | Medium | Safe after install with approval |
| `infra-dns-restart` | Restart `unbound` and `AdGuardHome` after validation | High | Do not run without separate approval |
| `infra-adguard-safe-restart` | Confirm AdGuard config exists, optional export wrapper, restart AdGuard, DNS smoke tests | High | Do not run without separate approval |
| `infra-health-report` | Compact host/service/timer/failed-unit/disk/journal report | Low | Safe after install |
| `infra-backup-health-check` | Read-only backup freshness/checksum readiness check | Low | Safe after install |
| `infra-restore-drill-check` | Read-only restore drill readiness check | Low | Safe after install |

All wrappers:

- use `bash`, `set -euo pipefail`, and `IFS=$'\n\t'`
- accept no arbitrary user input
- avoid `eval`
- use fixed paths or command resolution for `unbound-checkconf`
- use `timeout` around commands that can hang
- avoid printing raw secrets or raw AdGuard config
- emit compact `CHECK:`, `RESULT:`, and `STATUS:` lines

## Cockpit Boundary

Cockpit is an admin UI and should not be made safe by giving `pi` broad sudo. Use a separate admin account for Cockpit administration, for example `cockpitadmin`, with its own auth and audited privilege policy.

`pi` remains the DNS service account and repo automation user. Its sudo surface should be limited to fixed infra wrappers only.

## Agent Command Policy

Agents may request these commands after live install:

```bash
sudo /usr/local/sbin/infra-dns-status
sudo /usr/local/sbin/infra-health-report
sudo /usr/local/sbin/infra-backup-health-check
sudo /usr/local/sbin/infra-restore-drill-check
sudo /usr/local/sbin/infra-unbound-validate-reload
sudo /usr/local/sbin/infra-dns-reload
```

Agents must not request these without separate explicit approval:

```bash
sudo /usr/local/sbin/infra-dns-restart
sudo /usr/local/sbin/infra-adguard-safe-restart
```

Agents must never request broad replacements such as:

```bash
sudo systemctl restart AdGuardHome
sudo systemctl restart unbound
sudo unbound-control flush_zone '*'
sudo unbound-control flush '*'
```

## Verification

Repo-only:

```bash
shellcheck scripts/sudo-wrappers/* scripts/install/install-pi-sudo-wrappers.sh
python3 scripts/ci/check-markdown-links.py
git diff --check
git status --short
```

If `shellcheck` is unavailable:

```bash
bash -n scripts/sudo-wrappers/* scripts/install/install-pi-sudo-wrappers.sh
```

Live install verification, after explicit approval:

```bash
cd /home/pi/repos/infra
sudo scripts/install/install-pi-sudo-wrappers.sh
id pi
sudo -l -U pi
ls -l /usr/local/sbin/infra-*
sudo /usr/local/sbin/infra-dns-status
sudo /usr/local/sbin/infra-health-report
sudo /usr/local/sbin/infra-backup-health-check
sudo /usr/local/sbin/infra-restore-drill-check
sudo /usr/local/sbin/infra-unbound-validate-reload
sudo /usr/local/sbin/infra-dns-reload
```

Do not run `infra-dns-restart` or `infra-adguard-safe-restart` during default verification.

## Rollback

Rollback is a live system change and requires explicit approval.

Remove the new sudoers drop-in:

```bash
sudo rm /etc/sudoers.d/infra-pi-wrappers
```

Remove only the new wrappers created by this model:

```bash
sudo rm /usr/local/sbin/infra-dns-status
sudo rm /usr/local/sbin/infra-unbound-validate-reload
sudo rm /usr/local/sbin/infra-dns-reload
sudo rm /usr/local/sbin/infra-dns-restart
sudo rm /usr/local/sbin/infra-adguard-safe-restart
sudo rm /usr/local/sbin/infra-health-report
sudo rm /usr/local/sbin/infra-backup-health-check
sudo rm /usr/local/sbin/infra-restore-drill-check
```

Do not remove `/usr/local/sbin/infra-backup-dns-export` as part of this rollback unless a separate approved plan replaces the backup export model.

Validate after rollback:

```bash
sudo visudo -c
sudo -l -U pi
```
