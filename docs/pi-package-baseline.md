# Pi package baseline

> Status: current package posture for Raspberry Pi DNS/infra node.
> Updated: 2026-04-30 after shellcheck install (tool pass Round 2).

## Summary

The Pi package set is normal to lightly tool-heavy for a DNS/infra node, not bloated.

Core role:

- DNS/front policy: AdGuard Home runtime under `/home/pi/AdGuardHome`
- Recursive/cache resolver: `unbound`
- Admin access: `ssh`, Cockpit, `tmux`
- Repo source of truth: `/home/pi/repos/infra`

Approved diagnostic tools installed on 2026-04-29:

- `lsof`
- `mtr-tiny`
- `ripgrep`

Install used `--no-install-recommends`. Package cleanup Round 1 later removed only `rpi-connect-lite` and `rpi-update`. No purge, autoremove, package installs, apt upgrade, service changes, AdGuard config changes, Unbound config changes, or firewall changes were part of that cleanup.

Approved tools installed on 2026-04-30:

- `shellcheck` (0.10.0-1) — shell script linter for infra repo scripts.
  Install: `sudo apt-get install -y --no-install-recommends shellcheck`.
  No daemon/service started. No runtime overhead. No other packages installed.
  DNS/infra verified healthy before and after install.
  First lint pass run read-only against all 15 scripts in `scripts/` on 2026-04-30.
  See shellcheck lint baseline section below.

## Keep packages

Keep these on the Pi:

- AdGuard Home runtime files under `/home/pi/AdGuardHome`
- `unbound`, `unbound-anchor`
- `ssh` / OpenSSH packages
- Cockpit packages (`cockpit`, `cockpit-ws`, `cockpit-system`, `cockpit-networkmanager`, `cockpit-storaged`, `cockpit-packagekit`)
- `tmux`
- Base OS maintenance packages such as `cron`, `logrotate`, `unattended-upgrades`, `systemd-timesyncd`
- Raspberry Pi kernel, firmware, and zram/swap packages

## Operational tools present

Useful tools already present for diagnostics and agent work:

- `tmux`
- `git`
- `curl`
- `wget`
- `jq`
- `bind9-dnsutils` / `dig`
- `tcpdump`
- `ethtool`
- `ncdu`
- `htop`
- `strace`
- `lsof`
- `mtr-tiny` / `mtr`
- `ripgrep` / `rg`
- `shellcheck` — shell script linter

## Shellcheck lint baseline (2026-04-30)

First lint pass run read-only on 2026-04-30 against all scripts in `scripts/`.
No script files were modified. Findings are documented here as follow-up candidates.

15 scripts checked. 9 passed clean. 6 had info/warning-level findings:

| Script | Findings | Level | Notes |
| --- | --- | --- | --- |
| `scripts/debug/debug-https-rr.sh` | SC2059 ×5 | info | printf format string contains color variables — style issue |
| `scripts/maintenance/check-backups.sh` | SC2015 ×2 | info | `A && B \|\| C` idiom — not true if-then-else; low risk in context |
| `scripts/maintenance/dns-health-report.sh` | SC2196 ×3, SC2001 ×1 | info/style | `egrep` deprecated (use `grep -E`); one `sed` vs bash substitution |
| `scripts/maintenance/monitor-cpu.sh` | SC2034, SC2155 | warning | SCRIPT_DIR unused; declare+assign pattern |
| `scripts/maintenance/sync-pi-dns-backups-offpi.sh` | SC2029, SC2038 | info/warning | client-side SSH expansion; `xargs` without `-0` |

No SC1xxx (fatal parse) or error-level findings. All findings are style/info/warning.
Script fixes deferred — raise as separate task with explicit scope.

## Not installed on Pi by policy

These belong on the future Opti/Debian VM unless explicitly approved for Pi:

- Docker
- Podman
- Caddy

Do not add parallel service platforms to the DNS node without a Phase 0/1/2 plan and explicit `GO`.

## Removed packages

Removed in package cleanup Round 1 on 2026-04-29:

- `rpi-connect-lite` - removed because Raspberry Pi Connect is not part of the DNS/infra role.
- `rpi-update` - removed because manual firmware update tooling is not needed for stable apt-managed infra.

No `autoremove` or `purge` was run.

## Future review candidates

These are not approved for removal by this document. Review separately before action:

| Package/group | Current posture | Notes |
| --- | --- | --- |
| `avahi-daemon` | installed, service/socket disabled | Remove candidate only if `pi.local`/mDNS is intentionally retired permanently. |
| `cloud-init`, `rpi-cloud-init-mods` | installed, cloud-init disabled by marker file and units disabled | Remove candidate only after confirming no future NoCloud/provisioning workflow depends on it. |
| `mkvtoolnix` | installed | Not DNS/infra-core; review usage before removal. |
| `p7zip-full` | installed | Useful for archives; review usage before removal. |
| `build-essential`, `gcc`, `make`, `gdb` | installed | Keep if local build/debug work is expected; otherwise review later. |

## Deferred install candidates

Not installed in the 2026-04-29 tool pass:

- `btop` - skipped because `htop` is already present.
- `needrestart` - deferred to avoid extra apt/service noise.
- `sysstat` - deferred because it may introduce ongoing data collection.
- `iotop` - deferred; install later if IO diagnostics need it.
- `smartmontools` - low value on SD-card-only Pi.
