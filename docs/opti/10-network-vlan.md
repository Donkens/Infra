# Opti network and VLAN plan

## Implementation status

| Component | Status | Date |
| --- | --- | --- |
| Server VLAN 30 | ✅ Live | 2026-04-26 |
| Proxmox host baseline | ✅ Live | 2026-05-02 |
| Opti Trunk port profile | ✅ Created; UI profile name not re-verified in VLAN test | 2026-04-26 |
| AdGuard DNS rewrites | ✅ Live, verified | 2026-04-26 |
| Opti path VLAN tagging | ✅ Linux/UDR switch state confirms VLAN 30 tagged on Opti path | 2026-05-02 |
| VLAN 30 VM/tap traffic | ✅ Validated with temporary CT `900`, then destroyed | 2026-05-02 |
| Firewall rules (Server zone) | ❌ Not yet — separate GO required | — |

## Trunk model

The UniFi switch port to the Opti should use:

| Network | Port mode | Purpose |
| --- | --- | --- |
| Default LAN | Native / untagged | Proxmox host management |
| Server VLAN 30 | Tagged | HAOS and Docker VMs |

### UniFi resource IDs

| Resource | ID |
| --- | --- |
| Server VLAN 30 network | `69ee65711bc6e72d27744844` |
| Opti Trunk port profile | `69ee65781bc6e72d2774484b` |

### Opti Trunk profile details

- `forward: customize` (`tagged_vlan_mgmt: custom`)
- Native: Default LAN (`67505ffb6c2b447c24945afc`)
- Tagged: Server VLAN 30 only
- Excluded (not tagged): IOT/VLAN 10, MLO-LAN/VLAN 40, Guest/VLAN 20
- Applied to physical path: Linux/UDR switch state confirmed VLAN 30 tagged on
  the Opti path on 2026-05-02; UniFi UI profile name was not separately
  verified in that run.

### UDR-7 port map

| Port | Name | Current profile | Opti candidate |
| ---: | --- | --- | --- |
| 1 | Pi-DNS | LAN – Pi / Lab | — |
| 2 | Mini-LAN | 2 LAN – Mac mini | — |
| 3 | (Unused) | disabled | ✅ Recommended for Opti |
| 4 | WAN – Tele2 C4 | Default (WAN cable) | — |
| 5 | SFP+ (Unused) | disabled | Alternative |

## Proxmox bridge

`vmbr0` should be VLAN-aware. The Proxmox host uses untagged Default LAN for management. VMs attach to `vmbr0` with VLAN tag `30`.

Verified host config on 2026-05-02:

```text
auto vmbr0
iface vmbr0 inet static
	address 192.168.1.60/24
	gateway 192.168.1.1
	bridge-ports nic0
	bridge-stp off
	bridge-fd 2
	bridge-vlan-aware yes
	bridge-vids 2-4094
```

`bridge vlan show dev vmbr0` currently shows only VLAN `1 PVID Egress Untagged`.
That is expected until VM/tap interfaces exist and attach to `vmbr0` with VLAN
tag `30`.

## VLAN 30 guest validation

Validated on 2026-05-02 with a temporary LXC CT:

| Field | Value |
| --- | --- |
| CTID | `900` |
| Hostname | `tmp-vlan30-test` |
| Bridge | `vmbr0` |
| VLAN tag | `30` |
| Temporary IP | `192.168.30.250/24` |
| Gateway tested | `192.168.30.1` |
| Pi DNS tested | `192.168.1.55` |
| Template | `debian-13-standard_13.1-2_amd64.tar.zst` |
| Cleanup | CT `900` destroyed after validation |

Validation result:

- CT received `192.168.30.250/24` on `eth0`.
- Default route was `192.168.30.1`.
- `ping 192.168.30.1` passed.
- `ping 192.168.1.55` passed.
- `ping 1.1.1.1` passed.
- `getent hosts pi.home.lan` returned Pi DNS records.

No HAOS or Docker VM was created by this validation.

## Server VLAN 30 details

| Field | Value |
| --- | --- |
| Name | Server |
| VLAN ID | 30 |
| Subnet / gateway | `192.168.30.1/24` |
| DHCP range | `192.168.30.100` – `192.168.30.199` |
| DNS server | `192.168.1.55` |
| Domain | `home.lan` |
| IPv6 | Disabled (ipv4-only) |
| Firewall zone | LAN zone (shared with Default LAN) — see note below |

> **Firewall zone note:** Server VLAN 30 was automatically placed in the same firewall zone as Default LAN (`677d9959ed22014620a6a981`). Zone-based inter-VLAN rules between Default LAN and Server VLAN 30 will not be enforced until Server is moved to a dedicated zone. This is a prerequisite for the `GO firewall` step.

## DNS names — verified in AdGuard

| Name | IP | VLAN | Role | Status |
| --- | --- | --- | --- | --- |
| `opti.home.lan` | `192.168.1.60` | Default LAN | Proxmox host | ✅ live |
| `proxmox.home.lan` | `192.168.1.60` | Default LAN | Proxmox UI/API | ✅ live |
| `docker.home.lan` | `192.168.30.10` | Server VLAN 30 | Docker VM | ✅ live |
| `proxy.home.lan` | `192.168.30.10` | Server VLAN 30 | Caddy reverse proxy | ✅ live |
| `ha.home.lan` | `192.168.30.20` | Server VLAN 30 | HAOS | ✅ live |
| `haos.home.lan` | `192.168.30.20` | Server VLAN 30 | HAOS alias | ✅ live |
| `dockge.home.lan` | `192.168.30.10` | Server VLAN 30 | Dockge | ✅ live |
| `uptime.home.lan` | `192.168.30.10` | Server VLAN 30 | Uptime Kuma | ✅ live |
| `dozzle.home.lan` | `192.168.30.10` | Server VLAN 30 | Dozzle | ✅ live |
| `stremio.home.lan` | `192.168.30.10` | Server VLAN 30 | Stremio | ✅ live |

## VM tags

| VM | VLAN tag | Access |
| --- | ---: | --- |
| `101` HAOS | `30` | `ha.home.lan:8123` direct |
| `102` Debian Docker | `30` | SSH plus Caddy-managed services |

## Pre-workload validation

Server VLAN 30 exists live in UniFi and uses Pi DNS (`192.168.1.55`). The Opti host is live on Default LAN/native, while HAOS and Docker VMs remain planned on Server VLAN 30.

Before placing heavy workloads on VLAN 30:

- verify DNS bypass and gateway DNS block coverage from a Server VLAN client
- verify firewall isolation policy for Server VLAN 30
- keep WAN port forwards disabled
- keep Pi as the DNS node
- do not move Server VLAN into a dedicated firewall zone without a separate `GO` plan
