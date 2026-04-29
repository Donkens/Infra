# Opti Phase 0 - pre-install checklist

Install-day checklist: [Proxmox install preflight](proxmox-install-preflight.md).

Use this file for current readiness summary. Use the preflight runbook for BIOS, USB installer, disk wipe, Proxmox installer fields, first login, and post-install validation.

## Network prep status (completed 2026-04-26)

| Item | Status | Detail |
| --- | --- | --- |
| Server VLAN 30 created | ✅ Done | ID `69ee65711bc6e72d27744844`, subnet `192.168.30.1/24` |
| DHCP configured | ✅ Done | Range `.100`–`.199`, DNS `192.168.1.55`, domain `home.lan` |
| IPv6 disabled on VLAN 30 | ✅ Done | `ipv6_interface_type: none` |
| Opti Trunk port profile created | ✅ Done | ID `69ee65781bc6e72d2774484b`, forward `customize` |
| Opti Trunk applied to port | ❌ Not yet | Apply to UDR-7 port 3 when Opti arrives |
| AdGuard DNS rewrites (10 names) | ✅ Done | Verified with `dig @192.168.1.55` |
| IP conflict check | ✅ Clear | `192.168.1.60`, `192.168.30.10`, `192.168.30.20` all free |
| Firewall rules for Server VLAN | ❌ Not yet | Separate `GO firewall` required |
| Server VLAN in dedicated zone | ❌ Not yet | Currently shares LAN zone — prerequisite for firewall step |

## Hardware checklist (do before plugging in)

- [ ] Confirm shipped RAM amount.
- [ ] Choose `32 GB` target profile or low-RAM bootstrap branch.
- [ ] Review BIOS: enable virtualisation, disable unnecessary peripherals.
- [ ] Confirm UniFi port 3 is available for Opti.
- [ ] Confirm no Tailscale, no Jellyfin, no Vaultwarden initially.
- [ ] Decide first backup disk target (USB-SSD preferred).

## Steps when Opti arrives

1. Open [Proxmox install preflight](proxmox-install-preflight.md).
2. Plug Opti into the approved UDR-7 port.
3. Apply `Opti Trunk` profile only after separate `GO` if it is not already applied.
4. Install Proxmox using the preflight checklist.
5. Validate Proxmox host management on `192.168.1.60`.
6. Validate VLAN 30 with [Validate Server VLAN 30](validate-server-vlan30.md).
7. Issue `GO firewall` only after install and validation are clear.

## Low-RAM branch

If host RAM is below `32 GB`, bootstrap only:

- Proxmox install.
- VLAN 30 validation.
- Basic HAOS/Docker structure.
- Light services only.
- Documentation.

Wait for `32 GB` before heavy workloads.
