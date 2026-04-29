# Proxmox install notes

Operational install-day checklist: [Proxmox install preflight](../../runbooks/proxmox-install-preflight.md).

## BIOS checklist

- Update BIOS before production workloads if practical.
- Enable Intel virtualization support.
- Enable UEFI boot.
- Confirm NVMe is detected.
- Confirm installed RAM and choose target or low-RAM bootstrap profile.
- Leave Quick Sync passthrough untouched initially.

## Host settings

| Setting | Value |
| --- | --- |
| Hostname | `opti` / `proxmox` DNS aliases |
| Management IP | `192.168.1.60` |
| VLAN | Default LAN / untagged |
| Role | Hypervisor only |

## Bridge notes

Use one VLAN-aware Linux bridge, normally `vmbr0`. The exact NIC name is hardware/distribution dependent; verify it on the host before editing.

See `proxmox/snippets/interfaces.example` for an example only.

## Snapshot policy

Use Proxmox snapshots only as short test checkpoints:

1. Take snapshot.
2. Test change.
3. Delete snapshot.

No long-lived snapshots on the Opti NVMe.

## Low-RAM warning

If the Opti arrives below `32 GB`, use the low-RAM bootstrap profile. Do not build the full HAOS + Docker baseline until RAM headroom is available.
