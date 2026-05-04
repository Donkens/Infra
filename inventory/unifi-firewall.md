# UniFi firewall policies

> Current custom UniFi firewall policy inventory.
> Last verified: 2026-05-04 CEST — Phase 2B applied

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
| `allow-haos-wiz-control` | **yes** | ALLOW | zone policy | HAOS `192.168.30.20` in Server zone `69f7de611bc6e72d2776b75b` | `wiz-bulbs-ipv4` in IoT zone `6980de97e060a06b8ef9b613` | UDP `38899-38900` | `69f687011bc6e72d277674c3` | Permanent. Updated from Internal to Server source zone in Phase 2A. index=10000. |
| `allow-haos-yeelight-control` | **yes** | ALLOW | zone policy | HAOS `192.168.30.20` in Server zone `69f7de611bc6e72d2776b75b` | Yeelight `192.168.10.150` in IoT zone `6980de97e060a06b8ef9b613` | TCP `55443` | `69f869c91bc6e72d2776d75f` | HAOS → Yeelight Bedroom. Minimal rule, index 10001. IPV4 only. create_allow_respond: true. No SSDP/multicast, no broad VLAN access. |
| `allow-haos-wiz-icmp-temp` | **no** | ALLOW | zone policy | HAOS `192.168.30.20`; source zone still Internal `677d9959ed22014620a6a981` | `wiz-bulbs-ipv4` in IoT zone | ICMP | `69f687011bc6e72d277674c6` | Temporary validation rule. **Disabled 2026-05-03**; left unchanged in Phase 2A. index=10001. |
| `allow-server-to-pi-dns-udp` | yes | ALLOW | zone policy | Server zone `69f7de611bc6e72d2776b75b` ANY | Pi DNS `192.168.1.55` in Internal zone | UDP `53` | `69f7dec11bc6e72d2776b789` | Phase 2A continuity rule. |
| `allow-server-to-pi-dns-tcp` | yes | ALLOW | zone policy | Server zone `69f7de611bc6e72d2776b75b` ANY | Pi DNS `192.168.1.55` in Internal zone | TCP `53` | `69f7dec11bc6e72d2776b78c` | Phase 2A continuity rule. |
| `allow-lan-admin-to-haos` | yes | ALLOW | zone policy | Internal zone `677d9959ed22014620a6a981` ANY | HAOS `192.168.30.20` in Server zone | TCP `8123` | `69f7dec11bc6e72d2776b78f` | Phase 2A continuity rule for HAOS UI. |
| `allow-lan-admin-to-haos-ssh` | yes | ALLOW | zone policy | Internal zone `677d9959ed22014620a6a981` ANY | HAOS `192.168.30.20` in Server zone | TCP `22` | `69f7df531bc6e72d2776b7c0` | Phase 2A continuity rule preserving pre-existing HAOS admin SSH reachability. |

## Verified behavior

- Default + MLO client DNS bypass is verified blocked from Mac mini: `@192.168.1.1` and `@1.1.1.1` timed out.
- Pi upstream DNS is allowed: Pi can query external DNS as expected for recursion/upstream use.
- UDR dnsmasq listens on gateway IPs, so firewall blocks are required to keep ordinary clients on Pi DNS.

## Verified behavior

- Default + MLO client DNS bypass is verified blocked from Mac mini: `@192.168.1.1` and `@1.1.1.1` timed out.
- Pi upstream DNS is allowed: Pi can query external DNS as expected for recursion/upstream use.
- UDR dnsmasq listens on gateway IPs, so firewall blocks are required to keep ordinary clients on Pi DNS.

## Server VLAN 30 Phase 2A — completed 2026-05-04

Live-tested from HAOS `192.168.30.20` via SSH after the UniFi zone migration.

| Item | Detail |
|---|---|
| Dedicated Server zone | Created `Server` zone `69f7de611bc6e72d2776b75b` |
| VLAN 30 zone move | Server VLAN 30 (`69ee65711bc6e72d27744844`) moved from `Internal` `677d9959ed22014620a6a981` to `Server` `69f7de611bc6e72d2776b75b` |
| WiZ rule update | `allow-haos-wiz-control.source.zone_id` updated from `677d9959ed22014620a6a981` to `69f7de611bc6e72d2776b75b` |
| Continuity ALLOW | Server → Pi DNS UDP/TCP 53; Internal → HAOS TCP 8123 and TCP 22 |
| Phase 2B blocks | Applied 2026-05-04 |

## Server VLAN 30 Phase 2B — completed 2026-05-04

Applied after Phase 2A validation. DNS bypass gaps closed.

| Item | Detail |
|---|---|
| Gateway DNS bypass blocked | `block-server-gateway-dns-udp/tcp` — Server → Gateway `192.168.30.1` UDP/TCP 53 BLOCK |
| WAN DNS bypass blocked | `block-server-wan-dns-udp/tcp` — Server → External ANY UDP/TCP 53 BLOCK |
| Server → Internal isolation | Zone default `block_all` (set when Server zone was created) already blocks Server-initiated connections to Internal. No explicit rule needed. `block-server-to-internal` rule created then **disabled** after discovering it also blocked ESTABLISHED return traffic, breaking HAOS reachability from Internal. |

### Phase 2B key finding — zone default block

