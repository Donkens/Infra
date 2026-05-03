# DNS names

> Source-of-truth for important `home.lan` names.
> Last verified: 2026-05-04 00:12 CEST

## Authority model

| Record type | Authority | Notes |
|---|---|---|
| Forward DNS for live hosts and services | AdGuard Home on Pi `192.168.1.55` / `fd12:3456:7801::55` | AdGuard handles client-facing A/AAAA records and service/convenience rewrites. Do not duplicate forward `.home.lan` names in Unbound unless intentionally changing the authority model. |
| Recursion | Unbound on Pi `127.0.0.1:5335` | AdGuard upstream for recursive resolution. |
| PTR / reverse DNS | Unbound `ptr-local.conf` | Reverse records for documented infra hosts using `local-data-ptr`; no forward `local-data` A/AAAA baseline. |
| DHCP distribution | UniFi / UDR-7 | Client DNS should point to Pi DNS. |

## LIVE infra and service names

| Name | A | AAAA | PTR | Source | Status | Notes |
|---|---|---|---|---|---|---|
| `pi.home.lan` | `192.168.1.55` | `fd12:3456:7801::55` | `pi.home.lan.` | Forward: AdGuard; PTR: Unbound | LIVE | Pi DNS node. |
| `adguard.home.lan` | `192.168.1.55` | `fd12:3456:7801::55` | n/a | AdGuard rewrite | LIVE | AdGuard UI/TLS/DNS service alias. |
| `cockpit.home.lan` | `192.168.1.55` | UNKNOWN | n/a | AdGuard rewrite | LIVE | Pi Cockpit alias. |
| `macmini.home.lan` | `192.168.1.86` | `fd12:3456:7801::86` | `macmini.home.lan.` | Forward: AdGuard; PTR: Unbound | LIVE | Mac mini Ethernet. |
| `macmini-wifi.home.lan` | `192.168.1.84` | UNKNOWN | `macmini-wifi.home.lan.` | Forward: AdGuard; PTR: Unbound | LIVE | Mac mini WiFi. |
| `mbp.home.lan` | `192.168.1.78` | `fd12:3456:7801::78` | `mbp.home.lan.` | Forward: AdGuard; PTR: Unbound | LIVE | MacBook Pro 2015. |
| `udr.home.lan` | `192.168.1.1` | none / UNKNOWN | `udr.home.lan.` | Forward: AdGuard; PTR: Unbound | LIVE | UDR-7 gateway. AAAA did not answer in latest check. |
| `router.home.lan` | `192.168.1.1` | UNKNOWN | n/a | AdGuard rewrite | LIVE | UDR convenience alias. |
| `unifi.home.lan` | `192.168.1.1` | UNKNOWN | n/a | AdGuard rewrite | LIVE | UniFi UI alias. |
| `iphone.home.lan` | `192.168.40.207` | UNKNOWN | `iphone.home.lan.` | Forward: AdGuard; PTR: Unbound | LIVE | iPhone on MLO-LAN/VLAN 40. |

If a host has both forward and reverse DNS, forward lives in AdGuard and reverse lives in Unbound. Phase 0 on 2026-04-29 verified that direct Unbound forward lookup for `pi.home.lan A` returns `NXDOMAIN`, while AdGuard resolves `pi.home.lan`, `macmini.home.lan`, `adguard.home.lan`, and `cockpit.home.lan` correctly.

## Opti / VM / service names

These names are reserved for the Opti/Proxmox plan. Some may already resolve in AdGuard for forward planning, but services are not considered live until the corresponding host/VM exists and is validated.

As of 2026-05-02, `opti.home.lan` and `proxmox.home.lan` resolve to `192.168.1.60` via Pi AdGuard and system resolver. HAOS VM `101` is live on `192.168.30.20`; Docker VM and Docker-backed service names remain planned until their workloads exist and are validated. As of 2026-05-04, `ha.home.lan` PTR (`192.168.30.20 → ha.home.lan.`) is live in Unbound `ptr-local.conf`.

| Name | Planned IP | Role | PTR | Source | Status |
|---|---|---|---|---|---|
| `opti.home.lan` | `192.168.1.60` | Proxmox host hardware | n/a | AdGuard rewrite | LIVE |
| `proxmox.home.lan` | `192.168.1.60` | Proxmox UI/API | n/a | AdGuard rewrite | LIVE |
| `ha.home.lan` | `192.168.30.20` | Home Assistant OS | `ha.home.lan.` | Forward: AdGuard; PTR: Unbound | LIVE |
| `haos.home.lan` | `192.168.30.20` | HAOS alias (forward only) | n/a | AdGuard rewrite | LIVE |
| `docker.home.lan` | `192.168.30.10` | Debian Docker VM | — | AdGuard planned | PLANNED |
| `proxy.home.lan` | `192.168.30.10` | Caddy reverse proxy | — | AdGuard planned | PLANNED |
| `dockge.home.lan` | `192.168.30.10` | Dockge via Caddy | — | AdGuard planned | PLANNED |
| `uptime.home.lan` | `192.168.30.10` | Uptime Kuma via Caddy | — | AdGuard planned | PLANNED |
| `dozzle.home.lan` | `192.168.30.10` | Dozzle via Caddy | — | AdGuard planned | PLANNED |
| `stremio.home.lan` | `192.168.30.10` | Optional Stremio Server | — | AdGuard planned | PLANNED |
| `transmission.home.lan` | `192.168.30.10` | Optional, via Caddy only if used | — | AdGuard planned | PLANNED |
| `mcp.home.lan` | `192.168.30.10` | Later MCP/dev services | — | AdGuard planned | PLANNED |

## Related inventory

- [UniFi networks](unifi-networks.md)
- [DHCP reservations](dhcp-reservations.md)
- [DNS architecture](../docs/dns-architecture.md)
