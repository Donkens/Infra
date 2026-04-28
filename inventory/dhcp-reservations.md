# DHCP reservations

> Important UniFi fixed-IP reservations and planned infrastructure addresses.
> Last verified: 2026-04-28 19:45 CEST

MAC addresses are intentionally masked. Do not commit full hardware addresses.

| Device | Hostname | IP | Network / VLAN | MAC masked | Status | Source | Notes |
|---|---|---|---|---|---|---|---|
| Raspberry Pi DNS | `dns` / `pi` | `192.168.1.55` | Default / untagged | `b8:27:eb:xx:xx:xx` | LIVE | UniFi fixed IP + Pi runtime | Primary DNS node. |
| Mac mini Ethernet | `mini` | `192.168.1.86` | Default / untagged | `4c:20:b8:xx:xx:xx` | LIVE | UniFi fixed IP + Mac runtime | Primary admin Mac wired path. |
| Mac mini WiFi | `mini` | `192.168.1.84` | Default / untagged | `4c:20:b8:xx:xx:xx` | LIVE | UniFi fixed IP | Secondary Mac mini interface. |
| MacBook Pro 2015 | `mbp` | `192.168.1.78` | Default / untagged | `ac:bc:32:xx:xx:xx` | LIVE | UniFi fixed IP + SSH identity | Secondary admin client. |
| iPhone 17 Pro | `iPhone17Pro` | `192.168.40.207` | MLO-LAN / VLAN 40 | `5c:13:cc:xx:xx:xx` | LIVE | UniFi fixed IP + DNS PTR | MLO/6 GHz client. |
| Roborock S5 Max | n/a | `192.168.10.6` | IOT / VLAN 10 | `b0:4a:39:xx:xx:xx` | LIVE | UniFi fixed IP | IoT vacuum. |
| Opti / Proxmox host | `opti`, `proxmox` | `192.168.1.60` | Default / untagged | UNKNOWN | PLANNED | Repo plan | MAC unknown until hardware arrives. |
| HAOS VM | `ha`, `haos` | `192.168.30.20` | Server / VLAN 30 | UNKNOWN | PLANNED | Repo plan | VM MAC unknown until VM exists. |
| Docker VM | `docker`, `proxy` | `192.168.30.10` | Server / VLAN 30 | UNKNOWN | PLANNED | Repo plan | VM MAC unknown until VM exists. |

## Notes

- Planned Opti/VM addresses are DNS/IP plan targets, not verified DHCP reservations.
- Keep this file to critical infrastructure only; broad client lists belong in UniFi, not Git.
