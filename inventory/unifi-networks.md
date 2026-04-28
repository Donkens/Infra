# UniFi networks

> Current UniFi network source-of-truth for the homelab.
> Last verified: 2026-04-28 19:45 CEST

## Controller context

| Field | Value |
|---|---|
| Gateway | `udr.home.lan` / `udrhomelan` |
| Model | `UDMA67A` |
| UniFi OS / firmware | `5.0.16.30692` |
| Network app | `10.3.58` |
| Site | `default` |
| WAN | Tele2 IPv4 present; WAN IPv6 disabled |
| Internal IPv6 | ULA prefixes are used internally |
| DNS node | Raspberry Pi at `192.168.1.55` |

## Networks

| Network | Status | VLAN | Subnet | Gateway | DHCP range | DNS distributed | IPv6 / ULA | RA | DHCPv6 | Domain | Firewall zone | UniFi resource ID | Notes |
|---|---|---:|---|---|---|---|---|---|---|---|---|---|---|
| Default | LIVE | untagged | `192.168.1.0/24` | `192.168.1.1` | `192.168.1.6`-`192.168.1.254` | `192.168.1.55`; DHCPv6 DNS `fd12:3456:7801::55` | `fd12:3456:7801::/64` | enabled | enabled | `home.lan` | Internal `677d9959ed22014620a6a981` | `67505ffb6c2b447c24945afc` | Primary trusted LAN. |
| IOT | LIVE | `10` | `192.168.10.0/24` | `192.168.10.1` | `192.168.10.2`-`192.168.10.200` | `192.168.1.55` | `fd12:3456:7802::/64` | enabled | disabled | `iot.lan` | IOT `6980de97e060a06b8ef9b613` | `67544633c43374040ca74d5a` | IoT client network; DNS-to-Pi allow exists. |
| UniFi Guest | DISABLED | `20` | `192.168.20.0/24` | `192.168.20.1` | `192.168.20.2`-`192.168.20.100` | configured fields include `192.168.1.55` and `192.168.1.1`, but network disabled | none | configured true, inactive while disabled | not verified | empty | Hotspot `677d9959ed22014620a6a985` | `6794382d80972e6da3b2ff37` | Guest network and guest SSID are disabled. |
| Server | LIVE | `30` | `192.168.30.0/24` | `192.168.30.1` | `192.168.30.100`-`192.168.30.199` | `192.168.1.55` | none | none | none | `home.lan` | Internal `677d9959ed22014620a6a981` | `69ee65711bc6e72d27744844` | Network exists live. Workload/firewall isolation needs separate `GO` before heavy workloads. |
| MLO-LAN | LIVE | `40` | `192.168.40.0/24` | `192.168.40.1` | `192.168.40.6`-`192.168.40.254` | `192.168.1.55`; DHCPv6 DNS field points to Pi ULA | `fd12:3456:7804::/64` | enabled | disabled | `mlo.lan` | Internal `677d9959ed22014620a6a981` | `6924b0ed6a052a2a0be0affc` | 6 GHz client network; iPhone fixed client exists. |
| WireGuard Server 1 | LIVE | n/a | `10.10.10.0/24` | `10.10.10.1` | `10.10.10.2`-`10.10.10.254` | `192.168.1.55` | UNKNOWN | UNKNOWN | UNKNOWN | n/a | Vpn `677d9959ed22014620a6a984` | `69bafbfb5f55514edd926ca5` | Remote-user VPN; no key material belongs in Git. |

## Notes

- Pi DNS node is `192.168.1.55`.
- Default DHCP DNS is `192.168.1.55`.
- Default DHCPv6 DNS is `fd12:3456:7801::55`.
- WAN IPv6 is disabled; internal ULA prefixes are active on Default, IOT, and MLO-LAN.
- Server VLAN 30 exists live, but workload readiness depends on a separate firewall/isolation validation.
- Guest network is disabled and should remain documented separately from live client networks.
