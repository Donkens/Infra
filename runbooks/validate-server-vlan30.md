# Validate Server VLAN 30

> Read-only runbook for validating Server VLAN 30 before Opti/VM workloads.

## Scope

- Read-only validation only.
- No firewall changes.
- No UDR/UniFi writes.
- No service restarts or reloads.

## Preconditions

- A test client or VM is attached to Server VLAN 30.
- Expected subnet: `192.168.30.0/24`.
- Expected gateway: `192.168.30.1`.
- Expected DNS: `192.168.1.55`.

## Commands from VLAN 30 client

macOS DHCP packet details, if available:

```bash
ipconfig getpacket en0
```

macOS resolver and interface checks:

```bash
scutil --dns
ifconfig
route -n get default
```

DNS path checks:

```bash
dig @192.168.1.55 pi.home.lan A +short +time=2 +tries=1
dig @192.168.30.1 pi.home.lan A +short +time=2 +tries=1 || true
dig @1.1.1.1 cloudflare.com A +short +time=2 +tries=1 || true
```

Optional reachability checks:

```bash
ping -c 3 192.168.30.1
ping -c 3 192.168.1.55
traceroute 192.168.1.55
```

## Expected

- Client IP is in `192.168.30.0/24`.
- Default route is via `192.168.30.1`.
- DNS is distributed as `192.168.1.55`.
- Pi DNS answers via `@192.168.1.55`.
- Gateway DNS should timeout if block policy covers Server VLAN.
- WAN DNS should timeout if bypass block covers Server VLAN.

## Failure interpretation

| Symptom | Meaning |
|---|---|
| Gateway DNS answers from `@192.168.30.1` | DNS bypass gap. |
| `@1.1.1.1` answers | WAN DNS bypass gap. |
| No Pi DNS answer | DHCP, firewall, routing, or Pi DNS path issue. |
| Wrong subnet/gateway | VLAN/profile/client attachment issue. |

## Links

- [UniFi networks](../inventory/unifi-networks.md)
- [UniFi firewall](../inventory/unifi-firewall.md)
- [Network validation](../docs/network-validation.md)
- [Opti network and VLAN plan](../docs/opti/10-network-vlan.md)
