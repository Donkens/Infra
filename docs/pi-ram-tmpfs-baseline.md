# Pi RAM / tmpfs baseline — SD write reduction

> Phase 0 read-only audit completed: 2026-04-29.
> Issue: [#10](https://github.com/Donkens/Infra/issues/10)
> No runtime changes made as part of this doc.

This document records what is already RAM-backed on the Pi DNS node, what still writes to
the SD card, what must stay on disk, and a ranked list of what to do next. It is not a
forensic dump — secrets, raw configs, private keys, and raw backup contents are excluded.

## Executive summary

The fundamentals are good. Journald is volatile, `/tmp` is tmpfs, zram swap writes no
compressed pages to the SD card under normal load, Unbound's DNS cache lives entirely in
process memory, and AdGuard query logging is memory-only. The single largest ongoing SD
writer in the infra repo is `logs/dns-health.log`, currently 855 KB and growing at one
append per ten minutes. A stale persistent journal directory on disk (~19 MB) is orphaned
since `Storage=volatile` was enabled and should be vacuumed. Journald configuration is
split across two override files with a partially dead setting.

**log2ram, overlay-FS, and moving AdGuard statistics to RAM are not recommended.** The
gains are marginal for a DNS workload, and the additional complexity increases the risk of
data loss on an unexpected reboot.

## Already RAM-backed

| Path | FS type | Purpose | Notes |
|---|---|---|---|
| `/tmp` | tmpfs | Temporary files | systemd `tmp.mount`, 50% RAM cap (453 MB), 128 KB used |
| `/run` | tmpfs | PID files, sockets, runtime state | 181 MB total, 26 MB used |
| `/run/log/journal/` | tmpfs (via /run) | Active journald journal | 6.2 MB, `Storage=volatile` confirmed |
| `/run/lock` | tmpfs | Lock files (system) | 5 MB, empty |
| `/run/user/1000` | tmpfs | User session | 90 MB, 24 KB used |
| `/dev/shm` | tmpfs | Shared memory | 453 MB, empty |
| Unbound DNS cache | process memory | msg-cache 8 MB + rrset-cache 16 MB | Entirely in-process, no disk writes |
| AdGuard query log | process memory | `file_enabled: false`, 1000-entry ring | No file written; memory-only since config |
| zram swap | compressed RAM | Swap device `zram0`, 926 MB, 2.3 MB used | Not backed by SD card; managed by `rpi-zram-writeback.timer` (minimal writeback) |

## Disk-backed write paths

| Path | Writer / service | Size / frequency | Persistence needed | Recommendation |
|---|---|---|---|---|
| `logs/dns-health.log` | `dns-health.timer` (every 10 min) | 855 KB now, ~1 MB/day | No — operational health log | P2: logrotate cap or move to `/run/` |
| `logs/backup-health.log` | `backup-health.timer` (every 12 h) | 26 KB | Low — audit trail | logrotate size cap is sufficient |
| `state/dns-health.lock` | dns-health every run | 0 bytes, flock | No | P2: move to `/run/infra/` |
| `state/backup-health.lock` | backup-health every run | 0 bytes, flock | No | P2: move to `/run/infra/` later |
| `state/dns-health.last` | dns-health every run | 86 bytes | Partial (last known status) | Leave on disk for now |
| `state/backup-health.last` | backup-health | 181 bytes | Yes — backup baseline | Leave on disk |
| `state/backups/` | nightly backup script | 7.5 MB | Yes — primary backup copy | Must stay on disk |
| `/home/pi/AdGuardHome/data/stats.db` | AdGuard (periodic flush) | 256 KB | Yes — statistics UI | Leave on disk; see open questions |
| `/home/pi/AdGuardHome/data/filters/` | AdGuard (every 168 h) | ~13 MB, weekly | Yes — loaded at startup | Leave on disk |
| `/home/pi/AdGuardHome/AdGuardHome.yaml` | Manual config changes | 15 KB, rarely | Yes — primary config | Leave on disk |
| `/var/log/journal/` | None (orphaned) | ~19 MB static | No — journald is volatile | P1: vacuum |
| `/var/log/lastlog`, `/var/log/wtmp` | SSH login/logout | ~478 KB combined | Standard OS | Not worth moving |
| `/var/log/apt/`, `dpkg.log` | apt / unattended-upgrades | ~100 KB, infrequent | Yes — audit trail | Leave; logrotate handles it |
| `/var/log/dns-prewarm.log` | Unknown writer | 147 bytes (2026-04-28) | Unknown | Open question — identify writer |

## Do not move to RAM

These paths must remain on disk and must not be placed in a tmpfs or RAM-backed mount:

- `/home/pi/repos/infra/` — repo and persistent runtime state; must survive reboot
- `/home/pi/repos/infra/state/backups/` — primary backup copy; off-Pi copy exists but this is the source
- `/home/pi/repos/infra/state/backup-health.last` — documents last known backup status before reboot
- `/home/pi/AdGuardHome/AdGuardHome.yaml` — primary AdGuard config; loss causes silent degradation
- `/home/pi/AdGuardHome/data/` — filter lists required at startup; stats database is the only history
- `/home/pi/AdGuardHome/certs/` — TLS certificate and private key material
- `/etc/unbound/` — all Unbound configuration including `ptr-local.conf` and `pi.conf`
- `/etc/systemd/system/`, `/etc/sudoers.d/` — service units and privilege rules
- `~/.ssh/` — SSH host and identity keys
- `/var/tmp/` — designed to survive reboot; used by apt and dpkg during package operations

## Journald configuration note

Journald is configured across three files. Final effective settings are listed below.

| File | Setting | Status |
|---|---|---|
| `/etc/systemd/journald.conf` | `SystemMaxUse=50M` | Overridden by conf.d files |
| `99-volatile.conf` | `Storage=volatile` | **Active** — journal stays in `/run/log/journal/` |
| `99-volatile.conf` | `RuntimeMaxUse=32M` | Overridden by `99-yasse-limits.conf` |
| `99-yasse-limits.conf` | `RuntimeMaxUse=50M` | **Active** — confirmed by journald startup message |
| `99-yasse-limits.conf` | `SystemMaxUse=200M` | **Dead config** — irrelevant with `Storage=volatile` |

`SystemMaxUse` applies to persistent (disk) journals only. With `Storage=volatile` it has no
effect and should be removed to reduce confusion. See P1-B below.

## Recommendations

### P1 — Safe soon (no service restarts required beyond signal)

**[P1-A] Vacuum orphaned persistent journal from `/var/log/journal/`**

`journalctl --disk-usage` reports 25.3 MB total; 6.2 MB is the active volatile journal in
RAM. The remaining ~19 MB is old persistent journal data in `/var/log/journal/` from before
`Storage=volatile` was configured. Journald no longer writes there, but does not clean it
automatically.

```bash
# [APPROVAL REQUIRED]
# Run on Pi — read-only verification first:
sudo journalctl --disk-usage
ls -la /var/log/journal/

# Then vacuum:
sudo journalctl --vacuum-time=1s

# Verify result:
sudo journalctl --disk-usage
ls -la /var/log/journal/
```

Expected: disk-usage drops to ~6–7 MB (volatile journal in /run only).
Risk: low — orphaned data only; volatile journal in `/run/log/journal/` is unaffected.
Rollback: not applicable (historical data, irreversible, no operational value).

---

**[P1-B] Remove dead `SystemMaxUse` from journald config**

`/etc/systemd/journald.conf.d/99-yasse-limits.conf` contains `SystemMaxUse=200M` which has
no effect with `Storage=volatile`. It should be removed and a comment added explaining that
`RuntimeMaxUse=50M` intentionally overrides the 32M cap in `99-volatile.conf`.

```bash
# [APPROVAL REQUIRED]
# Edit /etc/systemd/journald.conf.d/99-yasse-limits.conf on Pi:
# - Remove: SystemMaxUse=200M
# - Keep:   RuntimeMaxUse=50M
# - Add comment: intentionally overrides 99-volatile.conf RuntimeMaxUse=32M

# Apply without full restart — signal journald to re-read config:
sudo systemctl kill --kill-whom=main --signal=SIGUSR2 systemd-journald

# Verify:
sudo systemctl show systemd-journald -p RuntimeMaxUse
journalctl --disk-usage
```

Risk: none — removes a setting that currently does nothing.

---

### P2 — Optional improvements

**[P2-A] Cap `logs/dns-health.log` — the largest ongoing SD writer**

`dns-health.timer` fires every 10 minutes and appends to `logs/dns-health.log`, currently
855 KB. Extrapolated: ~1 MB/day, ~365 MB/year with no rotation. Two options:

*Option 1: logrotate (safest, easiest):*
Create `/etc/logrotate.d/infra-dns-health` on Pi:
```
/home/pi/repos/infra/logs/dns-health.log {
    size 200k
    rotate 2
    compress
    missingok
    notifempty
    create 0644 pi pi
}
```
Keeps at most ~400 KB compressed. No service stop required. Run with:
```bash
# [APPROVAL REQUIRED]
sudo logrotate --debug /etc/logrotate.d/infra-dns-health   # dry-run first
sudo logrotate --force /etc/logrotate.d/infra-dns-health   # apply
```

*Option 2: write log to `/run/infra/` (zero SD writes):*
Change `dns-health-monitor.sh` to write the rolling log to `/run/infra/dns-health.log`.
Keep `state/dns-health.last` on disk (86 bytes — last known status, survives reboot).
Log history is lost on reboot, which is acceptable for an operational health check.
Requires:
- `RuntimeDirectory=infra` in `dns-health.service` (or a tmpfiles.d rule)
- Update log path variable in `dns-health-monitor.sh`

Decision deferred to operator — see open questions.

---

**[P2-B] Move `state/*.lock` to `/run/infra/` (later)**

`state/dns-health.lock` and `state/backup-health.lock` are zero-byte flock files created on
every health check run. `dns-health.timer` runs every 10 minutes, producing ~144 lock-file
opens per day on the SD card. Lock files have no value after reboot.

This is a follow-on to P2-A: if `/run/infra/` is established for the log, move the lock
files there in the same change. If P2-A stays as logrotate, do this as a separate step.

```bash
# Requires [APPROVAL REQUIRED] — edit scripts + service units:
# dns-health-monitor.sh: LOCKFILE="/run/infra/dns-health.lock"
# backup-health check:   LOCKFILE="/run/infra/backup-health.lock"
# dns-health.service:    RuntimeDirectory=infra   (creates /run/infra/ at startup)
# backup-health.service: RuntimeDirectory=infra
```

Risk: low — lock files are ephemeral; `/run/infra/` is created fresh at each service start.

---

### P3 — Not worth it

| Candidate | Reason not recommended |
|---|---|
| log2ram | Adds sync-on-shutdown dependency and data-loss risk on hard power-off. zram and volatile journald already cover the main value. Not appropriate for a DNS node that must stay simple. |
| AdGuard `stats.db` to RAM | Statistics UI and 168-hour history would be lost on every reboot. 256 KB is negligible in context. |
| `/var/tmp` to tmpfs | Designed to persist across reboots. apt and dpkg use it during package upgrades. |
| Unbound cache size increase (64 MB + 128 MB) | Old `99-pro-mode.conf.OFF` had this. With 905 MB total RAM and AdGuard + OS overhead, the current 24 MB (8 + 16) is the right balance. |
| `/var/log/lastlog` and `/var/log/wtmp` to tmpfs | Written only on SSH login/logout. Not a measurable SD wear contributor at this session rate. |

## Open questions — operator decisions required

**1. dns-health.log: logrotate (option 1) or move to `/run/` (option 2)?**

Option 1 keeps log history on disk across reboots and requires only a logrotate file.
Option 2 eliminates all SD writes for the health log but requires script and service-unit
changes. Choose based on whether post-reboot log history is operationally useful.

**2. What does `dns-health-monitor.sh` write to its log?**

The script runs every 10 minutes. Knowing whether it appends a fixed-size status line or
accumulates full dig/curl output determines whether a simple cap (option 1) or a clean
`/run/` separation (option 2) is the better fit. Read the script before committing to
either approach.

**3. What creates `/var/log/dns-prewarm.log`?**

A 147-byte file last modified 2026-04-28 at this path. Not identified during Phase 0 audit.
Determine the writer before deciding whether to ignore, cap, or redirect it.

**4. How often does AdGuard flush `stats.db`?**

`data/stats.db` was last modified at 19:00 on 2026-04-29. The `statistics.interval: 168h`
setting controls retention window, not flush frequency. If AdGuard flushes every hour or
every few minutes, this is a larger write contributor than it appears. Identify the actual
flush interval before deciding whether to address it.

## Related documents

- [`docs/raspberry-pi-baseline.md`](raspberry-pi-baseline.md) — general Pi hardware and service baseline
- [`docs/pi-maintenance-checklist.md`](pi-maintenance-checklist.md) — recurring maintenance checks
- [`docs/automation.md`](automation.md) — infra-auto-sync and backup automation overview
- [`runbooks/pi-sd-card-disaster-restore.md`](../runbooks/pi-sd-card-disaster-restore.md) — what to do if SD card fails
