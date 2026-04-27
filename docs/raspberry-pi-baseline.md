# Raspberry Pi baseline

## Summary

This is the sanitized baseline for the Raspberry Pi 3B+ DNS node.

- Hostname: `pi`
- Role: primary DNS node
- DNS chain: client -> AdGuard Home (`192.168.1.55`) -> Unbound (`127.0.0.1:5335`) -> upstream
- Repo source of truth on the Pi: `/home/pi/repos/infra`
- Baseline captured: 2026-04-27 after reboot and package maintenance

This document is a baseline, not a forensic dump. It intentionally excludes secrets, raw service configs, private keys, session data, and raw logs.

## Hardware and OS

- Model: `Raspberry Pi 3 Model B Plus Rev 1.3`
- OS: `Debian GNU/Linux 13 (trixie)`, `DEBIAN_VERSION_FULL=13.4`
- Kernel: `6.12.75+rpt-rpi-v8`
- Architecture: `aarch64`
- Memory: `905Mi` total, about `644Mi` available during Phase 0
- Swap: `904Mi`
- Root filesystem: `/dev/mmcblk0p2`, `29G` total, `24G` free, `17%` used
- Boot firmware filesystem: `/dev/mmcblk0p1`, `510M` total, `445M` free, `13%` used

## Network identity

- Primary interface: `eth0`
- IPv4: `192.168.1.55/24`
- IPv6 ULA: `fd12:3456:7801::55/64`
- Default gateway: `192.168.1.1`
- DNS name: `pi.home.lan`

## Role

The Pi remains the operational source of truth for live DNS service state. It should stay conservative because DNS availability depends on it.

Primary responsibilities:

- Receive LAN DNS traffic on `192.168.1.55`
- Run AdGuard Home as the front DNS policy and TLS/UI service
- Run Unbound as local recursive/cache resolver on loopback
- Keep sanitized infra snapshots and docs in `/home/pi/repos/infra`

## Services

Expected active services:

- `AdGuardHome.service`
- `unbound.service`
- `ssh.service`

Relevant timers observed during Phase 0:

- `backup-health.timer`
- `infra-auto-sync.timer`
- `dpkg-db-backup.timer`

## Ports

Expected listening ports:

| Port | Bind | Role |
| --- | --- | --- |
| `53/tcp,udp` | `*` | AdGuard DNS listener |
| `5335/tcp,udp` | `127.0.0.1` | Unbound upstream for AdGuard |
| `853/tcp,udp` | `*` | AdGuard DNS-over-TLS |
| `3000/tcp` | `*` | AdGuard UI/setup listener |
| `443/tcp` | `*` | AdGuard HTTPS/TLS endpoint |
| `22/tcp` | `0.0.0.0`, `[::]` | SSH |

## DNS architecture

Baseline chain:

- Client -> AdGuard Home on `192.168.1.55:53`
- AdGuard Home -> Unbound on `127.0.0.1:5335`
- Unbound -> upstream/root resolution

Unbound is also the local PTR authority for documented local reverse records. Firewall and VLAN policy should continue to force clients toward Pi DNS rather than adding parallel resolvers.

## Important paths

- Infra repo: `/home/pi/repos/infra`
- AdGuard Home working directory: `/home/pi/AdGuardHome`
- AdGuard Home service file: `/etc/systemd/system/AdGuardHome.service`
- AdGuard Home config path: `/home/pi/AdGuardHome/AdGuardHome.yaml` metadata only; raw content is not documented here
- Unbound base directory: `/etc/unbound`
- Unbound include directory: `/etc/unbound/unbound.conf.d`
- Active Unbound baseline config: `/etc/unbound/unbound.conf.d/pi.conf`
- Local reverse records: `/etc/unbound/unbound.conf.d/ptr-local.conf`

## AdGuard Home

Service baseline:

- `ExecStart=/home/pi/AdGuardHome/AdGuardHome "-s" "run"`
- `WorkingDirectory=/home/pi/AdGuardHome`
- `Restart=always`

`AdGuardHome.yaml` is root-owned and mode `600`. It was not read for this baseline. Do not paste or commit raw AdGuard config, credentials, session data, user hashes, rewrites, clients, upstream bodies, query logs, or backups.

