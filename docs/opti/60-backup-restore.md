# Backup and restore policy

## Current status

An interim Mac mini off-Pi target is live for Pi DNS backups:

- Container: `/Users/yasse/InfraBackups/pi-dns-backups.sparsebundle`
- Volume: `pi-dns-backups`
- Mounted destination: `/Volumes/pi-dns-backups/pi/state-backups/`
- Source: Pi `/home/pi/repos/infra/state/backups/`
- First verified backup copied: `dns-backup-20260429_030452`
- First safe restore drill: PASS on 2026-04-29.
- Recurring sync script: `/Users/yasse/repos/Infra/scripts/maintenance/sync-pi-dns-backups-offpi.sh`
- LaunchAgent path: `/Users/yasse/Library/LaunchAgents/com.yasse.pi-dns-backups.offpi-sync.plist`
- Schedule target: daily `04:30`.

Current Pi DNS backups under `state/backups/` remain local-only safety net data on the Pi and are not enough by themselves for Opti/Proxmox expansion.

Do not rely on Pi-local `state/backups/` as the only recovery path for Opti services, HAOS, Vaultwarden, or other heavy workloads.

## Initial destination

Use the Mac mini encrypted sparsebundle as the interim target. Move the same process to an external USB-SSD or equivalent off-Pi encrypted backup destination next. Offsite/Backblaze B2 can be added later after local backups and restore tests are boring and repeatable.

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

The first Pi DNS off-Pi restore drill is documented, but Opti/Proxmox workload backups still need their own restore drill before heavy workloads, Vaultwarden, or additional critical services are deployed.

## Vaultwarden gate

Do not deploy Vaultwarden until:

1. Backup destination exists.
2. Backup process is documented.
3. Restore-test is documented and completed.
