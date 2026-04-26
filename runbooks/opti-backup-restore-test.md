# Opti backup and restore-test checklist

## Backup destination

Start with external USB-SSD. Add offsite/Backblaze B2 later.

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

## Vaultwarden gate

Vaultwarden must wait until backup destination, backup process, and restore-test are complete.
