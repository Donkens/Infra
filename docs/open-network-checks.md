# Open network checks

> Current follow-up list after the UDR-7 / UniFi baseline.
> Last updated: 2026-04-28

## P1

- Validate Server VLAN 30 DNS bypass from an actual Server VLAN client.
- Validate Server VLAN 30 gateway DNS block from `192.168.30.1`.
- Validate Server VLAN 30 WAN DNS bypass block using `@1.1.1.1`.
- Validate Server VLAN 30 firewall isolation before workloads.
- Validate IoT-to-gateway DNS behavior from an IoT client.

## P2

- Identify hidden `element-b85dc41a14f3982d` SSID or document owner/purpose.
- Repair or standardize UDR SSH aliases `udr`, `udr7`, `router` after host-key drift review.

## P3

- Re-check MLO status because controller reports `mlo_enabled=false` while 6 GHz SSID is live.
- Re-check Guest network stays disabled.

## Safety

- Read-only validation first.
- No UDR/UniFi writes without separate `GO`.
- No firewall changes without Phase 0/1/2.

## Links

- [UniFi networks](../inventory/unifi-networks.md)
- [UniFi firewall](../inventory/unifi-firewall.md)
- [UniFi WiFi](../inventory/unifi-wifi.md)
- [Network validation](network-validation.md)
- [UDR-7 baseline](udr7-baseline.md)
