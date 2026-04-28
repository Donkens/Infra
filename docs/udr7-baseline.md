# UDR-7 baseline

> Sanitized UDR-7 / UniFi Network baseline for the homelab.
> Last verified: 2026-04-28 19:45 CEST

## Identity

| Field | Value |
|---|---|
| Gateway IP | `192.168.1.1` |
| Hostname | `udrhomelan` |
| DNS name | `udr.home.lan` |
| Model | `UDMA67A` |
| UniFi OS / firmware | `5.0.16.30692` |
| Network app | `10.3.58` |
| Site | `default` |
| Timezone | `Europe/Stockholm` |
| SSH user | `root` |

UDR aliases `udr7` and `router` currently have SSH host-key drift from the Mac mini. Use `ssh udr` or direct `ssh 192.168.1.1` until aliases are deliberately repaired.

## WAN

- ISP: Tele2.
- WAN IPv4 is present but not stored in this repository.
- WAN IPv6 is disabled / absent.
- UDR WAN DNS points to Pi DNS at `192.168.1.55`.

## Gateway DNS listeners

UDR dnsmasq listens on gateway addresses, including:

- `127.0.0.1:53`
- `192.168.1.1:53`
- `192.168.10.1:53`
- `192.168.30.1:53`
- `192.168.40.1:53`
- `10.10.10.1:53`
- ULA gateway addresses for active ULA networks

Firewall policy must keep ordinary clients on Pi DNS. Default and MLO client bypass tests were verified blocked on 2026-04-28. Server VLAN 30 and IoT gateway-DNS behavior still need explicit client-side validation.

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
