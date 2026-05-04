# Firewall Baseline

Status: baseline
Scope: UDR-7 firewall intent, LAN/IoT/Server VLAN segmentation, DNS bypass prevention, trusted admin paths, and change-management rules.

## Summary

Firewall policy should be explicit, minimal, documented, and validated after every change. The UDR-7 is the enforcement point for VLAN routing and Internet egress. The Raspberry Pi DNS node provides central DNS, and admin clients should have only the access they need.

Default posture:

- allow required admin paths from trusted clients
- allow required DNS paths to Pi/AdGuard
- block DNS bypass where policy requires central DNS
- isolate IoT and Server VLAN traffic by default
- avoid broad any-any rules
- document every exception with source, destination, protocol, port, and reason

## Network role model

| Network / host | Role | Firewall posture |
|---|---|---|
| Default LAN | Trusted home/admin network | Can administer infra where explicitly allowed. |
| IoT VLAN | Device network | Limited access; should not freely initiate into trusted/admin networks. |
| Server VLAN | VM/service network | Services exposed intentionally; default inter-VLAN access should be narrow. |
| MLO/iPhone VLAN | Client network for iPhone/MLO | Allow required client/home control paths only. |
| Pi DNS node | DNS and infra service | Allow DNS from intended clients; allow required upstream traffic. |
| UDR-7 | Gateway/router | Admin target only from trusted admin paths. |
| Opti/Proxmox | Compute host | Admin target from trusted clients; avoid broad lateral access. |
| HAOS | Home automation | Allow required integrations only; avoid broad host access. |
| Docker VM | App/service host | Expose only documented services. |

## Firewall principles

1. Prefer allow-by-need over broad allow rules.
2. Keep deny/block rules documented and ordered intentionally.
3. Protect management planes: UDR, Proxmox, HAOS, Pi, and Docker admin ports.
4. Centralize DNS through Pi/AdGuard where possible.
5. Avoid WAN port forwards unless explicitly approved and documented.
6. Validate rules with both positive and negative tests.
7. Keep raw exports/secrets out of Git; document sanitized intent and results.

## Trusted admin paths

Trusted admin clients may include Mac mini and MacBook Pro.

| Source | Destination | Policy |
|---|---|---|
| Mac mini | Pi / UDR / Opti / HAOS / Docker VM | Allowed when needed for admin. |
| MacBook Pro | Pi / UDR / Opti / HAOS / Docker VM | Allowed when needed for admin. |
| Pi | GitHub | Allowed for repo sync. |
| Pi | Mac/UDR/Opti/HAOS/Docker | Not required by default. |
| UDR | Other hosts | Not required by default. |
| HAOS | Other hosts | Not required by default except specific integrations. |
| Docker VM | Other hosts | Not required by default except explicit app dependencies. |

## DNS firewall policy

| Flow | Policy |
|---|---|
| Clients -> Pi DNS TCP/UDP 53 | Allow where clients should use central DNS. |
| Pi -> upstream DNS/Internet | Allow as required for resolver function. |
| Clients -> WAN TCP/UDP 53 | Block unless explicitly approved. |
| Clients -> UDR/gateway TCP/UDP 53 | Block where Pi/AdGuard is mandatory. |
| Server VLAN -> WAN DNS | Block unless explicit service exception exists. |
| IoT -> arbitrary DNS | Block or constrain according to IoT policy. |

DNS-over-HTTPS should be handled separately through client settings, app policy, or selective controls where practical.

## Management-plane protection

Sensitive admin services:

| Service | Host | Desired exposure |
|---|---|---|
| UniFi / UDR admin | UDR-7 | Trusted admin clients only. |
| SSH | Pi/UDR/Opti/HAOS/Docker | Trusted admin clients only. |
| Proxmox UI | Opti | Trusted admin clients only. |
| HAOS UI / SSH add-on | HAOS | Trusted home/admin clients only. |
| AdGuard UI | Pi | Trusted/admin network only; never WAN. |
| Cockpit, if enabled | Pi | Trusted/admin network only; review whether needed. |

## IoT policy

IoT devices should be treated as semi-trusted.

Recommended policy:

- allow IoT to Internet as needed
- allow IoT DNS to Pi/AdGuard
- allow specific controller paths, such as iPhone/app control to known IoT devices
- block broad IoT -> trusted LAN access
- document exceptions by device/integration

## Server VLAN policy

Server VLAN hosts should not automatically gain full LAN access.

Recommended policy:

- allow admin clients -> Server VLAN admin ports
- allow Server VLAN -> Internet only as needed
- allow Server VLAN -> Pi DNS
- block Server VLAN -> internal networks by default unless specific service dependency exists
- expose services through documented reverse proxy or LAN-only endpoints

## WAN exposure policy

Default: no WAN port forwards.

Any WAN exposure requires:

- explicit service name and owner
- source/destination/port/protocol
- TLS/auth plan
- update plan
- backup/restore plan where applicable
- rollback plan

Prefer Tailscale/VPN/private access over WAN port forwards.

## Rule documentation template

Use this shape for firewall changes:

| Field | Value |
|---|---|
| Rule name |  |
| Source |  |
| Destination |  |
| Protocol/port |  |
| Action | allow/block/reject |
| Direction / zone |  |
| Reason |  |
| Verification |  |
| Rollback |  |
| Last verified |  |

## Change management

Firewall changes should follow the same phase model as other infra work:

1. Phase 0: read-only inventory.
2. Phase 1: planned change with rollback.
3. Phase 2: apply minimal change.
4. Verify positive path still works.
5. Verify blocked path is blocked.
6. Confirm no unexpected broad access.
7. Update docs/inventory.
8. Sync repos across admin hosts.

## Validation examples

Use safe, targeted tests. Avoid noisy scans unless required.

DNS positive test:

```bash
dig @192.168.1.55 github.com A +short
```

SSH positive test:

```bash
ssh -o BatchMode=yes -o NumberOfPasswordPrompts=0 -o ConnectTimeout=5 pi 'hostname; whoami'
```

Negative tests should be documented per rule and should not rely on destructive commands.

## Safe checklist before firewall writes

- [ ] Current rules exported or inspected.
- [ ] Target rule is narrowly scoped.
- [ ] Rollback is clear.
- [ ] Management access will not be locked out.
- [ ] DNS path remains functional.
- [ ] Rule order/index is understood.
- [ ] Positive and negative validation commands are ready.
- [ ] Docs will be updated after verification.

## Incident response

If connectivity breaks after a firewall change:

1. Stop making further changes.
2. Use the existing admin session if still active.
3. Revert the most recent firewall rule first.
4. Verify UDR/management access.
5. Verify DNS resolution.
6. Verify default gateway and VLAN routing.
7. Document the incident with sanitized details.

## Related docs

- [`dns-security.md`](dns-security.md)
- [`ssh-hardening.md`](ssh-hardening.md)
- [`secrets-policy.md`](secrets-policy.md)
- [`auth-baseline.md`](auth-baseline.md)
