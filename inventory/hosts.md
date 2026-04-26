# Hosts

| Host | Role | Notes |
| --- | --- | --- |
| Raspberry Pi | DNS primary | AdGuard Home -> Unbound, `192.168.1.55`. |
| UDR-7 | Gateway/VLAN/firewall/WireGuard | Network authority. |
| Dell OptiPlex 7080 Micro | Proxmox hypervisor | Planned `192.168.1.60`. |
| Mac mini | Primary admin/compute client | Trusted admin client. |
| MacBook | Secondary admin client | Trusted admin client. |

No secrets belong in inventory files.
