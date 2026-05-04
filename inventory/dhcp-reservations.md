# DHCP reservations

> Important UniFi fixed-IP reservations and planned infrastructure addresses.
> Last verified: 2026-05-04 CEST (Opti MAC + Docker VM reservation confirmed)

MAC addresses are intentionally masked. Do not commit full hardware addresses.

| Device | Hostname | IP | Network / VLAN | MAC masked | Status | Source | Notes |
|---|---|---|---|---|---|---|---|
| Raspberry Pi DNS | `dns` / `pi` | `192.168.1.55` | Default / untagged | `b8:27:eb:xx:xx:xx` | LIVE | UniFi fixed IP + Pi runtime | Primary DNS node. |
| Mac mini Ethernet | `mini` | `192.168.1.86` | Default / untagged | `4c:20:b8:xx:xx:xx` | LIVE | UniFi fixed IP + Mac runtime | Primary admin Mac wired path. |
| Mac mini WiFi | `mini` | `192.168.1.84` | Default / untagged | `4c:20:b8:xx:xx:xx` | LIVE | UniFi fixed IP | Secondary Mac mini interface. |
| MacBook Pro 2015 | `mbp` | `192.168.1.78` | Default / untagged | `ac:bc:32:xx:xx:xx` | LIVE | UniFi fixed IP + SSH identity | Secondary admin client. |
| iPhone 17 Pro | `iPhone17Pro` | `192.168.40.207` | MLO-LAN / VLAN 40 | `5c:13:cc:xx:xx:xx` | LIVE | UniFi fixed IP + DNS PTR | MLO/6 GHz client. |
| Roborock S5 Max | n/a | `192.168.10.6` | IOT / VLAN 10 | `b0:4a:39:xx:xx:xx` | LIVE | UniFi fixed IP | IoT vacuum. |
| Yeelight Bedroom | `yeelight-bedroom` | `192.168.10.150` | IOT / VLAN 10 | `28:6c:07:xx:xx:xx` | LIVE | UniFi fixed IP | Yeelight Color bulb, model `color`, FW v76. LAN Control enabled, TCP 55443. HAOS control via `allow-haos-yeelight-control`. |
| Opti / Proxmox host | `opti`, `proxmox` | `192.168.1.60` | Default / untagged | `a4:bb:6d:xx:xx:xx` | LIVE | UniFi fixed IP | MAC verified 2026-05-04. UniFi name `Opti Proxmox`, note `Proxmox host · Dell OptiPlex 7080 Micro · 192.168.1.60 · Default LAN`. |
| HAOS VM 101 | `ha`, `haos` | `192.168.30.20` | Server / VLAN 30 | `bc:24:11:xx:xx:xx` | LIVE | UniFi fixed IP + HAOS runtime | Manual UniFi reservation for VMID `101`; runtime validated from HAOS guest agent. |
| Docker VM | `docker`, `proxy` | `192.168.30.10` | Server / VLAN 30 | `bc:24:11:xx:xx:xx` | LIVE | UniFi fixed IP + Proxmox VM runtime | MAC `BC:24:11:50:9C:4D` verified 2026-05-04. UniFi name `Docker VM 102`, note `Debian Docker VM · VLAN 30 · 192.168.30.10 · Proxmox VMID 102`. |

## Notes

- Opti, HAOS VM 101, and Docker VM 102 all have verified UniFi fixed-IP reservations as of 2026-05-04.
- Keep this file to critical infrastructure only; broad client lists belong in UniFi, not Git.
