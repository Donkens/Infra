# UDR-7 baseline

> Sanitized UDR-7 / UniFi Network baseline for the homelab.
> Last verified: 2026-05-06 CEST — Phase 0 audit via UniFi MCP

## Identity

| Field | Value |
|---|---|
| Gateway IP | `192.168.1.1` |
| Hostname | `udrhomelan` |
| DNS name | `udr.home.lan` |
| Model | `UDMA67A` |
| UniFi OS / firmware | `5.0.16.30692` (major `5.0.16` confirmed; full build from prior inventory, not re-verified by `ubnt-device-info firmware`) |
| Network app | `10.3.58` |
| Site | `default` |
| Timezone | `Europe/Stockholm` |
| SSH user | `root` |

All five SSH aliases are canonical and verified as of 2026-05-06:

| Alias | Resolves to | User | Key |
|---|---|---|---|
| `ssh udr` | `udr.home.lan` | `root` | `id_ed25519_udr2` |
| `ssh udr7` | `udr.home.lan` | `root` | `id_ed25519_udr2` |
| `ssh router` | `udr.home.lan` | `root` | `id_ed25519_udr2` |
| `ssh udr.home.lan` | `udr.home.lan` | `root` | `id_ed25519_udr2` |
| `ssh 192.168.1.1` | `udr.home.lan` | `root` | `id_ed25519_udr2` |

Canonical alias: `ssh udr`. All aliases share one config block in the iCloud-synced
ssh-config (`Scripts/infra/ssh-config`), effective on mini and mbp.
Pi is intentionally not configured as a UDR SSH client (DNS server role only).

## WAN

- ISP: Tele2.
- WAN IPv4 is present but not stored in this repository.
- WAN IPv6 is disabled / absent.
- WAN DNS: `wan_dns1: 192.168.1.55` (Pi), `wan_dns2: ""` — Pi only, no secondary. Verified live 2026-05-06 via mongo `networkconf`.
- WAN2 (`Internet 2`, ID `68fbe7ea2549353d5f544815`): configured failover-only profile (`wan_failover_priority: 2`, `wan_load_balance_type: failover-only`); physical port `eth4` is DOWN — no WAN2 cable connected. DNS preference is `auto` (DHCP-assigned if ever active). Not currently active.

## Gateway DNS listeners

UDR dnsmasq listens on gateway addresses, including:

- `127.0.0.1:53`
- `192.168.1.1:53`
- `192.168.10.1:53`
- `192.168.30.1:53`
- `192.168.40.1:53`
- `10.10.10.1:53`
- ULA gateway addresses for active ULA networks

Firewall policy must keep ordinary clients on Pi DNS. All VLAN bypass vectors verified blocked and runtime-validated as of 2026-05-06; see [`inventory/unifi-firewall.md`](../inventory/unifi-firewall.md) and [`docs/network-validation.md`](network-validation.md).

## DNS authority model

- UDR / UniFi owns DHCP, gateway, VLANs, WiFi, WireGuard, and firewall policy.
- UDR DHCP distributes Pi DNS (`192.168.1.55`) to live client networks.
- Pi is the DNS node.
- AdGuard Home is the LAN-facing DNS/filtering/rewrite layer.
- Unbound provides recursion and local reverse/PTR authority.

## Related inventory

- [UniFi networks](../inventory/unifi-networks.md)
- [UniFi firewall](../inventory/unifi-firewall.md)
- [UniFi WiFi](../inventory/unifi-wifi.md)
- [DHCP reservations](../inventory/dhcp-reservations.md)
- [DNS names](../inventory/dns-names.md)
- [VLANs](../inventory/vlans.md)

## Safe read-only audit commands

Run these only for inspection. Do not provision, restart, reboot, or apply changes from an audit shell.

```bash
ssh udr 'hostname; whoami; uname -a; ubnt-device-info firmware'
ssh udr 'ip -brief addr show br0 br10 br30 br40 wgsrv1'
ssh udr 'ss -tulpn | grep -E "(:53|:443|:8443|:51820)\b"'
ssh udr 'mongo --port 27117 ace --quiet --eval "db.networkconf.find({}, {name:1,purpose:1,vlan:1,ip_subnet:1,dhcpd_dns_1:1,dhcpdv6_dns_1:1,ipv6_subnet:1,enabled:1}).forEach(printjson)"'
```

Do not print raw UniFi objects that may contain credentials or VPN key material.
