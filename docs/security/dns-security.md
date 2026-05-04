# DNS Security Baseline

Status: baseline
Scope: Raspberry Pi DNS node, AdGuard Home, Unbound, UDR-7 DNS posture, LAN/IoT/Server VLAN clients, DNSecure/DoT clients, and DNS bypass prevention.

## Summary

DNS for the home infrastructure should be centralized, observable, and resistant to accidental bypass. The Raspberry Pi DNS node is the primary DNS service point. AdGuard Home is the LAN-facing DNS frontend, and Unbound is the local recursive resolver behind it.

Default posture:

- clients use Pi/AdGuard for DNS
- AdGuard forwards recursion to local Unbound
- Unbound listens only on loopback for recursion
- UDR DNS service should not become a bypass path for protected clients
- raw AdGuard runtime config stays out of Git
- sanitized exports and DNS inventories may be tracked

## Architecture

| Layer | Component | Role |
|---|---|---|
| Client DNS | LAN/IoT/Server VLAN clients | Use configured DNS path rather than arbitrary external DNS. |
| Frontend DNS | AdGuard Home on Pi | Filtering, rewrites, client visibility, DoT/DoH where configured. |
| Recursive resolver | Unbound on Pi | Local recursive resolver behind AdGuard. |
| Gateway | UDR-7 | Routing/firewall/DHCP; should not be a DNS bypass for protected clients. |
| Repo | Infra | Stores sanitized docs, inventories, scripts, and runbooks. |

## Known service model

| Service | Expected posture |
|---|---|
| AdGuard Home | Listens on LAN-facing DNS ports and provides filtering/rewrites. |
| Unbound | Listens on local resolver port, normally loopback-only. |
| UDR dnsmasq | May exist for gateway features, but should not be the preferred client DNS bypass path. |
| DNS-over-TLS / DNSecure | Allowed where explicitly configured to the home DNS service. |
| External DNS | Only approved upstream flows should be allowed. |

## Source-of-truth and Git posture

| Item | Source of truth | Git posture |
|---|---|---|
| AdGuard live runtime | Pi `/home/pi/AdGuardHome` | Raw config stays off Git. Sanitized exports may be tracked. |
| AdGuard DNS rewrites | Pi runtime / sanitized export | Track sanitized inventory when useful. |
| Unbound runtime | Pi `/etc/unbound` | Track safe local-data/PTR docs and sanitized config references. |
| DNS health state | Pi systemd timers/logs/state | Track scripts/docs; runtime logs/state usually stay runtime. |
| UDR DNS/firewall | UniFi/UDR runtime | Track documented intent and validation snapshots, not raw secrets. |
| Off-Pi backups | Mac mini sparsebundle / documented backup path | Track runbooks and restore drills, not raw backup archives. |

## Security objectives

1. All managed clients should use the intended DNS path.
2. DNS bypass to WAN resolvers should be blocked or explicitly documented.
3. DNS bypass to the gateway DNS service should be blocked where policy requires Pi/AdGuard.
4. Resolver health must be observable through timers/logs.
5. Raw DNS configs containing credentials or sensitive values must not enter Git.
6. DNS changes should be reversible and validated with queries.

## Bypass prevention

Recommended policy:

| Flow | Policy |
|---|---|
| Client VLAN -> Pi DNS | Allow. |
| Pi DNS -> upstream recursion/Internet | Allow as required. |
| Client VLAN -> WAN TCP/UDP 53 | Block unless explicitly approved. |
| Client VLAN -> UDR/gateway TCP/UDP 53 | Block where Pi/AdGuard is mandatory. |
| Server VLAN -> Pi DNS | Allow where services need DNS. |
| Server VLAN -> WAN TCP/UDP 53 | Block unless explicitly approved. |
| IoT -> Pi/AdGuard DNS | Allow. |
| IoT -> arbitrary DNS | Block or isolate according to IoT policy. |

DNS-over-HTTPS is harder to block generically because it rides over HTTPS. Handle it by client policy, app settings, and selective firewall/application control where practical.

## UDR-7 DNS posture

