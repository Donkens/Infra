# DNS names

> Source-of-truth for important `home.lan` names.
> Last verified: 2026-04-28 19:45 CEST

## Authority model

| Record type | Authority | Notes |
|---|---|---|
| Client-facing forward lookups | AdGuard Home on Pi `192.168.1.55` | AdGuard handles service/convenience rewrites and forwards other names to Unbound. |
| Recursion | Unbound on Pi `127.0.0.1:5335` | AdGuard upstream. |
| PTR / reverse DNS | Unbound `ptr-local.conf` | Reverse records for documented infra hosts. |
| DHCP distribution | UniFi / UDR-7 | Client DNS should point to Pi DNS. |

## LIVE infra and service names

| Name | A | AAAA | PTR | Source | Status | Notes |
|---|---|---|---|---|---|---|
| `pi.home.lan` | `192.168.1.55` | `fd12:3456:7801::55` | `pi.home.lan.` | Unbound / AdGuard forwarding | LIVE | Pi DNS node. |
| `adguard.home.lan` | `192.168.1.55` | `fd12:3456:7801::55` | n/a | AdGuard rewrite | LIVE | AdGuard UI/TLS/DNS service alias. |
| `cockpit.home.lan` | `192.168.1.55` | UNKNOWN | n/a | AdGuard rewrite | LIVE | Pi Cockpit alias. |
| `macmini.home.lan` | `192.168.1.86` | `fd12:3456:7801::86` | `macmini.home.lan.` | Unbound / AdGuard forwarding | LIVE | Mac mini Ethernet. |
| `macmini-wifi.home.lan` | `192.168.1.84` | UNKNOWN | `macmini-wifi.home.lan.` | Unbound PTR + AdGuard forward | LIVE | Mac mini WiFi. |
| `mbp.home.lan` | `192.168.1.78` | `fd12:3456:7801::78` | `mbp.home.lan.` | Unbound / AdGuard forwarding | LIVE | MacBook Pro 2015. |
| `udr.home.lan` | `192.168.1.1` | none / UNKNOWN | `udr.home.lan.` | AdGuard forward + Unbound PTR | LIVE | UDR-7 gateway. AAAA did not answer in latest check. |
| `router.home.lan` | `192.168.1.1` | UNKNOWN | n/a | AdGuard rewrite | LIVE | UDR convenience alias. |
| `unifi.home.lan` | `192.168.1.1` | UNKNOWN | n/a | AdGuard rewrite | LIVE | UniFi UI alias. |
| `iphone.home.lan` | `192.168.40.207` | UNKNOWN | `iphone.home.lan.` | Unbound PTR + AdGuard forward | LIVE | iPhone on MLO-LAN/VLAN 40. |

## PLANNED Opti / VM / service names

These names are reserved for the Opti/Proxmox plan. Some may already resolve in AdGuard for forward planning, but services are not considered live until the corresponding host/VM exists and is validated.

| Name | Planned IP | Role | Status |
|---|---|---|---|
| `opti.home.lan` | `192.168.1.60` | Proxmox host hardware | PLANNED |
| `proxmox.home.lan` | `192.168.1.60` | Proxmox UI/API | PLANNED |
| `docker.home.lan` | `192.168.30.10` | Debian Docker VM | PLANNED |
| `proxy.home.lan` | `192.168.30.10` | Caddy reverse proxy | PLANNED |
| `ha.home.lan` | `192.168.30.20` | Home Assistant OS | PLANNED |
| `haos.home.lan` | `192.168.30.20` | HAOS alias | PLANNED |
| `dockge.home.lan` | `192.168.30.10` | Dockge via Caddy | PLANNED |
| `uptime.home.lan` | `192.168.30.10` | Uptime Kuma via Caddy | PLANNED |
| `dozzle.home.lan` | `192.168.30.10` | Dozzle via Caddy | PLANNED |
| `stremio.home.lan` | `192.168.30.10` | Optional Stremio Server | PLANNED |
| `transmission.home.lan` | `192.168.30.10` | Optional, via Caddy only if used | PLANNED |
| `mcp.home.lan` | `192.168.30.10` | Later MCP/dev services | PLANNED |

## Related inventory

- [UniFi networks](unifi-networks.md)
- [DHCP reservations](dhcp-reservations.md)
- [DNS architecture](../docs/dns-architecture.md)
