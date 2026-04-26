# Firewall baseline plan

This is documentation only. Do not apply live firewall changes from this file.

UDR-7 remains the gateway, VLAN, firewall, and WireGuard authority.

## Planned allow model

| Source | Destination | Ports | Purpose |
| --- | --- | --- | --- |
| Default LAN | `192.168.30.10` | `80/443` | Caddy services on Docker VM |
| Default LAN | `192.168.30.20` | `8123` | Direct HAOS access |
| Mac mini / MacBook | `192.168.30.10` | `22` | Docker VM admin |
| Mac mini / MacBook | `192.168.1.60` | `8006`, `22` if needed | Proxmox admin |
| Server VLAN 30 | `192.168.1.55` | `tcp/udp 53` | Pi DNS |
| Server VLAN 30 | WAN | `80/443`, NTP | Updates and Docker pulls |
| IoT VLAN | HAOS | only required HA ports | Home Assistant integrations |

Optionally document `853/443` to Pi only if internal DoT/DoH is introduced later.

## Planned block model

| Source | Destination | Policy |
| --- | --- | --- |
| Default LAN | Server VLAN 30 | Block all not explicitly allowed. |
| Server VLAN 30 | Default LAN | Block everything else initially. |
| IoT VLAN | Proxmox | Block. |
| IoT VLAN | Docker admin surfaces | Block. |

## Notes

- No WAN port forwards.
- No public exposure of admin surfaces.
- Debug order remains routing -> firewall -> DNS -> application.
