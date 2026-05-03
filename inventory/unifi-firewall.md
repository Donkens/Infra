# UniFi firewall policies

> Current custom UniFi firewall policy inventory.
> Last verified: 2026-05-03 CEST

## Scope

This file tracks custom UniFi firewall policies and IP groups on UDR-7. It does not replace the live controller; it is a sanitized source-of-truth for future audits.

## IP groups

| Group | IPs | Resource ID | Notes |
|---|---|---|---|
| `wiz-bulbs-ipv4` | `192.168.10.129`, `.131`, `.133`, `.134`, `.174` | `69f683421bc6e72d27767433` | All WiZ bulbs on IoT VLAN 10. Used as destination in `allow-haos-wiz-control`. |

## Custom policies

| Policy | Enabled | Action | Direction / type | Source summary | Destination summary | Protocol / ports | Resource ID | Notes |
|---|---:|---|---|---|---|---|---|---|
| `IoT DNS to Pi` | yes | ALLOW | zone policy | IOT zone `6980de97e060a06b8ef9b613` | Pi DNS `192.168.1.55`, `fd12:3456:7801::55` in Internal zone | all, port `53` | `699d85638c8bad417c824dc3` | Allows IoT clients to resolve through Pi DNS. |
| `block-iot-to-wan-dns-bypass` | yes | BLOCK | zone policy | IOT zone | WAN / External zone | all, port `53` | `69dfd0443c599e2e12f029d0` | Blocks classic IoT DNS bypass to WAN resolvers. |
| `allow-pi-dns-upstream-to-wan-udp` | yes | ALLOW | zone policy | Pi `192.168.1.55` in Internal zone | WAN / External zone | UDP `53` | `69ee4d011bc6e72d27743fa2` | Allows Pi DNS upstream queries. |
| `allow-pi-dns-upstream-to-wan-tcp` | yes | ALLOW | zone policy | Pi `192.168.1.55` in Internal zone | WAN / External zone | TCP `53` | `69ee4d011bc6e72d27743fa5` | Allows Pi DNS upstream fallback over TCP. |
| `block-internal-gateway-dns-udp` | yes | BLOCK | zone policy | Default + MLO networks in Internal zone | Gateway DNS IPs `192.168.1.1`, `192.168.40.1` | UDP `53` | `69ee4d011bc6e72d27743fa8` | Blocks UDR dnsmasq bypass for verified client networks. |
| `block-internal-gateway-dns-tcp` | yes | BLOCK | zone policy | Default + MLO networks in Internal zone | Gateway DNS IPs `192.168.1.1`, `192.168.40.1` | TCP `53` | `69ee4d011bc6e72d27743fab` | TCP companion to gateway DNS block. |
| `block-internal-wan-dns-udp` | yes | BLOCK | zone policy | Default + MLO networks in Internal zone | WAN / External zone | UDP `53` | `69ee4d011bc6e72d27743fae` | Blocks direct WAN DNS from Default/MLO. |
| `block-internal-wan-dns-tcp` | yes | BLOCK | zone policy | Default + MLO networks in Internal zone | WAN / External zone | TCP `53` | `69ee4d021bc6e72d27743fb1` | TCP companion to WAN DNS block. |
| `allow-haos-wiz-control` | **yes** | ALLOW | zone policy | HAOS `192.168.30.20` in Server zone `677d9959ed22014620a6a981` | `wiz-bulbs-ipv4` in IoT zone `6980de97e060a06b8ef9b613` | UDP `38899-38900` | `69f687011bc6e72d277674c3` | Permanent. Allows HAOS to control WiZ bulbs. index=10000. |
| `allow-haos-wiz-icmp-temp` | **no** | ALLOW | zone policy | HAOS `192.168.30.20` in Server zone | `wiz-bulbs-ipv4` in IoT zone | ICMP | `69f687011bc6e72d277674c6` | Temporary validation rule. **Disabled 2026-05-03** after WiZ integration confirmed. index=10001. |

## Verified behavior

- Default + MLO client DNS bypass is verified blocked from Mac mini: `@192.168.1.1` and `@1.1.1.1` timed out.
- Pi upstream DNS is allowed: Pi can query external DNS as expected for recursion/upstream use.
- UDR dnsmasq listens on gateway IPs, so firewall blocks are required to keep ordinary clients on Pi DNS.

## Verified behavior

- Default + MLO client DNS bypass is verified blocked from Mac mini: `@192.168.1.1` and `@1.1.1.1` timed out.
- Pi upstream DNS is allowed: Pi can query external DNS as expected for recursion/upstream use.
- UDR dnsmasq listens on gateway IPs, so firewall blocks are required to keep ordinary clients on Pi DNS.

## Server VLAN 30 gaps — confirmed 2026-05-03

Live-tested from HAOS `192.168.30.20` via SSH.

| Gap | Detail |
|---|---|
| No dedicated Server zone | VLAN 30 (`69ee65711bc6e72d27744844`) in `Internal` zone (`677d9959ed22014620a6a981`) — zone-based isolation impossible |
| Gateway DNS bypass open | `@192.168.30.1:53` answers from HAOS — `block-internal-gateway-dns-*` rules use `network_ids` that exclude Server VLAN 30 |
| WAN DNS bypass uncovered | `block-internal-wan-dns-*` rules use `network_ids` that exclude Server VLAN 30 |
| `allow-haos-wiz-control` zone dependency | `source.zone_id = 677d9959ed22014620a6a981` (Internal) — breaks on zone migration if not updated atomically |

Isolation plan and approval blocks: [`docs/opti/server-vlan30-isolation-plan-2026-05-03.md`](../docs/opti/server-vlan30-isolation-plan-2026-05-03.md)

## Planned policies for Server zone (pending GO Phase 2A + 2B)

| Policy | Direction | Source | Destination | Port | Action | Status |
|---|---|---|---|---|---|---|
| `allow-server-to-pi-dns-udp` | Server → Internal | Server zone ANY | IP `192.168.1.55` | UDP 53 | ALLOW | Planned |
| `allow-server-to-pi-dns-tcp` | Server → Internal | Server zone ANY | IP `192.168.1.55` | TCP 53 | ALLOW | Planned |
| `allow-server-to-wan` | Server → External | Server zone ANY | ANY | all (non-53) | ALLOW | Planned |
| `allow-lan-admin-to-haos` | Internal → Server | Internal zone ANY | IP `192.168.30.20` | TCP 8123 | ALLOW | Planned |
| `block-server-wan-dns-udp` | Server → External | Server zone ANY | ANY | UDP 53 | BLOCK | Planned |
| `block-server-wan-dns-tcp` | Server → External | Server zone ANY | ANY | TCP 53 | BLOCK | Planned |
| `block-server-gateway-dns-udp` | Server → Gateway | Server zone ANY | IP `192.168.30.1` | UDP 53 | BLOCK | Planned |
| `block-server-gateway-dns-tcp` | Server → Gateway | Server zone ANY | IP `192.168.30.1` | TCP 53 | BLOCK | Planned |
| `block-server-to-internal` | Server → Internal | Server zone ANY | ANY | all | BLOCK | Planned |

## Follow-up validation needed

- IoT-to-gateway DNS needs explicit client-side test documentation; current policy inventory confirms IoT-to-WAN DNS block and IoT-to-Pi DNS allow.
- `docs/unifi-firewall-state-2026-04-15.md` is superseded/stale for current policy count. Keep it as historical context only.
- `allow-haos-wiz-icmp-temp` is disabled, not deleted. Delete via UniFi UI during Phase 2B (Settings → Security → Traffic & Firewall Rules → find rule → Delete).
