# VLANs

> Current UniFi network source-of-truth: [unifi-networks.md](unifi-networks.md).

| VLAN | Name | Subnet | Role | Status |
| ---: | --- | --- | --- | --- |
| untagged | Default LAN | `192.168.1.0/24` | Trusted LAN, Proxmox host management | ✅ live |
| `10` | IOT | `192.168.10.0/24` | IoT devices, limited access | ✅ live |
| `20` | Guest | `192.168.20.0/24` | Guest network | ⛔ disabled |
| `30` | Server | `192.168.30.0/24` | HAOS and Docker VM workloads | ✅ live; workload/firewall readiness needs validation |
| `40` | MLO-LAN | `192.168.40.0/24` | 6 GHz WiFi clients | ✅ live; WLAN MLO flag currently DRIFT/UNKNOWN |

## Server VLAN 30

| Field | Value |
| --- | --- |
| UniFi network ID | `69ee65711bc6e72d27744844` |
| DHCP range | `192.168.30.100` – `192.168.30.199` |
| Static / reserved | `.10` Docker VM, `.20` HAOS VM |
| DNS | `192.168.1.55` |
| Firewall zone | Shared LAN zone — dedicated zone required at `GO firewall` step. Current firewall state: [`docs/unifi-firewall-state-2026-04-15.md`](../docs/unifi-firewall-state-2026-04-15.md) |

## Opti Trunk port profile

| Field | Value |
| --- | --- |
| UniFi profile ID | `69ee65781bc6e72d2774484b` |
| Forward mode | `customize` |
| Native | Default LAN |
| Tagged | Server VLAN 30 only |
| Applied to port | Linux/UDR switch state confirmed VLAN 30 tagged on Opti path 2026-05-02; UniFi UI profile name not separately verified in that run |

## Opti switch port plan

- Native / untagged: Default LAN
- Tagged: VLAN `30` only (IOT, MLO, Guest excluded)
- Recommended port: UDR-7 port 3

## Opti Proxmox host

As of 2026-05-02, Proxmox management is live on native/untagged Default LAN:
`192.168.1.60/24` on `vmbr0`.

Proxmox `vmbr0` is VLAN-aware. Future VM workloads use VLAN tag `30`:

| VM | Planned IP | VLAN tag | Status |
| --- | --- | ---: | --- |
| `101` HAOS | `192.168.30.20` | `30` | live |
| `102` Debian Docker | `192.168.30.10` | `30` | planned |

VLAN 30 VM/tap traffic was validated with a temporary CT on 2026-05-02.

### VLAN 30 VM/tap validation

Validated 2026-05-02 with temporary LXC CT `900` named
`tmp-vlan30-test`.

| Field | Value |
| --- | --- |
| Bridge | `vmbr0` |
| VLAN tag | `30` |
| Temporary IP | `192.168.30.250/24` |
| Gateway tested | `192.168.30.1` |
| Pi DNS tested | `192.168.1.55` |
| Internet ping | `1.1.1.1` passed |
| Cleanup | CT `900` destroyed after validation |

HAOS VM `101` is live on VLAN 30. Debian Docker VM `102` remains planned.

## MLO-LAN VLAN 40

- Network exists live in UniFi.
- iPhone fixed/reserved client exists at `192.168.40.207`.
- `UniFi MLO/6Ghz` is assigned to VLAN 40, but controller reports `mlo_enabled=false`; see [unifi-wifi.md](unifi-wifi.md).
