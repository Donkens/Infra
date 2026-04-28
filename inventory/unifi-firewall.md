# UniFi firewall policies

> Current custom UniFi firewall policy inventory.
> Last verified: 2026-04-28 19:45 CEST

## Scope

This file tracks custom DNS-related UniFi firewall policies on UDR-7. It does not replace the live controller; it is a sanitized source-of-truth for future audits.

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

## Verified behavior

- Default + MLO client DNS bypass is verified blocked from Mac mini: `@192.168.1.1` and `@1.1.1.1` timed out.
- Pi upstream DNS is allowed: Pi can query external DNS as expected for recursion/upstream use.
- UDR dnsmasq listens on gateway IPs, so firewall blocks are required to keep ordinary clients on Pi DNS.

## Follow-up validation needed

- Server VLAN 30 DNS bypass and gateway DNS behavior must be verified before workloads are placed there.
- IoT-to-gateway DNS needs explicit client-side test documentation; current policy inventory confirms IoT-to-WAN DNS block and IoT-to-Pi DNS allow.
- `docs/unifi-firewall-state-2026-04-15.md` is superseded/stale for current policy count. Keep it as historical context only.
