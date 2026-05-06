# Runbook: Validate UDR firewall

> Read-only validation commands for confirming firewall and DNS enforcement posture on the UDR-7.
> Run these after any firewall/network change or as a periodic sanity check.
> Do **not** apply changes from an audit shell. Phase 1/2 rules apply for any write.

Last updated: 2026-05-06

---

## 1. DNS enforcement — clients receive Pi DNS

Confirm DHCP-distributed DNS for each live VLAN:

```bash
# Live mongo view: which DNS is distributed per network
ssh udr 'mongo --port 27117 ace --quiet --eval "
db.networkconf.find(
  {enabled: {$ne: false}},
  {name:1, vlan:1, ip_subnet:1, dhcpd_dns_1:1, dhcpdv6_dns_1:1}
).forEach(printjson)"'
```

Expected: `dhcpd_dns_1: 192.168.1.55` for Default, IOT, Server, MLO-LAN, WireGuard.

---

## 2. DNS bypass block tests

These confirm UDR dnsmasq is not reachable from client VLANs (policy should block or redirect).

Run from a client on each VLAN (or from a temporary LXC with the VLAN tag):

```bash
# Should be blocked by firewall policy (not return a response)
dig @192.168.1.1 cloudflare.com        # from Default LAN client
dig @192.168.10.1 cloudflare.com       # from IOT client
dig @192.168.30.1 cloudflare.com       # from Server VLAN client
dig @192.168.40.1 cloudflare.com       # from MLO-LAN client

# Should succeed (Pi DNS)
dig @192.168.1.55 cloudflare.com
```

Expected: gateway queries time out / REFUSED; Pi query resolves.

Check which block/redirect rules are active:

```bash
# iptables DNS redirect/block rules on UDR
ssh udr 'iptables -t nat -L PREROUTING -n -v | grep -E "dpt:53|udp.*53"'
ssh udr 'iptables -L FORWARD -n -v | grep -E ":53 "'
```

---

## 3. Admin paths — Proxmox and Docker UI access

```bash
# Test Docker VM port reachability from Default LAN (should succeed for admin host)
curl -sk --max-time 3 https://192.168.30.10:2375 -o /dev/null -w "%{http_code}\n"  # Docker API (if exposed)
curl -sk --max-time 3 http://192.168.30.10:9000  -o /dev/null -w "%{http_code}\n"  # Portainer (if running)

# Proxmox UI reachability from Default LAN (should succeed)
curl -sk --max-time 3 https://192.168.1.60:8006  -o /dev/null -w "%{http_code}\n"

# Proxmox rule is disabled — confirm Docker VM cannot reach Proxmox on 8006 from Server zone
# (run from 192.168.30.10 or a Server-VLAN LXC)
curl -sk --max-time 3 https://192.168.1.60:8006  -o /dev/null -w "%{http_code}\n"
# Expected: connection refused / timeout (disabled Proxmox rule)
```

---

## 4. IoT isolation

IoT clients (VLAN 10) should not reach LAN or Server resources directly.

```bash
# From an IoT client (192.168.10.x):
ping -c3 192.168.1.1      # gateway — reachable (allowed for DNS/DHCP)
ping -c3 192.168.1.55     # Pi DNS — reachable (explicit allow)
ping -c3 192.168.1.60     # Opti/Proxmox — should be BLOCKED
ping -c3 192.168.30.10    # Docker VM — should be BLOCKED
ping -c3 192.168.30.20    # HAOS — should be BLOCKED

# Check IoT zone firewall rules in UniFi MCP or:
ssh udr 'iptables -L FORWARD -n -v | grep "192.168.10"'
```

---

## 5. Server zone isolation (VLAN 30)

Server zone (Docker VM `.10`, HAOS `.20`) should only reach internet and Pi DNS; LAN-initiated access only via explicit allow rules.

```bash
# From Docker VM (192.168.30.10) or a Server-VLAN LXC:
ping -c3 1.1.1.1            # internet — should succeed
dig @192.168.1.55 google.com # Pi DNS — should succeed
ping -c3 192.168.1.1         # UDR gateway — DNS/DHCP only
ping -c3 192.168.1.55        # Pi — DNS only, ICMP may be blocked
ping -c3 192.168.1.60        # Opti/Proxmox — should be BLOCKED (Proxmox rule disabled)
ping -c3 192.168.10.1        # IoT gateway — should be BLOCKED
ping -c3 192.168.1.100       # arbitrary Default LAN host — should be BLOCKED

# Verify Server zone active rules via MCP audit (Phase 0):
# unifi_get_firewall_policy_details for all Server-zone policy IDs
```

Expected active Server zone policies: `allow-server-to-internet`, `allow-server-dns-to-pi`, `block-server-to-default`, `block-server-to-iot`, `block-server-to-gateway-dns`.

---

## 6. Live firewall policy count check

Quick count to catch unexpected rule additions/deletions:

```bash
ssh udr 'mongo --port 27117 ace --quiet --eval "
print(\"Total firewall policies: \" + db.firewallgroup.count());
print(\"Enabled policies: \" + db.firewallgroup.count({enabled: true}));
"'
```

Or via UniFi MCP: `unifi_list_firewall_policies` — compare count and names against `inventory/unifi-firewall.md`.

---

## Reference

- Firewall inventory: [`inventory/unifi-firewall.md`](../inventory/unifi-firewall.md)
- Network inventory: [`inventory/unifi-networks.md`](../inventory/unifi-networks.md)
- VLAN map: [`inventory/vlans.md`](../inventory/vlans.md)
- UDR baseline: [`docs/udr7-baseline.md`](../docs/udr7-baseline.md)
