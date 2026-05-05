# Backup and restore policy

## Phase 1E baseline — 2026-05-06

Backup freshness monitoring added:

| Component | Status |
|---|---|
| Kuma Push monitor "Proxmox backup freshness" (ID 16, heartbeat 1500 min) | ✅ LIVE |
| Health-check script (Mac mini, 05:00 daily) | ✅ LIVE — `check-proxmox-backup-age.sh` |
| LaunchAgent `com.yasse.proxmox-backup-age-check` | ✅ Laddad |
| Token env-fil | ✅ `/Users/yasse/.config/infra/proxmox-backup-monitor.env` (chmod 600, ej committad) |
| Första manuella körning | ⚠️ WARN/EXPECTED — VM101 49.5h gammal (väntar på 03:00 backup ikväll) |

Kuma-monitorn visar DOWN tills Proxmox-backup kör 2026-05-06 03:00 + Mac mini sync 04:00. Förväntat och självläkande. **Bekräfta PASS efter 05:00 imorgon.**

## Phase 1D baseline — 2026-05-05

Proxmox backup automation baseline is live:

| Component | Status |
|---|---|
| Scheduled backup job (VMs 101+102, daily 03:00, keep-last=2) | ✅ LIVE — `jobs.cfg` ID `ba5952c1` |
| Off-host sync script + LaunchAgent (Mac mini 04:00 daily) | ✅ LIVE — `sync-proxmox-vm-backups.sh` |
| VM 102 (docker) restore-test | ✅ PASS 2026-05-05 |
| VM 101 (haos) restore-test | ✅ PASS 2026-05-03 |
| Vaultwarden gate | ✅ Cleared — all conditions met |

Vaultwarden can now be deployed. See `runbooks/opti-backup-restore-test.md` for both restore-test records.

---

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

## Docker VM 102 — app/config backup baseline (2026-05-04)

> This is a **Docker application and config backup**, not a Proxmox full-VM backup.
> Both layers are needed: this covers compose files and appdata; Proxmox vzdump covers
> the full VM disk. They complement each other and are not substitutes.

Script: `scripts/maintenance/docker-vm-backup.sh`
Runtime install: `/usr/local/sbin/docker-vm-backup` on Docker VM (root:root 755)

### What is backed up

| Path | Contents |
|---|---|
| `/srv/compose/` | All compose stack directories: `caddy/`, `dockge/`, `dozzle/`, `uptime-kuma/`. Includes `compose.yaml`, `Caddyfile`, `.env.example` files. |
| `/srv/appdata/caddy/` | Caddy runtime state (TLS cache, autosave config). |
| `/srv/appdata/uptime-kuma/` | Uptime Kuma SQLite database and config. |
| `/srv/appdata/dozzle/` | Dozzle `users.yml` (bcrypt hashes) and `admin/` directory. |
| `/srv/appdata/dockge/` | Dockge state (empty at this baseline; fills after Dockge is started). |

### What is excluded

| Pattern | Reason |
|---|---|
| `*.sock` | Socket files cannot be archived by tar |
| `*/tmp`, `*/tmp/*` | Transient temporary files |
| `*/cache`, `*/cache/*` | Cache directories |
| `*/.cache`, `*/.cache/*` | Hidden cache directories |
| `*/node_modules/*` | Node module trees (safety for future services) |
| `*/__pycache__` | Python bytecode (safety for future services) |
| Container images | Rebuilt via `docker pull`; not in `/srv/` |

### Backup locations

| Layer | Path | Note |
|---|---|---|
| Local (Docker VM) | `/srv/backups/docker-vm-102/docker-vm-102-backup-YYYYmmdd-HHMMSS.tar.gz` | Retention: 7 newest kept |
| Off-host (Mac mini) | `/Users/yasse/InfraBackups/docker-vm-102/` | rsync pull after each backup |
| SHA256 checksum | Same dir as tarball, `.sha256` suffix | Portable — verifies on Linux and macOS |

### How to run backup manually

```bash
# On Docker VM:
sudo /usr/local/sbin/docker-vm-backup

# Off-host pull from Mac mini:
rsync -av docker:/srv/backups/docker-vm-102/ /Users/yasse/InfraBackups/docker-vm-102/

# Verify checksum on Mac mini (macOS shasum):
cd /Users/yasse/InfraBackups/docker-vm-102
shasum -a 256 -c *.sha256

# Verify checksum on Docker VM (Linux sha256sum):
cd /srv/backups/docker-vm-102
sha256sum -c *.sha256
```

### Restore test procedure

Non-destructive. Extract to temp dir and verify structure without starting any service.

```bash
RESTORE_DIR="/tmp/docker-vm-102-restore-test-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESTORE_DIR"
tar -xzf /Users/yasse/InfraBackups/docker-vm-102/docker-vm-102-backup-*.tar.gz -C "$RESTORE_DIR"
find "$RESTORE_DIR" -maxdepth 4 -type d | sort | head -40
# Verify expected dirs present: srv/compose/{caddy,uptime-kuma,dozzle,dockge}
# Verify expected dirs present: srv/appdata/{caddy,uptime-kuma,dozzle,dockge}
# Verify sensitive files exist (do NOT print contents):
find "$RESTORE_DIR" -name 'users.yml' -o -name '*.env' | sort
rm -rf "$RESTORE_DIR"
```

### Baseline result — 2026-05-04

| Check | Result |
|---|---|
| Script created | `scripts/maintenance/docker-vm-backup.sh` ✅ |
| Runtime install | `/usr/local/sbin/docker-vm-backup` root:root 755 ✅ |
| Backup file | `docker-vm-102-backup-20260504-201659.tar.gz` (296K, 45 entries) ✅ |
| SHA256 on Docker VM | `b3f44218786633bf80b62792a507e0f8b25999483a689ac853ba53b0b07da36c` ✅ |
| Docker VM checksum | `sha256sum -c`: OK ✅ |
| rsync to Mac mini | `/Users/yasse/InfraBackups/docker-vm-102/` — 294K transferred ✅ |
| Mac mini checksum | `shasum -a 256 -c`: OK ✅ |
| Restore test | PASS — all 4 compose stacks and 4 appdata dirs present; `users.yml` present ✅ |
| `dockge` appdata | Empty at this baseline (Dockge not yet started — expected) ✅ |

### Retention policy

Default: keep newest 7 backups. Override via `RETENTION_KEEP=N` environment variable.
The script removes the oldest `.tar.gz` and paired `.sha256` automatically.

### Notes

- rsync was installed on Docker VM during baseline: `apt-get install -y rsync` (2026-05-04).
- File permissions: `600` (rw-------). Files chowned to `yasse` when run via sudo.
- Backup does NOT include container images, live socket files, or Proxmox VM disk state.
- This baseline covers Phase 1C-C2a service state (Caddy + Uptime Kuma + Dozzle live; Dockge compose ready but not started).
- Re-run backup after Dockge is started (Phase 1C-C2b) to capture Dockge state.

## Vaultwarden gate

Do not deploy Vaultwarden until:

1. Backup destination exists. ✅ Docker VM backup baseline live 2026-05-04
2. Backup process is documented. ✅ See above
3. Restore-test is documented and completed. ✅ Restore-test PASS 2026-05-04
4. Proxmox-level scheduled backup job with off-host target configured and tested.
