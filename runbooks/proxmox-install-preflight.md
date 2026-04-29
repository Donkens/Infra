# Proxmox install preflight

Scope: install-day checklist for Dell OptiPlex 7080 Micro running Proxmox VE bare metal.

This runbook prepares the Opti for Proxmox install only. It does not approve UniFi, firewall, Pi DNS, package, or service runtime changes. Those require separate Phase 1/2 plans and explicit `GO`.

## Target

| Field | Value |
| --- | --- |
| Hardware | Dell OptiPlex 7080 Micro |
| CPU | i7-10700T |
| RAM target | `32 GB` |
| Disk target | `512 GB NVMe` |
| NIC | `1 GbE` |
| Host role | Proxmox VE bare metal hypervisor |
| Host IP | `192.168.1.60/24` on Default LAN / untagged |
| Gateway | `192.168.1.1` |
| DNS | `192.168.1.55` |
| Domain | `home.lan` |

Verify actual RAM, disk, and NIC in BIOS or installer before wiping anything.

## Hard stops

Stop before install if any item is true:

- Off-Pi backup sync has not produced at least one verified run after the scheduled job became active, if that run is being used as the current safety baseline.
- Installed RAM is unknown.
- Installed RAM is below `32 GB` and the low-RAM branch has not been chosen explicitly.
- UniFi Opti port/trunk decision is not clear.
- VLAN 30 cannot be validated after install with [Validate Server VLAN 30](validate-server-vlan30.md).
- More than one possible install disk is present and the target NVMe is not obvious.
- Proxmox VE ISO source/checksum has not been verified.
- Vaultwarden is planned before workload backup/restore drill is complete.
- Any password, token, private key, recovery secret, or raw backup content would be pasted into docs, chat, shell history, or Git.

## Hardware identity

- Confirm model: Dell OptiPlex 7080 Micro.
- Confirm CPU: i7-10700T.
- Confirm RAM amount.
- Confirm `512 GB NVMe` target disk.
- Confirm wired `1 GbE` link.
- Choose profile:
  - `32 GB`: target profile.
  - Below `32 GB`: low-RAM bootstrap only.

## USB installer checklist

- Download Proxmox VE ISO from the official Proxmox source.
- Verify ISO checksum from the official checksum source.
- Create USB installer with a known-good imaging tool.
- Boot via UEFI USB from the Opti boot menu.
- Do not wipe any disk until the target NVMe is confirmed in the installer.

## BIOS checklist

- Use UEFI boot.
- Enable Intel virtualization / VT-x.
- Disable Secure Boot unless a supported Proxmox Secure Boot path is confirmed separately.
- Set USB first for install, then NVMe first after install.
- Confirm NVMe is detected.
- Confirm RAM amount.
- Set power restore behavior intentionally if the option is present.
- Do not update BIOS during install flow unless a separate BIOS update plan exists.
- Leave Quick Sync passthrough untouched initially.

## Disk wipe plan

- Removing Windows from the Opti NVMe is intentional.
- Confirm the target disk is the internal NVMe before install.
- Disconnect or avoid other disks unless they are intentionally part of the install.
- Preserve no Windows data unless it has already been backed up separately.
- Treat the Proxmox installer wipe as destructive and irreversible.

## UniFi/network preflight

UDR-7 remains gateway, VLAN, firewall, and WireGuard authority. Pi remains DNS.

Expected network model:

| Network | Port mode | Purpose |
| --- | --- | --- |
| Default LAN | Native / untagged | Proxmox host management |
| Server VLAN 30 | Tagged | HAOS and Docker VMs |

Expected install fields:

| Field | Value |
| --- | --- |
| Host IP | `192.168.1.60/24` |
| Gateway | `192.168.1.1` |
| DNS | `192.168.1.55` |
| Domain/search | `home.lan` |

Preflight checks:

- Confirm the Opti will use UDR-7 port `3` unless the port plan changes.
- Confirm `Opti Trunk` uses Default LAN native and VLAN 30 tagged.
- Do not make firewall changes during install.
- Do not move Server VLAN 30 to a dedicated firewall zone without a separate `GO firewall` plan.

References:

