# Hosts

| Host | Role | Notes |
| --- | --- | --- |
| Raspberry Pi | DNS primary | AdGuard Home -> Unbound, `192.168.1.55`. Baseline: [Raspberry Pi baseline](../docs/raspberry-pi-baseline.md). SDRAM: `sdram_freq=550`, documented in [Raspberry Pi 3B+ SDRAM OC baseline](../docs/raspberry-pi-3b-plus-sdram-oc-baseline-2026-04-27.md). |
| UDR-7 | Gateway/VLAN/firewall/WireGuard | Network authority. |
| Dell OptiPlex 7080 Micro | Proxmox hypervisor | Planned `192.168.1.60`. |
| Mac mini | Primary admin/compute client | Trusted admin client. |
| MacBook | Secondary admin client | Trusted admin client. |

No secrets belong in inventory files.
