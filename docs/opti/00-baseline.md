# Opti baseline

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
