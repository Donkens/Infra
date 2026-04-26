# Opti Phase 1 - Proxmox install plan

## Scope

Install Proxmox VE bare metal on the Opti and configure host management on Default LAN.

## Plan

1. Confirm BIOS settings and installed RAM.
2. Install Proxmox VE on NVMe.
3. Set host IP to `192.168.1.60`.
4. Configure VLAN-aware `vmbr0`.
5. Validate Proxmox UI at `192.168.1.60:8006`.
6. Validate VLAN 30 VM tagging with a test VM or controlled VM setup.

## Low-RAM branch

If installed RAM is below `32 GB`, do not build the full target layout. Keep only the minimum VMs needed to validate Proxmox, VLAN 30, and basic service structure.

## Boundaries

- No long-lived snapshots.
- No application services on the Proxmox host.
- No DNS or firewall changes without a separate approved task.
