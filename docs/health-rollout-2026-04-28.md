# Health unit hardening rollout — 2026-04-28

> Historical record of the live hardening rollout for `dns-health` and `backup-health` units.

## Status summary

| Unit | Repo hardening | Live install | Manual one-shot | Automatic timer |
|---|---|---|---|---|
| `dns-health.service` | committed | installed | PASS 21:20:43 | PASS 21:30:50 |
| `backup-health.service` | committed | installed | PASS 21:20:43 | PENDING — next run after 2026-04-29 09:20:43 |
| `infra-auto-sync.service` | WorkingDirectory + TimeoutStartSec added to repo template | **not touched live** | n/a | n/a |

## Hardening directives applied

```
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
PrivateTmp=true
ReadWritePaths=/home/pi/repos/infra/logs /home/pi/repos/infra/state
TimeoutStartSec=2min
```

## Installed live paths

- `/etc/systemd/system/dns-health.service`
- `/etc/systemd/system/backup-health.service`

## Backup of pre-hardening units

Original unit files backed up to Pi-local path before install:

```
/home/pi/systemd-unit-backups-20260428-212025/
```

This path is Pi-local only and is not tracked in Git.

## Verification evidence

| File | Timestamp | Content |
|---|---|---|
| `state/dns-health.last` | 2026-04-28 21:30:50 | status=OK (automatic timer run) |
| `state/backup-health.last` | 2026-04-28 21:20:43 | status=OK (manual one-shot) |
| `logs/dns-health-fail.log` | 2026-03-15 entry | historical only — pre-hardening baseline |

## Rollback

> GO ROLLBACK — only execute if an explicit rollback is approved.

```bash
# Restore dns-health.service from backup
sudo cp /home/pi/systemd-unit-backups-20260428-212025/dns-health.service \
        /etc/systemd/system/dns-health.service
sudo systemctl daemon-reload

# Restore backup-health.service from backup
sudo cp /home/pi/systemd-unit-backups-20260428-212025/backup-health.service \
        /etc/systemd/system/backup-health.service
sudo systemctl daemon-reload
```

## Related

- [docs/automation.md](automation.md)
- [runbooks/verify-backup-health-timer.md](../runbooks/verify-backup-health-timer.md)
- [docs/raspberry-pi-baseline.md](raspberry-pi-baseline.md)
