# Hosts

| Host | Role | Notes |
| --- | --- | --- |
| Raspberry Pi | DNS primary | AdGuard Home -> Unbound, `192.168.1.55`. Baseline: [Raspberry Pi baseline](../docs/raspberry-pi-baseline.md). SDRAM: `sdram_freq=550`, documented in [Raspberry Pi 3B+ SDRAM OC baseline](../docs/raspberry-pi-3b-plus-sdram-oc-baseline-2026-04-27.md). |
| UDR-7 | Gateway/VLAN/firewall/WireGuard | Network authority. |
| `opti.home.lan` | Proxmox hypervisor | Live `192.168.1.60`. Dell OptiPlex 7080 Micro, Intel i7-10700T, `32 GB` RAM, `512 GB NVMe`, Proxmox VE 9.1. Management on Default LAN/native untagged. |
| `ha.home.lan` / `haos.home.lan` | HAOS VM 101 | Live `192.168.30.20` on Server VLAN 30. Runs on `opti.home.lan`; VM name `haos`, `2 vCPU`, `6144 MB` RAM, `64 GB` disk on `local-lvm`. |
| `docker.home.lan` / `proxy.home.lan` | Docker VM 102 | Docker-Caddy host. Live `192.168.30.10` on Server VLAN 30. Debian, SSH user `yasse`. Runs Caddy, Uptime Kuma, and Dozzle. |
| Mac mini | Primary admin/compute client | Trusted admin client. |
| MacBook | Secondary admin client | Trusted admin client. |

No secrets belong in inventory files.
