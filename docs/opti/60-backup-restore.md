# Backup and restore policy

## Current status

External USB/offsite backup is planned, not live. Current Pi DNS backups under `state/backups/` are local-only safety net data and are not enough for Opti/Proxmox expansion.

Do not rely on Pi-local `state/backups/` as the only recovery path for Opti services, HAOS, Vaultwarden, or other heavy workloads.

## Initial destination

Use an external USB-SSD or equivalent off-Pi encrypted backup destination first. Offsite/Backblaze B2 can be added later after local backups and restore tests are boring and repeatable.

## Backup scope

Include:

- HAOS backups
- Proxmox VM configs
- `/srv/compose`
- `/srv/appdata`
- important exports

Exclude initially:

- media
- downloads
- cache

## Restore-test requirement

Backups are not considered real until a restore-test is documented and completed. Use `runbooks/opti-backup-restore-test.md` for the checklist.

Complete a restore drill before heavy workloads, Vaultwarden, or additional critical services are deployed on Opti/Proxmox.

## Vaultwarden gate

Do not deploy Vaultwarden until:

1. Backup destination exists.
2. Backup process is documented.
3. Restore-test is documented and completed.
