# Opti backup and restore-test checklist

First Proxmox VM restore-test completed 2026-05-03 (Phase 2B). A Pi DNS off-Pi backup restore drill was completed on 2026-04-29.

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

## Completed restore tests

### 2026-05-03 — Proxmox VM 101 (haos) restore-test — Phase 2B

| Field | Value |
| --- | --- |
| Date | 2026-05-03 |
| Operator | Yasse/Claude |
| Source backup | `/var/lib/vz/dump/vzdump-qemu-101-2026_05_03-22_48_45.vma.zst` (2.12 GB, zstd, SHA256 `cd54ef0c…`) |
| Off-host copy | `/Users/yasse/InfraBackups/proxmox-dumps/vzdump-qemu-101-2026_05_03-22_48_45.vma.zst` |
| Restore target | VMID `199` (test-only, destroyed after drill) |
| Restore command | `qmrestore … 199 --storage local-lvm` |
| Import time | ~10 seconds |
| Safety modifications | `net0` deleted (prevent IP conflict with live HAOS at 192.168.30.20), `onboot=0`, renamed to `haos-restore-test-199` |
| Boot result | `status: running` after 52 s; disk I/O observed (544 MB read, 75 MB written) confirming HAOS initialised from restored disk |
| Consistency note | Backup is crash-consistent (snapshot mode, QGA fs-freeze skipped — known WARN); HAOS booted cleanly from crash-consistent image |
| Cleanup | `qm stop 199 --timeout 30` then `qm destroy 199 --purge`; LVM volumes `vm-199-disk-0` and `vm-199-disk-1` removed |
| Live VM 101 state | `running` throughout — no service interruption |
| HAOS health after | `issues: []`, `suggestions: []`, `unhealthy: []`, `unsupported: []` |
| Visual console | Not verified via SSH; Proxmox Web UI noVNC would show full boot screen — runtime `status: running` + disk I/O at 52 s is sufficient evidence |
| Result | **PASS** |
| Follow-ups | Scheduled backup job to permanent off-host storage (USB SSD / NFS / PBS); quarterly restore-test cadence |

### 2026-04-29 — Pi DNS off-Pi backup drill

| Field | Value |
| --- | --- |
| Date | 2026-04-29 |
| Operator | Yasse/Codex |
| Source backup path / timestamp | Pi `/home/pi/repos/infra/state/backups/latest` -> `dns-backup-20260429_030452` |
| Target / safe restore location | Encrypted Mac mini sparsebundle `/Users/yasse/InfraBackups/pi-dns-backups.sparsebundle`; mounted copy at `/Volumes/pi-dns-backups/pi/state-backups/`; drill path `/tmp/pi-dns-restore-drill/` |
| Files restored | Latest Pi DNS backup directory copied to safe temp path; raw file contents were not printed |
| Ownership / permissions checked | Metadata copied and checksums validated; Mac copy is for recovery staging, not direct live restore |
| Services touched | None |
| Validation commands | `shasum -a 256 -c meta/SHA256SUMS.txt`; metadata/count checks; no live restore |
| Result | PASS |
| Follow-ups | USB-SSD/offsite migration; retention `--apply` decision; long-term encryption/key handling policy; optional scheduled off-Pi sync |

Recurring off-Pi sync is handled by `/Users/yasse/repos/Infra/scripts/maintenance/sync-pi-dns-backups-offpi.sh` via LaunchAgent `com.yasse.pi-dns-backups.offpi-sync`. Restore drills remain manual and are not triggered by the recurring sync job.

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
