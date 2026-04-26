# Opti Phase 0 - pre-install checklist

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

1. Plug Opti into UDR-7 port 3.
2. Apply `Opti Trunk` profile to port 3 in UniFi (or via MCP).
3. Install Proxmox. Set static IP `192.168.1.60` on host interface.
4. Verify: `ping proxmox.home.lan` → `192.168.1.60`, Proxmox UI on `:8006`.
5. Create VMs with VLAN 30 interface → Docker VM (`.10`), HAOS VM (`.20`).
6. Verify DHCP from VMs (range `.100`–`.199`).
7. Verify DNS from VMs: `dig @192.168.1.55 docker.home.lan`, `ha.home.lan`.
8. Issue `GO firewall` — create Server zone and firewall rules.

## Low-RAM branch

If host RAM is below `32 GB`, bootstrap only:

- Proxmox install.
- VLAN 30 validation.
- Basic HAOS/Docker structure.
- Light services only.
- Documentation.

Wait for `32 GB` before heavy workloads.
