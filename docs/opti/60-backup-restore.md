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
- Pi export wrapper: `/usr/local/sbin/export-pi-dns-backups`
- Narrow sudoers rule: `/etc/sudoers.d/pi-dns-backup-export`

Current Pi DNS backups under `state/backups/` remain local-only safety net data on the Pi and are not enough by themselves for Opti/Proxmox expansion.

Do not rely on Pi-local `state/backups/` as the only recovery path for Opti services, HAOS, Vaultwarden, or other heavy workloads.

Latest Proxmox Phase 0 audit on 2026-05-03 found:

- No Proxmox-level backup job exists yet.
- `/var/lib/vz/dump` is empty.
- HAOS has local backups, including `haos-onboarding-baseline-2026-05-02-full`
  and `haos-wiz-baseline-2026-05-03-full`, but local HAOS backups are not a
  Proxmox/off-host restore strategy.
- No confirmed off-host Proxmox/VM restore-test exists yet.

Proxmox dump audit on 2026-05-04:

- VM 101 interim backup verified present on Opti and Mac mini ✅
- VM 102 interim backup completed as Phase 1C-A — see section below ✅

## Proxmox interim vzdump — Phase 2A (2026-05-03)

First Proxmox-level backup of VM 101 (haos) completed on 2026-05-03 as an
interim snapshot. This is **not** a scheduled job and **not** the final backup
architecture. Proper external USB SSD, NFS/NAS, or Proxmox Backup Server (PBS)
target and a documented restore-test are still required before Vaultwarden or
other critical services are deployed.

| Field | Value |
| --- | --- |
| Backup file | `vzdump-qemu-101-2026_05_03-22_48_45.vma.zst` |
| Backup date | 2026-05-03 22:48:45 CEST |
| Mode | `snapshot` (crash-consistent; QGA fs-freeze skipped — agent not running) |
| Compression | `zstd` |
| Compressed size | `2.12 GB` |
| Sparse ratio | 92% zero data (thin VM) |
| Duration | 37 seconds |
| Local path | `/var/lib/vz/dump/vzdump-qemu-101-2026_05_03-22_48_45.vma.zst` |
| Off-host path | `/Users/yasse/InfraBackups/proxmox-dumps/vzdump-qemu-101-2026_05_03-22_48_45.vma.zst` |
| SHA256 | `cd54ef0cd9fddc78beb7421f9a3441db409823a2e9a980fce01695204a9db53d` |
| SHA256 match | ✅ identical on opti and Mac mini |
| Companion files | `.log` and `.vma.zst.notes` copied off-host |
| VM status after | `running` |
| HAOS health after | `issues: []`, `suggestions: []`, `unhealthy: []`, `unsupported: []` |
| Restore-test | not yet completed — required before critical workloads |

> **QGA note:** `INFO: skipping guest-agent 'fs-freeze', agent configured but not
> running` — backup is crash-consistent, not guest-fs-frozen. This is the known
> QGA WARN state and does not affect backup validity for a stateless OS like HAOS.

## Proxmox interim vzdump — Phase 1C-A (2026-05-04)

Second Proxmox-level backup completed for VM 102 (docker) on 2026-05-04 as an
interim pre-deploy snapshot. This is **not** a scheduled job and **not** the
final backup architecture. Taken before any Docker services are deployed so a
clean rollback point exists.

| Field | Value |
| --- | --- |
| Backup file | `vzdump-qemu-102-2026_05_04-16_45_42.vma.zst` |
| Backup date | 2026-05-04 16:45:42 CEST |
| Mode | `snapshot` (guest-fs-frozen — QGA fs-freeze succeeded ✅) |
| Compression | `zstd` |
| Compressed size | `579 MB` |
| Sparse ratio | 98% zero data (thin VM, no containers yet) |
| Duration | 36 seconds |
| Local path | `/var/lib/vz/dump/vzdump-qemu-102-2026_05_04-16_45_42.vma.zst` |
| Off-host path | `/Users/yasse/InfraBackups/proxmox-dumps/vzdump-qemu-102-2026_05_04-16_45_42.vma.zst` |
| SHA256 | `068a0d55cf4149ae2e931c0fb3dd7c71e1999d61b28c25eb1f57f165e295808c` |
| SHA256 match | ✅ identical on Opti and Mac mini |
| Companion files | `.log` copied off-host |
| VM status after | `running` |
| Restore-test | not yet completed — required before critical workloads |

> **QGA note:** `INFO: issuing guest-agent 'fs-freeze' command` then
> `INFO: issuing guest-agent 'fs-thaw' command` — backup is guest-fs-frozen,
> not merely crash-consistent. This is the preferred QGA state; better than the
> VM 101 backup which had QGA unavailable.

### What remains (proper backup architecture)

1. External USB SSD attached to opti **or** NFS mount from Mac mini as a
   Proxmox storage target — add as `dir` or `nfs` storage in Proxmox UI.
2. Scheduled `vzdump` job targeting off-host storage (Datacenter → Backup → Add).
3. Retention policy: minimum 3 daily, 1 weekly.
4. Documented restore-test using a test VMID (e.g. `199`) before deploying
   Vaultwarden or Docker VM `102`.
5. Quarterly restore-test thereafter.

The recurring Mac mini pull uses the Pi wrapper above instead of broad `sudo tar`. The older broad sudo rule in `/etc/sudoers.d/010_pi-nopasswd` is intentionally not removed in this step; observe a scheduled wrapper-based run first, then remove broad sudo in a separate audited change.

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
