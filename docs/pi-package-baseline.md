# Pi package baseline

> Status: current package posture for Raspberry Pi DNS/infra node.
> Updated: 2026-04-29 after approved diagnostic tool install.

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

Install used `--no-install-recommends`. No package removals, purge, autoremove, service changes, AdGuard config changes, Unbound config changes, or firewall changes were part of this install.

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

## Not installed on Pi by policy

These belong on the future Opti/Debian VM unless explicitly approved for Pi:

- Docker
- Podman
- Caddy

Do not add parallel service platforms to the DNS node without a Phase 0/1/2 plan and explicit `GO`.

## Future review candidates

These are not approved for removal by this document. Review separately before action:

| Package/group | Current posture | Notes |
| --- | --- | --- |
| `avahi-daemon` | installed, service/socket disabled | Remove candidate only if `pi.local`/mDNS is intentionally retired permanently. |
| `cloud-init`, `rpi-cloud-init-mods` | installed, cloud-init disabled by marker file and units disabled | Remove candidate only after confirming no future NoCloud/provisioning workflow depends on it. |
| `rpi-connect-lite` | installed | Review whether Raspberry Pi Connect is used. |
| `rpi-update` | installed | Powerful firmware update tool; keep only if intentionally used. |
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
