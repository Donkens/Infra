# Proxmox Phase 0 audit - opti

Date: 2026-05-03

Status: WARN.

This was a read-only documentation baseline for Proxmox host `opti`. No live
changes were made.

## Scope

In scope:

- Proxmox host baseline.
- HAOS VM `101` Proxmox-side state.
- Backup, storage, network, and security posture.
- Documentation drift.

Out of scope:

- Proxmox changes.
- HAOS changes.
- Pi, UDR, DNS, AdGuard, Unbound, UniFi, VLAN, firewall, Home Assistant Core,
  SSH config, restarts, reboots, package installs, and package upgrades.

## Current state

| Area | State |
| --- | --- |
| Hostname | `opti` |
| Proxmox VE | `9.1.0` |
| Manager | `pve-manager 9.1.9` |
| Kernel | `7.0.0-3-pve` |
| IP | `192.168.1.60/24` |
| Gateway | `192.168.1.1` |
| DNS | `192.168.1.55` |
| Bridge | `vmbr0`, VLAN-aware |
| Storage | `local` and `local-lvm` active and healthy |
| NVMe SMART | PASS, `Percentage Used: 1%`, `Media and Data Integrity Errors: 0`, `Temperature: 26 Celsius` |
| Failed systemd units | none |
| APT | repos sane; no upgradable packages listed |
| VMs | VM `101 haos` running; Docker VM `102` absent/planned |
| CTs | `0` |
| HAOS health | `issues: []`, `suggestions: []`, `unhealthy: []`, `unsupported: []` |
| QGA | `agent: enabled=1`; `qm agent 101 ping` fails with `QEMU guest agent is not running` |
| HAOS onboot | `0` |
| Proxmox backups | no job; `/var/lib/vz/dump` empty |

## PASS

- Proxmox host identity, version, kernel, IP, DNS, and gateway match baseline.
- `vmbr0` is VLAN-aware and HAOS VM `101` runs on VLAN `30`.
- No failed systemd units were reported.
- Storage is healthy with `local` and `local-lvm` active.
- NVMe SMART health is currently OK.
- APT repository policy is sane for Debian `trixie` and Proxmox
  `pve-no-subscription`; no upgradable packages were listed.
- HAOS health is clean.
- Docker VM `102` is still absent/planned, matching the intended workload gate.

## WARN

1. No Proxmox-level backup job exists yet.
2. `/var/lib/vz/dump` is empty.
3. No confirmed off-host Proxmox/VM restore-test exists yet.
4. SSH hardening is pending:
   `PermitRootLogin yes`, `PasswordAuthentication yes`, `X11Forwarding yes`,
   `AllowTcpForwarding yes`.
5. No PVE firewall policy files were found under `/etc/pve`.
6. `rpcbind` listens on `0.0.0.0:111` and `[::]:111`; review whether it is
   needed.
7. Server VLAN 30 isolation/firewall-zone work remains a separate `GO firewall`
   task.
8. HAOS QEMU Guest Agent is a known WARN: the VM option is enabled, but HAOS is
   not running/responding to QGA.
9. HAOS VM `101` has `onboot: 0`, so it will not autostart after a Proxmox host
   reboot unless changed.
10. NVMe reports `Unsafe Shutdowns: 117`; current SMART health is OK.
11. CPU governor is `performance`, which is acceptable but less idle-efficient.

## Recommendations

| Priority | Area | Recommendation | Requires GO? |
| --- | --- | --- | --- |
| P1 | Backups | Create Proxmox backup job, off-host destination, and restore-test before critical workloads | yes |
| P1 | SSH | Plan key-only SSH hardening and root login reduction | yes |
| P1 | Firewall | Review PVE firewall posture and Server VLAN 30 isolation | yes |
| P1 | Availability | Decide whether HAOS VM `101` should use `onboot=1` | yes |
| P2 | Docs | Keep QGA state documented as known WARN, not as responding | no |
| P2 | rpcbind | Review whether `rpcbind` is required on the host | yes |
| P3 | Power | Consider a measured power tuning pass later | yes |

## Avoid

- Do not install packages inside HAOS to fix QGA.
- Do not run `qm set 101 --agent enabled=1`; the option is already enabled.
- Do not deploy Vaultwarden or other critical workloads before Proxmox/off-host
  backup and restore-test are documented and completed.
- Do not move Server VLAN 30 or change firewall policy without a separate
  `GO firewall` plan.

## Documentation drift

- `docs/opti/00-baseline.md` previously said the QEMU guest agent responds.
  Live state is `agent: enabled=1`, but `qm agent 101 ping` returns
  `QEMU guest agent is not running`.
- `docs/opti/10-network-vlan.md` had the same QGA drift.
- Docker VM `102` remains absent/planned.
- HAOS VM `101` still has `onboot: 0`.
- Proxmox backups are not configured; HAOS local backups exist but do not
  provide a Proxmox/off-host restore strategy.
- Proxmox host security hardening remains pending.

## Confirmed no changes

No Proxmox, HAOS, Pi, UDR, DNS, AdGuard, Unbound, UniFi, VLAN, firewall, SSH,
package, restart, reboot, or runtime changes were made by this audit.
