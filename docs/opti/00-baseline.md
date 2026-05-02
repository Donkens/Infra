# Opti baseline

## Verified baseline — 2026-05-02

The Opti is installed and validated as a Proxmox VE host. HAOS VM `101` is live
on Server VLAN 30. The Debian Docker VM has not been created yet.

| Area | Value |
| --- | --- |
| Hardware | Dell OptiPlex 7080 Micro |
| CPU | Intel i7-10700T |
| RAM | `32 GB` |
| Disk | `512 GB NVMe` |
| OS | Proxmox VE `9.1.0` |
| Manager | `pve-manager 9.1.9` |
| Running kernel | `7.0.0-3-pve` |
| Hostname | `opti` |
| FQDN | `opti.home.lan` |
| Management bridge | `vmbr0` |
| Management IP | `192.168.1.60/24` |
| Gateway | `192.168.1.1` |
| DNS | `192.168.1.55` |

### Network config

`vmbr0` is the management bridge on Default LAN/native untagged and is
configured VLAN-aware for future VM traffic.

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

### APT baseline

| Repository | Status |
| --- | --- |
| Debian `trixie` | enabled |
| Debian `trixie-updates` | enabled |
| Debian `trixie-security` | enabled |
| Proxmox `pve-no-subscription` for `trixie` | enabled |
| Proxmox enterprise | disabled |
| Ceph enterprise | disabled |

### Validation result

| Check | Result |
| --- | --- |
| `systemctl --failed` | `0 loaded units listed` |
| `local` storage | active |
| `local-lvm` storage | active |
| Gateway ping `192.168.1.1` | OK |
| DNS node ping `192.168.1.55` | OK |
| Internet ping `1.1.1.1` | OK |
| `qm list` | HAOS VM `101` running |
| `pct list` | empty |

### Live workloads

| VMID | Name | Role | Network | Status |
| ---: | --- | --- | --- | --- |
| `101` | `haos` | Home Assistant OS | `192.168.30.20/24`, VLAN 30 | live |

HAOS VM `101` uses `q35`, `OVMF`, `cpu host`, `2` cores, `6144 MB` RAM,
`64 GB` on `local-lvm`, and `net0` on `vmbr0` with VLAN tag `30`. The QEMU
guest agent responds. `onboot` is currently `0`.

### HAOS onboarding and backup baseline

HAOS onboarding and the first backup baseline are complete. The UI responds on
`http://192.168.30.20:8123`, `http://ha.home.lan:8123`, and
`http://haos.home.lan:8123`.

| Check | Result |
| --- | --- |
| Core | `2026.4.4` |
| Supervisor | `2026.04.2`, `healthy: true`, `supported: true` |
| HAOS | `17.2` |
| Full backup | `haos-onboarding-baseline-2026-05-02-full` |
| Backup date | `2026-05-02T21:50:45.400045+00:00` |
| Backup type | `full` |
| Backup protected | `false` |
| Backup size | `0.12 MB` |
| Resolution state | `issues: []`, `suggestions: []`, `unhealthy: []`, `unsupported: []` |

The stale `no_current_backup` repair was cleared with
`ha resolution check run backups`. Older partial backups still exist and were
not modified. Core was not restarted, Supervisor was not reloaded/restarted, and
the host was not rebooted during the resolution refresh.

Follow-up: `Advanced SSH & Web Terminal` was observed with `state: error`; this
is not a blocker for the backup baseline.

## Target architecture

Dell OptiPlex 7080 Micro runs Proxmox VE bare metal. Proxmox is a hypervisor only; workloads live in VMs.

| Component | Role | Notes |
| --- | --- | --- |
| UDR-7 | Gateway, VLAN, firewall, WireGuard | Authority for network policy. |
| Pi | DNS primary | AdGuard Home -> Unbound remains the DNS chain. |
| Opti | Proxmox hypervisor | `192.168.1.60`, Default LAN / untagged. |
| VM 101 | HAOS | `192.168.30.20`, VLAN 30. |
| VM 102 | Debian Docker | `192.168.30.10`, VLAN 30. |
| Mac mini / MacBook | Admin clients | SSH/browser admin from trusted devices only. |

## Target RAM profile

Target host RAM is `32 GB`.

| Allocation | Target |
| --- | ---: |
| Proxmox host reserve | `~4-6 GB` |
| HAOS VM | `2 vCPU`, `6 GB RAM`, `64 GB disk` |
| Docker VM | `6 vCPU`, `18 GB RAM`, `200 GB disk` |
| Headroom | Host overhead, bursts, cache, small future services |

## Low-RAM bootstrap profile

`32 GB` is the target profile, not a hard blocker for documentation or initial bootstrap.

| Host RAM | Policy |
| --- | --- |
| `16 GB` | HAOS `4 GB`; Docker `6-8 GB`; keep services light. |
| `8 GB` | Do not run the full layout; validate network and run one lightweight VM at a time. |

Safe before `32 GB`: Proxmox install, VLAN 30 validation, HAOS bootstrap, Docker Engine + Compose, Caddy, Dockge, Uptime Kuma, Dozzle, `node_exporter`. Stremio Server is optional only if memory pressure is acceptable.

Wait for `32 GB` before many HA add-ons, MCP/dev workloads, code-server/OpenVSCode, heavy media services, Vaultwarden, Transmission-heavy usage, Prometheus/Grafana, or a local media library.

## First-week skip list

- No Tailscale initially; WireGuard on UDR-7 is primary.
- No Jellyfin initially.
- No Vaultwarden until backup and restore-test are complete.
- No Quick Sync passthrough unless Jellyfin/local media is added later.
- No large media library, large downloads, or long-lived snapshots on NVMe.
- No public/WAN exposure.
