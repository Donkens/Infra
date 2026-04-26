# IP plan

## Default LAN

| IP | Name | Role |
| --- | --- | --- |
| `192.168.1.55` | Pi DNS | AdGuard Home + Unbound |
| `192.168.1.60` | Opti / Proxmox | Hypervisor management |

## Server VLAN 30

| IP | Name | Role |
| --- | --- | --- |
| `192.168.30.10` | Docker VM | Caddy and Docker services |
| `192.168.30.20` | HAOS VM | Home Assistant OS |

## Policy

- Proxmox host management stays untagged on Default LAN.
- VM traffic uses VLAN tag `30`.
- Pi remains DNS primary.
- UDR-7 remains gateway/VLAN/firewall authority.
