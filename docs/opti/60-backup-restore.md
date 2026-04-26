# Backup and restore policy

## Initial destination

Use an external USB-SSD first. Offsite/Backblaze B2 can be added later after local backups and restore tests are boring and repeatable.

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

## Vaultwarden gate

Do not deploy Vaultwarden until:

1. Backup destination exists.
2. Backup process is documented.
3. Restore-test is documented and completed.