When the custom `Server` zone was created, UniFi automatically set `block_all` for `Server → Internal` (and other cross-zone pairs). This means:
- HAOS cannot initiate TCP/ICMP to Internal zone hosts (confirmed: `ping 192.168.1.60` from HAOS → 100% loss).
- Return/ESTABLISHED traffic from HAOS back to Internal clients IS allowed (handled by the existing ALLOW rules with `create_allow_respond: true`).
- An explicit `block-server-to-internal` with `connection_state_type: ALL` blocked ESTABLISHED return traffic, breaking HAOS TCP reachability from Internal. Rule was disabled after validation.

### Phase 2B validation results — 2026-05-04

| Test | Expected | Result |
|---|---|---|
| `HA_CORE_OK_AFTER_2B` | PASS | ✅ PASS |
| HAOS resolution info | `issues: []` | ✅ PASS |
| HAOS → Pi DNS `@192.168.1.55` | `192.168.1.55` | ✅ PASS |
| HAOS → Internet `ping 1.1.1.1` | 0% loss | ✅ PASS |
| HAOS UI `192.168.30.20:8123` from Mac mini | reachable | ✅ PASS |
| HAOS SSH `192.168.30.20:22` from Mac mini | reachable | ✅ PASS |
| Gateway DNS bypass `@192.168.30.1:53` | TIMEOUT | ✅ BLOCKED |
| WAN DNS bypass `@1.1.1.1:53` | TIMEOUT | ✅ BLOCKED |
| Server → Internal ICMP `192.168.1.60` | BLOCKED | ✅ BLOCKED (zone default) |
| `allow-haos-wiz-control` | enabled, source zone Server | ✅ OK |
| `qm status 101` | running | ✅ PASS |
| No Docker VM 102 rules | none created | ✅ confirmed |

Isolation plan and approval blocks: [`docs/opti/server-vlan30-isolation-plan-2026-05-03.md`](../docs/opti/server-vlan30-isolation-plan-2026-05-03.md)

## Live policies for Server zone

| Policy | Direction | Source | Destination | Port | Action | ID | Status |
|---|---|---|---|---|---|---|---|
| `allow-server-to-pi-dns-udp` | Server → Internal | Server zone ANY | IP `192.168.1.55` | UDP 53 | ALLOW | `69f7dec11bc6e72d2776b789` | ✅ Live Phase 2A |
| `allow-server-to-pi-dns-tcp` | Server → Internal | Server zone ANY | IP `192.168.1.55` | TCP 53 | ALLOW | `69f7dec11bc6e72d2776b78c` | ✅ Live Phase 2A |
| `block-server-to-internal` | Server → Internal | Server zone ANY | ANY | all | BLOCK | `69f816d31bc6e72d2776c2d0` | ⛔ Disabled — redundant; zone default already blocks; explicit rule breaks ESTABLISHED return traffic |
| `allow-lan-admin-to-haos` | Internal → Server | Internal zone ANY | IP `192.168.30.20` | TCP 8123 | ALLOW | `69f7dec11bc6e72d2776b78f` | ✅ Live Phase 2A |
| `allow-lan-admin-to-haos-ssh` | Internal → Server | Internal zone ANY | IP `192.168.30.20` | TCP 22 | ALLOW | `69f7df531bc6e72d2776b7c0` | ✅ Live Phase 2A |
| `block-server-gateway-dns-udp` | Server → Gateway | Server zone ANY | IP `192.168.30.1` | UDP 53 | BLOCK | `69f816ba1bc6e72d2776c2c2` | ✅ Live Phase 2B |
| `block-server-gateway-dns-tcp` | Server → Gateway | Server zone ANY | IP `192.168.30.1` | TCP 53 | BLOCK | `69f816c31bc6e72d2776c2c6` | ✅ Live Phase 2B |
| `block-server-wan-dns-udp` | Server → External | Server zone ANY | ANY | UDP 53 | BLOCK | `69f816c81bc6e72d2776c2c9` | ✅ Live Phase 2B |
| `block-server-wan-dns-tcp` | Server → External | Server zone ANY | ANY | TCP 53 | BLOCK | `69f816cc1bc6e72d2776c2cd` | ✅ Live Phase 2B |
| `allow-server-to-wan` | Server → External | Server zone ANY | ANY | all (non-53) | ALLOW | — | Not created — HAOS internet works via zone default |
| `allow-haos-yeelight-control` | Server → IoT | HAOS `192.168.30.20` | Yeelight `192.168.10.150` | TCP 55443 | ALLOW | `69f869c91bc6e72d2776d75f` | ✅ Live 2026-05-04 |

## Follow-up validation needed

- IoT-to-gateway DNS needs explicit client-side test documentation; current policy inventory confirms IoT-to-WAN DNS block and IoT-to-Pi DNS allow.
- `docs/unifi-firewall-state-2026-04-15.md` is superseded/stale for current policy count. Keep it as historical context only.
- `allow-haos-wiz-icmp-temp` (`69f687011bc6e72d277674c6`) is disabled, not deleted. Delete via UniFi UI when convenient (Settings → Security → Traffic & Firewall Rules → find rule → Delete).
- `block-server-to-internal` (`69f816d31bc6e72d2776c2d0`) is disabled. Delete via UniFi UI when convenient, or leave disabled as documentation of the zone-default-block finding.
