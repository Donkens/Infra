# Runbook: Pi Sudo Wrapper Live Install

Use this runbook when the repo-only wrapper model has been synced to `/home/pi/repos/infra`, but `pi` cannot run the installer because `pi` intentionally does not have broad sudo.

Do not use `sudo -S`, askpass, or broad sudo for `pi`.

## Current Blocker: No Root/Admin Path From pi SSH Session

Status observed after manual install attempt:

- SSH to Pi as `pi` worked.
- `su -` was attempted.
- Root authentication failed:

```text
su: Autentiseringsfel
```

No live install happened:

- no writes to `/usr/local/sbin/`
- no writes to `/etc/sudoers.d/`
- no service reload/restart

This confirms there is currently no usable root/admin path from the `pi` SSH session. Phase 1 files can remain staged/available in `/home/pi/repos/infra`, but do not install live until a separate trusted admin path exists.

Next safe step: create or use a separate trusted admin user such as `cockpitadmin` via local console or another already-authorized admin path.

Do not:

- restore broad sudo to `pi`
- add `pi` to the `sudo` group
- use `sudo -S` password piping
- use an askpass workaround

## Preconditions

- Phase 1 repo files are present under `/home/pi/repos/infra`.
- `pi` is not in the `sudo` group.
- `pi` does not have broad sudo.
- `/usr/local/sbin/infra-backup-dns-export` is preserved.
- Legacy direct sudoers may still exist and are handled as `WARN` until Phase 3 cleanup.

## Path A — Local Root Shell On Pi

Use a local console or another already trusted root/admin session on the Pi.

Run:

```bash
cd /home/pi/repos/infra
sudo scripts/install/install-pi-sudo-wrappers.sh
```

Verify:

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

## Path B — Temporary Admin User / cockpitadmin

Create or use a separate admin user, not `pi`.

Use that admin user to run:

```bash
cd /home/pi/repos/infra
sudo scripts/install/install-pi-sudo-wrappers.sh
```

After install, verify:

```bash
id pi
sudo -l -U pi
ls -l /usr/local/sbin/infra-*
```

Confirm:

- `pi` is still not in the `sudo` group.
- `pi` still lacks broad sudo.
- `sudo -l -U pi` shows only explicit wrappers plus any remaining legacy `WARN` rules.
- legacy direct sudoers cleanup is deferred to Phase 3 after wrappers are verified.

Legacy direct sudoers to remove later in a separate approved Phase 3:

- `/bin/systemctl restart AdGuardHome`
- `/bin/systemctl restart unbound`
- `/usr/local/bin/unbound-control flush_zone *`
- `/usr/local/bin/unbound-control flush *`

## Failure Stops

Stop if:

- `visudo` fails.
- `pi` is in the `sudo` group.
- broad sudo is detected for `pi`.
- any new wrapper is writable by `pi`.
- `/usr/local/sbin/infra-backup-dns-export` would be replaced or removed.

## Rollback

Rollback is a live system change and requires an explicit approval.

Remove the new sudoers drop-in:

```bash
sudo rm /etc/sudoers.d/infra-pi-wrappers
```

Remove only wrappers installed from `scripts/sudo-wrappers/`:

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

Preserve:

```bash
/usr/local/sbin/infra-backup-dns-export
```

Validate after rollback:

```bash
sudo visudo -c
sudo -l -U pi
```

## Related

- [Pi sudo wrapper model](pi-sudo-wrapper-model.md)
- [Security policy](../docs/security/pi-sudo-wrapper-model.md)