UDR-7 may expose dnsmasq/gateway DNS on internal interfaces. This is normal for many routers, but it can become a bypass path if clients are supposed to use Pi/AdGuard.

Policy:

- UDR may keep its gateway DNS function if required by UniFi/gateway behavior.
- Protected client networks should not use UDR DNS as their normal resolver.
- Firewall rules should prevent default/Server VLAN clients from bypassing Pi/AdGuard via gateway DNS where that is the active policy.
- Any exception must be documented with source, destination, protocol, port, and reason.

## AdGuard Home policy

Allowed in Git:

- sanitized config summaries
- DNS rewrite inventories
- client/group intent
- filter list names without secrets
- safe verification output

Not allowed in Git:

- raw `AdGuardHome.yaml`
- passwords/hashes/API tokens
- raw query logs if they include sensitive browsing/device activity
- raw backup archives

Operational notes:

- DDR/discovery behavior should be documented when changed.
- DNS rewrites should be tracked in inventory docs when they define infrastructure names.
- UI exposure must stay LAN/VLAN-scoped, not WAN-exposed.

## Unbound policy

Unbound should remain the resolver backend. It should not be unnecessarily exposed to client networks unless intentionally designed.

Recommended posture:

| Area | Policy |
|---|---|
| Listener | Loopback/local backend where practical. |
| AdGuard -> Unbound | Allow local recursion path. |
| Clients -> Unbound direct | Not required by default. |
| PTR/local records | Track documented local-data/PTR entries. |
| Root key/hints | Do not manually edit without runbook/reason. |

## DNS-over-TLS / DNSecure

DNSecure and DoT/DoH clients can be useful for secure remote/mobile DNS, but they must be documented.

Policy:

- Document which clients use DoT/DoH to home DNS.
- Do not expose DoT/DoH to WAN unless intentionally designed and firewalled.
- Certificates and private keys must not be committed.
- If DoT is used internally, validate both name resolution and certificate behavior.

## Validation commands

Run from an admin client:

```bash
dig @192.168.1.55 pi.home.lan A +short
dig @192.168.1.55 udr.home.lan A +short
dig @192.168.1.55 github.com A +short
```

Run on Pi:

```bash
systemctl is-active AdGuardHome unbound
ss -lntup | grep -E '(:53|:853|:443|:3000|:5335)' || true
dig @127.0.0.1 -p 5335 github.com A +short
dig @127.0.0.1 github.com A +short
```

Use `+short` for docs-friendly output and avoid dumping raw query logs.

## Health monitoring

Expected DNS health checks:

| Check | Purpose |
|---|---|
| AdGuard service active | DNS frontend available. |
| Unbound service active | Recursive backend available. |
| Query to port 53 | Client-facing DNS works. |
| Query to Unbound backend | Backend resolver works. |
| Backup health | DNS backup chain remains restorable. |
| Off-Pi backup health | DNS backup survives Pi failure. |

Health timers/scripts should remain documented and should avoid printing secrets.

## Change management

DNS changes should follow this pattern:

1. Phase 0: read-only inventory and current behavior.
2. Phase 1: plan change and rollback.
3. Phase 2: apply minimal change.
4. Verify service health.
5. Verify representative queries.
6. Update docs/inventory.
7. Sync repos across admin hosts.

## Safe DNS change checklist

- [ ] Backup or export current runtime state if needed.
- [ ] No raw secrets printed.
- [ ] AdGuard remains active.
- [ ] Unbound remains active.
- [ ] Client-facing DNS answers.
- [ ] Backend resolver answers.
- [ ] Firewall intent remains documented.
- [ ] Repo docs updated with sanitized output only.

## Incident response

If DNS breaks:

1. Check AdGuard and Unbound service state.
2. Check whether Pi answers on client-facing DNS.
3. Check whether Unbound answers on backend resolver port.
4. Check recent firewall changes on UDR.
5. Temporarily use a documented fallback only if needed.
6. Revert the smallest recent change first.
7. Record the incident with sanitized details.

## Related docs

- [`secrets-policy.md`](secrets-policy.md)
- [`ssh-hardening.md`](ssh-hardening.md)
- [`auth-baseline.md`](auth-baseline.md)
