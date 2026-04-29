# Opti backup and restore-test checklist

No completed Opti/Proxmox restore test is documented yet.

## Backup destination

Start with an external USB-SSD or equivalent off-Pi encrypted backup destination. Add offsite/Backblaze B2 later.

## Backup scope

- HAOS backups
- Proxmox VM configs
- `/srv/compose`
- `/srv/appdata`
- important exports

Do not include media, downloads, or cache in the initial scope.

## Restore-test

1. Document backup source and destination.
2. Run a backup.
3. Restore a representative file or app dataset into a safe test location.
4. Confirm ownership and permissions.
5. Document the result.

## Restore test result template

Copy this section into the issue/runbook entry for each completed drill.

| Field | Value |
| --- | --- |
| Date | |
| Operator | |
| Source backup path / timestamp | |
| Target / safe restore location | |
| Files restored | |
| Ownership / permissions checked | |
| Services touched | |
| Validation commands | |
| Result | |
| Follow-ups | |

## Vaultwarden gate

Vaultwarden must wait until backup destination, backup process, and restore-test are complete.