## Unbound

Observed baseline:

- `unbound-control` works
- Version: `1.22.0`
- Threads: `2`
- Modules: `validator iterator`
- Control mode: `reuseport control(namedpipe)`
- `unbound-checkconf` reported no errors for `/etc/unbound/unbound.conf`

Important active config traits from sanitized grep:

- `interface: 127.0.0.1@5335`
- `interface: ::1@5335`
- `do-ip4: yes`
- `do-ip6: no`
- `cache-min-ttl: 300`
- `cache-max-ttl: 86400`
- `cache-max-negative-ttl: 300`
- `prefetch: yes`
- `serve-expired: yes`
- LAN access allowed for `127.0.0.0/8`, `::1/128`, `192.168.1.0/24`, and local ULA prefixes

## Certificates and TLS

AdGuard TLS material exists under `/home/pi/AdGuardHome/certs`. This baseline documents only the directory-level fact, not private key contents or raw certificate material.

For current TLS cleanup context and certificate deployment notes, see [DNS/TLS cleanup baseline](dns-tls-baseline-2026-04-26.md).

## Repo and automation

- Pi repo: `/home/pi/repos/infra`
- Branch during Phase 0: `main`
- Remote: `git@github.com:Donkens/Infra.git`
- HEAD during Phase 0: `264592e docs: document raspberry pi sdram oc baseline`
- Relevant automation: `infra-auto-sync.timer`, `backup-health.timer`, `dpkg-db-backup.timer`

No commits or pushes should happen without explicit instruction.

## SDRAM OC

Current stable SDRAM baseline:

- `vcgencmd get_config sdram_freq` returned `sdram_freq=550`
- Keep this conservative; the Pi is the primary DNS node

Detailed record: [Raspberry Pi 3B+ SDRAM OC baseline](raspberry-pi-3b-plus-sdram-oc-baseline-2026-04-27.md).

## Health checks

Recommended quick checks:

- `systemctl is-active AdGuardHome.service`
- `systemctl is-active unbound.service`
- `systemctl is-active ssh.service`
- `ss -tulpn | grep -E ':(53|5335|853|3000|443|22)\b'`
- `vcgencmd get_throttled`
- `vcgencmd measure_temp`
- `df -h / /boot/firmware`
- `unbound-control status`
- `unbound-control stats_noreset | head -80`

Expected healthy post-reboot state from Phase 0 context:

- `throttled=0x0`
- Temperature around low `50 C`
- AdGuard Home, Unbound, and SSH active
- DNS smoke tests through Unbound resolve public names

## Reboot validation

After planned reboot, verify:

- `uptime`
- `uname -a`
- `cat /etc/os-release`
- `vcgencmd get_throttled`
- `vcgencmd measure_temp`
- `systemctl is-active AdGuardHome.service`
- `systemctl is-active unbound.service`
- `systemctl is-active ssh.service`
- `ss -tulpn | grep -E ':(53|5335|853|3000|443|22)\b'`
- `dig @127.0.0.1 -p 5335 cloudflare.com A +short`
- `dig @127.0.0.1 -p 5335 google.com A +short`

## Do not document / do not touch

Do not document, paste, copy broadly, or commit:

- no raw `AdGuardHome.yaml`
- no credentials
- no private keys
- no cert private keys
- no session data
- no raw query logs
- no raw clients, rewrites, upstreams, or user rules
- no password hashes
- no raw backup files such as `AdGuardHome.yaml` backups
- no broad copies of `/home/pi/AdGuardHome`
- no sockets, pid files, locks, or runtime device state

## Related docs

- [Raspberry Pi 3B+ SDRAM OC baseline](raspberry-pi-3b-plus-sdram-oc-baseline-2026-04-27.md)
- [DNS/TLS cleanup baseline](dns-tls-baseline-2026-04-26.md)
- [Pi DNS Runbook](runbook.md)
- [Restore Guide](restore.md)
- [IP plan](../inventory/ip-plan.md)
- [DNS names](../inventory/dns-names.md)
