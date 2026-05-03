# Proxmox backup plan — opti

Date: 2026-05-03

## Status

Phase 2A interim backup completed. This is the first Proxmox-level backup of
VM 101 (haos). It is an interim snapshot only — not a scheduled job and not the
final backup architecture. A restore-test and a proper off-host storage target
are required before Vaultwarden or Docker VM 102 are deployed.

## Phase 2A — Interim vzdump (2026-05-03)

| Field | Value |
| --- | --- |
| VM | `101 haos` |
| Backup file | `vzdump-qemu-101-2026_05_03-22_48_45.vma.zst` |
| Backup date | 2026-05-03 22:48:45 CEST |
| Mode | `snapshot` |
| Consistency | crash-consistent — QGA fs-freeze skipped (`agent configured but not running`) |
| Compression | `zstd` |
| Compressed size | `2.12 GB` |
| Sparse ratio | 92% zero data (thin-provisioned 64 GB VM disk) |
| Duration | 37 seconds |
| Local path | `/var/lib/vz/dump/vzdump-qemu-101-2026_05_03-22_48_45.vma.zst` |
| Off-host path | `/Users/yasse/InfraBackups/proxmox-dumps/vzdump-qemu-101-2026_05_03-22_48_45.vma.zst` |
| SHA256 | `cd54ef0cd9fddc78beb7421f9a3441db409823a2e9a980fce01695204a9db53d` |
| SHA256 verified | ✅ identical on opti and Mac mini |
| Companion files | `.log` and `.vma.zst.notes` copied off-host |
| VM status after | `running` |
| HAOS health after | `issues: []`, `suggestions: []`, `unhealthy: []`, `unsupported: []` |

### QGA note

vzdump reported:

```
INFO: skipping guest-agent 'fs-freeze', agent configured but not running?
INFO: starting backup via QMP command
INFO: started backup task 'ab478e76-7c87-46d8-a43b-a468ea0b978e'
INFO: resuming VM again
```

The VM was not suspended. Backup is crash-consistent (disk snapshot via LVM
thin). This is acceptable for HAOS — it is a purpose-built OS and recovers
cleanly from this backup type. The QGA WARN is a known pre-existing state and
does not affect backup validity.

### Restore-test gate

**Restore-test PASS — 2026-05-03 (Phase 2B).**

`vzdump-qemu-101-2026_05_03-22_48_45.vma.zst` was imported as VMID 199, booted
successfully (52 s uptime, 544 MB disk read, `status: running`), then stopped
and destroyed. Full result in `runbooks/opti-backup-restore-test.md`.

## Current backup gaps (after Phase 2A)

| Gap | Status |
| --- | --- |
| Scheduled Proxmox backup job | not configured |
| Permanent off-host storage target (USB SSD / NFS / PBS) | not configured |
| Retention policy | not configured |
| Restore-test | ✅ PASS 2026-05-03 |

## Backup architecture — short-term (interim)

```
opti /var/lib/vz/dump/
  └── vzdump-qemu-101-*.vma.zst   ← manual only, local NVMe
          │
          scp (manual)
          │
Mac mini /Users/yasse/InfraBackups/proxmox-dumps/
  └── vzdump-qemu-101-*.vma.zst   ← off-host copy
```

This is not sufficient for production workloads. Local-only backup on the same
NVMe does not protect against disk failure.

## Backup architecture — proper (next step)

Choose one off-host storage target and add it as a Proxmox storage:

| Option | Method | Notes |
| --- | --- | --- |
| External USB SSD on opti | `dir` storage at `/mnt/usb-backup` | Simplest; survives opti NVMe failure |
| NFS mount from Mac mini | `nfs` storage in Proxmox UI | Mac mini must export an NFS share |
| Proxmox Backup Server (PBS) | Separate PBS install | Best long-term; dedup, verify, prune |

Once off-host storage is added:

1. Datacenter → Backup → Add scheduled job targeting off-host storage.
2. Retention: `keep-daily 3`, `keep-weekly 1`.
3. First restore-test with test VMID.
4. Quarterly restore-test thereafter.

## Vaultwarden gate

Do not deploy Vaultwarden until:

1. ✅ Backup destination exists (interim Mac mini copy — partial).
2. ✅ Backup process documented (this file).
3. ✅ Restore-test documented and completed — PASS 2026-05-03.
4. ❌ Scheduled backup job to permanent off-host target — **still required**.
