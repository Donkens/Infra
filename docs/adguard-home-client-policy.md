# AdGuard Home client policy

> Status: **PLANNED** — not applied to live AdGuard configuration.
> No client group changes have been applied yet.
> This document defines a proposed client grouping strategy for future consideration.

## Purpose

Define a per-client-group filtering strategy for AdGuard Home on Pi. The goal is to reduce false-positive risk for IoT and Apple devices while maintaining appropriate filtering for default LAN clients.

## Current state

- All 11 persistent clients are in the default group.
- No custom client groups exist in the live configuration.
- Filtering applies uniformly to all clients.
- Runtime client sources: 5 (ARP-discovery active).

When client groups are applied, changes must follow [adguard-home-change-policy.md](adguard-home-change-policy.md) and require an explicit `GO` from the operator.

---

## Proposed groups

### Default LAN

Intended clients: general wired and WiFi devices on VLAN 1 (`192.168.1.0/24`) not assigned to another group.

Examples: Mac mini (`192.168.1.86`), Mac mini WiFi (`192.168.1.84`), MacBook Pro (`192.168.1.78`).

| Setting | Value |
|---|---|
| Filtering level | Standard — current blocklists |
| Safe Search | Off |
| Parental control | Off |
| User rules | Shared global allow-rules |

False-positive risks:
- Homebrew update domains (`formulae.brew.sh`, `raw.githubusercontent.com`)
- npm package registry (`registry.npmjs.org`)
- GitHub Actions and API endpoints
- OpenAI, Claude, Anthropic API endpoints

Validation checklist:
- [ ] `brew update` completes without DNS errors
- [ ] `npm install` resolves registry
- [ ] GitHub web and API reachable
- [ ] `dig @192.168.1.55 formulae.brew.sh A +short` returns IP

Rollback: return affected clients to default group in AdGuard UI; no YAML change required.

---

### IoT/MLO

Intended clients: IoT devices and MLO-connected phones on VLAN 40 (`192.168.40.0/24`) and IoT sub-clients on VLAN 1.

Examples: iPhone (`192.168.40.207`), WiZ smart bulbs, Roborock vacuum, Nest/Google Home, Tibber.

| Setting | Value |
|---|---|
| Filtering level | Reduced — retain malware/phishing blocks only; remove aggressive ad/tracker lists |
| Safe Search | Off |
| Parental control | Off |
| User rules | Additional allows for manufacturer cloud domains |

False-positive risks:
- Apple Private Relay and iCloud CDN (`mask.icloud.com`, `apple-relay.cloudflare.com`)
- Apple `HTTPS`/SVCB (type 65) queries — aggressive on iOS; avoid blocking Apple CDN HTTPS records
- WiZ cloud control (`scheduler.wiz.to`, `fd.wizlighting.com`)
- Roborock cloud sync (`*.roborock.com`, `*.io.mi.com`)
- Nest/Google Home management (`home.google.com`, `*.googleapis.com`)
- Tibber pricing API (`api.tibber.com`)
- UniFi local controller calls from managed devices

Validation checklist:
- [ ] iPhone Safari loads pages without DNS errors
- [ ] iCloud sync functional (no blocks for `*.icloud.com` in AdGuard stats)
- [ ] WiZ bulbs respond to app control
- [ ] Roborock app syncs map data
- [ ] `dig @192.168.1.55 mask.icloud.com A +short` returns IP
- [ ] `dig @192.168.1.55 scheduler.wiz.to A +short` returns IP

Rollback: return client to default group in AdGuard UI.

---

### Dev/Admin

Intended clients: Mac mini and MacBook Pro when acting as primary dev/admin stations.

Alternative: keep as Default LAN and use global user rules for dev-specific allows. Prefer this simpler path until a concrete false-positive is confirmed.

| Setting | Value |
|---|---|
| Filtering level | Standard or stricter with explicit allows for dev/cloud domains |
| Safe Search | Off |
| Parental control | Off |
| User rules | Allowlist for npm, GitHub, Homebrew, OpenAI, Claude, Anthropic |

False-positive risks:
- Claude and Anthropic API (`claude.ai`, `api.anthropic.com`)
- OpenAI API (`api.openai.com`)
- GitHub raw content and LFS (`raw.githubusercontent.com`, `*.github.com`)
- npm (`registry.npmjs.org`)
- Homebrew (`formulae.brew.sh`, `ghcr.io`)

Validation checklist:
- [ ] `curl -s https://api.anthropic.com` returns non-DNS error (not NXDOMAIN)
- [ ] `npm install` resolves registry
- [ ] GitHub API and web reachable

Rollback: return client to default group in AdGuard UI.

---

## Implementation order

When ready to apply (requires explicit approval and operator `GO`):

1. Create group in AdGuard UI (Settings → Filters → Client Groups, or Clients → Groups)
2. Assign clients to group (Clients → edit client → assign group)
3. Set group-specific filter settings
4. Validate checklist for each group before moving to the next
5. Monitor AdGuard statistics for unexpected blocks for at least 24 hours
6. Document applied state in `docs/raspberry-pi-baseline.md`

Apply one group at a time. Validate before proceeding to the next.

---

## Related docs

- [AdGuard change policy](adguard-home-change-policy.md)
- [AdGuard false-positive allowlist](adguard-home-false-positive-allowlist.md)
- [AdGuard optimization audit runbook](../runbooks/adguard-optimization-audit.md)
- [DNS architecture](dns-architecture.md)
- [Raspberry Pi baseline](raspberry-pi-baseline.md)
