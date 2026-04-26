# VLANs

| VLAN | Name | Subnet | Role | Status |
| ---: | --- | --- | --- | --- |
| untagged | Default LAN | `192.168.1.0/24` | Trusted LAN, Proxmox host management | ✅ live |
| `10` | IOT | `192.168.10.0/24` | IoT devices, limited access | ✅ live |
| `20` | Guest | `192.168.20.0/24` | Guest network | ⛔ disabled |
| `30` | Server | `192.168.30.0/24` | HAOS and Docker VM workloads | ✅ live |
| `40` | MLO-LAN | `192.168.40.0/24` | 6 GHz WiFi clients | ✅ live |

## Server VLAN 30

| Field | Value |
| --- | --- |
| UniFi network ID | `69ee65711bc6e72d27744844` |
| DHCP range | `192.168.30.100` – `192.168.30.199` |
| Static / reserved | `.10` Docker VM, `.20` HAOS VM (no DHCP reservation until MAC known) |
| DNS | `192.168.1.55` |
| Firewall zone | Shared LAN zone — dedicated zone required at `GO firewall` step |

## Opti Trunk port profile

| Field | Value |
| --- | --- |
| UniFi profile ID | `69ee65781bc6e72d2774484b` |
| Forward mode | `customize` |
| Native | Default LAN |
| Tagged | Server VLAN 30 only |
| Applied to port | No — apply when Opti arrives on port 3 |

## Opti switch port plan

- Native / untagged: Default LAN
- Tagged: VLAN `30` only (IOT, MLO, Guest excluded)
- Recommended port: UDR-7 port 3

Proxmox `vmbr0` should be VLAN-aware. VM `101` and VM `102` use tag `30`.
