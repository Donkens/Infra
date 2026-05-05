# Runbook: Pi Sudo Wrapper Model

Use this runbook to install or verify the Pi infra sudo wrapper model.

Do not use this runbook to restore broad sudo for `pi`.

Live install requires a root/admin path because `pi` intentionally cannot install its own sudo allowlist. Use [Pi sudo wrapper live install](pi-sudo-wrapper-live-install.md) for the manual root/admin install procedure.

## Phase 0 — Recon

Read-only only.

Verify the target host:

```bash
hostname
whoami
id
pwd
uname -a
git -C /home/pi/repos/infra status --short --branch || true
```

Inspect current privilege and runtime state:

```bash
sudo -l -U pi || true
id pi
ls -l /usr/local/sbin/infra-* 2>/dev/null || true
systemctl is-active unbound AdGuardHome || true
systemctl list-timers --all | grep -E 'dns-health|backup-health|infra-auto-sync' || true
command -v unbound-checkconf || true
```

Expected findings before migration:

- `pi` is not in `sudo` group.
- `/usr/local/sbin/infra-backup-dns-export` may already exist and must be preserved.
- Direct legacy rules may still exist for `systemctl restart` and `unbound-control flush`.

Stop and report before writes.

## Phase 1 — Repo-Only

Edit only tracked repo files:

- `scripts/sudo-wrappers/`
- `scripts/install/install-pi-sudo-wrappers.sh`
- `docs/security/pi-sudo-wrapper-model.md`
- `runbooks/pi-sudo-wrapper-model.md`
- `inventory/services.md`
- related docs/index files as needed

Run repo-only checks:

```bash
shellcheck scripts/sudo-wrappers/* scripts/install/install-pi-sudo-wrappers.sh
python3 scripts/ci/check-markdown-links.py
git diff --check
git status --short
```

If `shellcheck` is not installed:

```bash
bash -n scripts/sudo-wrappers/* scripts/install/install-pi-sudo-wrappers.sh
```

Stop after Phase 1 and ask for explicit `GO` before installing to live system paths.

## Phase 2 — Live Install

Requires explicit approval.

If `pi` cannot run the installer because sudo is already hardened, use [Pi sudo wrapper live install](pi-sudo-wrapper-live-install.md). Do not use `sudo -S`, askpass, or broad sudo for `pi`.

Run on Pi:

```bash
cd /home/pi/repos/infra
sudo scripts/install/install-pi-sudo-wrappers.sh
```

The installer:

- requires root
- installs wrappers to `/usr/local/sbin/`
- sets owner `root:root`
- sets mode `0755`
- installs `/etc/sudoers.d/infra-pi-wrappers`
- validates sudoers with `visudo -cf`
- preserves `/usr/local/sbin/infra-backup-dns-export`
- reports legacy direct sudo rules as `WARN`

## Verification

Safe default verification:

```bash
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

Do not run these without separate explicit approval:

```bash
sudo /usr/local/sbin/infra-dns-restart
sudo /usr/local/sbin/infra-adguard-safe-restart
```

## Legacy Cleanup

After wrapper verification, plan a separate sudoers cleanup for legacy direct rules:

- `/bin/systemctl restart AdGuardHome`
- `/bin/systemctl restart unbound`
- `/usr/local/bin/unbound-control flush_zone *`
- `/usr/local/bin/unbound-control flush *`

Do not remove them silently during install. Remove only with a separate approved plan and verify `sudo -l -U pi` afterward.

## Rollback

Rollback requires explicit approval.

```bash
sudo rm /etc/sudoers.d/infra-pi-wrappers
sudo rm /usr/local/sbin/infra-dns-status
sudo rm /usr/local/sbin/infra-unbound-validate-reload
sudo rm /usr/local/sbin/infra-dns-reload
sudo rm /usr/local/sbin/infra-dns-restart
sudo rm /usr/local/sbin/infra-adguard-safe-restart
sudo rm /usr/local/sbin/infra-health-report
sudo rm /usr/local/sbin/infra-backup-health-check
sudo rm /usr/local/sbin/infra-restore-drill-check
sudo visudo -c
sudo -l -U pi
```

Do not remove `/usr/local/sbin/infra-backup-dns-export` unless a separate approved backup-export migration says so.
