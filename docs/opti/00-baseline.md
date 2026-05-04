# Opti baseline

## Verified baseline — 2026-05-04

Latest read-only Proxmox audit: [Proxmox Phase 0 audit — 2026-05-03](proxmox-phase-0-audit-2026-05-03.md).

The Opti is installed and validated as a Proxmox VE host. HAOS VM `101` is live
on Server VLAN 30. Debian Docker VM `102` is live on Server VLAN 30 as of
2026-05-04 Phase 1A — see [docker-vm-102-baseline.md](docker-vm-102-baseline.md).

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
| `102` | `docker` | Debian Docker VM | `192.168.30.10/24`, VLAN 30 | live — Phase 1A 2026-05-04 |

HAOS VM `101` uses `q35`, `OVMF`, `cpu host`, `2` cores, `6144 MB` RAM,
`64 GB` on `local-lvm`, and `net0` on `vmbr0` with VLAN tag `30`. The QEMU
Guest Agent option is enabled with `agent: enabled=1`, but the HAOS guest agent
is not running/responding; this is a known WARN. HAOS VM `101` now has
`onboot: 1`, enabling HAOS autostart after a Proxmox host reboot. No reboot or
restart was performed during the `onboot` change.

### Proxmox Phase 0 audit — 2026-05-03

Status: WARN. No live changes were made.

| Area | Live state |
| --- | --- |
| Proxmox VE | `9.1.0` |
| Manager | `pve-manager 9.1.9` |
| Kernel | `7.0.0-3-pve` |
| Failed units | none |
| APT | Debian `trixie`, `trixie-updates`, `trixie-security`, Proxmox `pve-no-subscription`; no upgradable packages listed |
| Storage | `local` and `local-lvm` active and healthy |
| NVMe SMART | PASS, `Percentage Used: 1%`, `Media and Data Integrity Errors: 0`, `Temperature: 26 Celsius` |
| VM inventory | VM `101 haos` running; CT count `0`; Docker VM `102` absent/planned |
| HAOS health | `issues: []`, `suggestions: []`, `unhealthy: []`, `unsupported: []` |
| QGA | `agent: enabled=1`; `qm agent 101 ping` returns `QEMU guest agent is not running` |
| Proxmox backups | interim vzdump of VM 101 completed 2026-05-03; off-host copy on Mac mini; restore-test PASS 2026-05-03 |
| Security posture | SSH hardened Phase 2A; PVE host firewall active Phase 2B 2026-05-03: `host.fw`+`cluster.fw` applied, allowlist `192.168.1.0/24` ports 22/8006/3128/ICMP, inbound DROP; rpcbind blocked at host firewall, service running (nfs-blkmap dependency) |

Phase 0 WARN items:

- Interim vzdump of VM 101 (haos) completed 2026-05-03 as Phase 2A snapshot;
  off-host copy on Mac mini at
  `/Users/yasse/InfraBackups/proxmox-dumps/vzdump-qemu-101-2026_05_03-22_48_45.vma.zst`;
  SHA256 verified; this is interim only — see
  `docs/opti/60-backup-restore.md` for full status.
- No scheduled Proxmox backup job yet; `/var/lib/vz/dump` has one manual dump.
- Restore-test PASS 2026-05-03: VMID 199 imported from dump, booted 52 s, destroyed; see `runbooks/opti-backup-restore-test.md`.
- ~~Proxmox SSH posture remains broad.~~ **Resolved Phase 2A 2026-05-03:**
  `/etc/ssh/sshd_config.d/99-hardening.conf` applied: `PasswordAuthentication no`,
  `X11Forwarding no`, `AllowTcpForwarding no`, `PermitRootLogin prohibit-password`.
  Both MBP and Mac mini validated with new key-only sessions after reload.
  PVE firewall and `rpcbind` review remain separate pending tasks.
- ~~No PVE firewall policy files under `/etc/pve`.~~ **Applied Phase 2B 2026-05-03:**
  `cluster.fw` (`enable: 1`) and `host.fw` (allowlist `192.168.1.0/24` → ports
  22/8006/3128/ICMP; DROP all other inbound) written and loaded. `pve-firewall`
  status `enabled/running`. New SSH sessions and Web UI validated after reload.
  See `docs/opti/proxmox-firewall-review-2026-05-03.md`.
- `rpcbind` on `0.0.0.0:111`: service still running (nfs-blkmap dependency);
  inbound port 111 now **blocked by host firewall** (no ACCEPT rule, hits DROP).
  Restrict rpcbind to localhost as separate defence-in-depth GO if desired.
- Server VLAN 30 isolation/firewall-zone work remains a separate `GO firewall`
  task.
- HAOS QGA is a known WARN; do not install packages inside HAOS for this.
- NVMe has `Unsafe Shutdowns: 117`, while current SMART health is OK.
- CPU governor is `performance`; acceptable, but less idle-efficient.

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

`Advanced SSH & Web Terminal` was later configured for key-only access and
started successfully. Port `22` on `192.168.30.20` is open, and key-based SSH
login from the MacBook works. Non-interactive SSH `ha` CLI access is fixed by
`/home/hassio/.zshenv`, which sources `/etc/profile.d/homeassistant.sh` so
`SUPERVISOR_TOKEN` is available to `zsh` SSH commands.

SSH admin aliases were validated on 2026-05-03:

| Client | Key | Validated aliases |
| --- | --- | --- |
| MacBook `mbp` | `~/.ssh/id_ed25519_mbp` | `ssh opti`, `ssh proxmox`, `ssh ha`, `ssh haos` |
| Mac mini `mini` | `~/.ssh/id_ed25519_macmini` | `ssh opti`, `ssh proxmox`, `ssh ha`, `ssh haos` |

Proxmox `sshd` hardening was not changed during this validation; password auth
remains a separate future hardening review.

### WiZ integration baseline — 2026-05-03

WiZ integration added to HAOS. Five WiZ bulbs on IoT VLAN 10 are controlled by HAOS
on Server VLAN 30 via a dedicated firewall rule. No integration-specific HAOS
add-ons are required; WiZ uses UDP 38899-38900 for device control.

| Object | Value |
| --- | --- |
| IP group | `wiz-bulbs-ipv4` (`69f683421bc6e72d27767433`) |
| Permanent firewall rule | `allow-haos-wiz-control` (`69f687011bc6e72d277674c3`), **enabled** |
| Temporary ICMP rule | `allow-haos-wiz-icmp-temp` (`69f687011bc6e72d277674c6`), **disabled** 2026-05-03 |
| WiZ bulb IPs | `192.168.10.129`, `.131`, `.133`, `.134`, `.174` |
| WiZ inventory | `5` devices, `20` entities, `0` missing effective areas |
| Protocol | UDP 38899-38900, src `192.168.30.20` → dst `wiz-bulbs-ipv4` |
| Full backup | `haos-wiz-baseline-2026-05-03-full`, slug `3e602056`, `full`, `2026-05-03T18:47:34.215668+00:00`, `0.22 MB` |
| Resolution state | `issues: []`, `suggestions: []`, `unhealthy: []`, `unsupported: []` |

Area mapping verified in HAOS:

| WiZ suffix | Area |
| --- | --- |
| `4F823E` | Kitchen |
| `4F8388` | Bathroom |
| `4F8602` | Living Room |
| `4F8818` | Living Room |
| `4F8888` | Hallway |

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