- [Opti network and VLAN plan](../docs/opti/10-network-vlan.md)
- [VLAN inventory](../inventory/vlans.md)
- [UniFi networks](../inventory/unifi-networks.md)

## Proxmox installer fields

Use these values unless a Phase 1 install plan changes them:

| Field | Value |
| --- | --- |
| Hostname | `opti.home.lan` |
| Static IP | `192.168.1.60/24` |
| Gateway | `192.168.1.1` |
| DNS server | `192.168.1.55` |
| Domain/search | `home.lan` |
| Filesystem/storage | Decision point: choose Proxmox installer default unless a separate storage plan selects another layout. Do not choose an aggressive ZFS layout without confirming RAM/headroom. |
| Email/root password | Operator-held only. Do not paste or commit secrets. |

DNS aliases `opti.home.lan` and `proxmox.home.lan` are planned names. Service status stays planned until the host exists and UI/API reachability is validated.

## vmbr0 VLAN-aware checklist

- Use one Linux bridge, normally `vmbr0`.
- Attach `vmbr0` to the physical NIC discovered on the Opti.
- Keep Proxmox host management untagged on Default LAN.
- Enable VLAN-aware bridge mode.
- Use VLAN tag `30` on Server VMs:
  - HAOS VM `101`: tag `30`, IP `192.168.30.20`.
  - Debian Docker VM `102`: tag `30`, IP `192.168.30.10`.
- Do not paste example config blindly. Verify the real NIC name first.

Reference example: [interfaces.example](../proxmox/snippets/interfaces.example).

## First login / post-install validation

From a trusted admin client:

```bash
ping -c 3 192.168.1.60
open https://192.168.1.60:8006
```

On the Proxmox host, record observed values:

```bash
ip a
ip route
cat /etc/network/interfaces
pveversion
timedatectl
```

Storage sanity checks:

```bash
lsblk
pvesm status
df -h
```

DNS/network checks:

```bash
ping -c 3 192.168.1.1
ping -c 3 192.168.1.55
getent hosts proxmox.home.lan || true
getent hosts pi.home.lan || true
```

Post-install decision points:

- Proxmox subscription/no-subscription repository policy.
- Update policy.
- SSH policy.
- Storage layout adjustments.

Do not run automatic update or repository commands from this preflight unless a separate approved plan names the exact commands.

## VLAN 30 validation handoff

Do not consider Server VLAN 30 ready for workloads until [Validate Server VLAN 30](validate-server-vlan30.md) passes from a VLAN 30 client or VM.

Expected:

- Client IP is in `192.168.30.0/24`.
- Default route is `192.168.30.1`.
- DNS is `192.168.1.55`.
- Pi DNS answers.
- Gateway/WAN DNS bypass checks behave as documented.

## Backup/restore gates

References:

- [Backup and restore policy](../docs/opti/60-backup-restore.md)
- [Opti backup and restore-test checklist](opti-backup-restore-test.md)

Current state:

- Pi DNS off-Pi backup exists and has passed a safe restore drill.
- Opti/Proxmox workload backups still need their own backup process and restore drill.
- Vaultwarden remains blocked until backup destination, backup process, and restore-test are complete.

## Low-RAM branch

If installed RAM is below `32 GB`:

- Install Proxmox only if the low-RAM branch is explicitly approved.
- Keep VM footprint minimal.
- Use HAOS and Docker bootstrap profiles only.
- Do not deploy Jellyfin.
- Do not deploy Vaultwarden.
- Do not deploy heavy MCP/dev/media workloads.
- Upgrade RAM before moving beyond light services.

## Stop criteria / rollback boundary

Stop before destructive disk wipe if disk identity, target disk, or data-preservation status is uncertain.

Before workloads exist, reinstalling Proxmox is acceptable if install choices are wrong. After workloads exist, create a new Phase 0/1 plan before reinstalling or wiping.

Do not troubleshoot install/network failures by changing UniFi, firewall, Pi DNS, or VLAN runtime blindly. Use read-only validation first, then create a separate `GO` plan if runtime changes are needed.

Document final observed values after install:

- Actual RAM.
- Actual disk model/size.
- Actual NIC name.
- Final `/etc/network/interfaces`.
- Proxmox version.
- Storage layout.
- Validation results.
