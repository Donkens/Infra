# Opti Phase 0 - pre-install checklist

Read-only planning only. No writes to live systems from this repo task.

## Checklist

- Confirm shipped RAM amount.
- Choose `32 GB` target profile or low-RAM bootstrap branch.
- Review BIOS checklist.
- Confirm UniFi port plan: Default LAN native, VLAN 30 tagged.
- Confirm planned IPs do not conflict.
- Decide first backup disk target, preferably external USB-SSD.
- Confirm no Tailscale, no Jellyfin, no Vaultwarden initially.

## Low-RAM branch

If host RAM is below `32 GB`, bootstrap only:

- Proxmox install.
- VLAN 30 validation.
- Basic HAOS/Docker structure.
- Light services only.
- Documentation.

Wait for `32 GB` before heavy workloads.
