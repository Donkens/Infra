# AdGuard Home false-positive allowlist

> Status: **CANDIDATES** — not a live allowlist.
> Every entry here is a candidate to validate before adding to AdGuard.
> Do not add domains wholesale. Validate each entry before allowing.

## Purpose

Document known-safe domain categories at risk of false-positive blocking by common DNS filter lists. Use this as a reference when investigating reports of broken services, not as an auto-import list.

## Validation method

For any suspected false positive:

1. **Reproduce** — confirm the client reports a DNS failure, not a connection or TLS error
2. **Check AdGuard UI** — Query log → filter by domain → confirm block source (which filter list)
3. **Add temporary allow rule** — AdGuard UI → Filters → User rules → `@@||example.domain^`
4. **Test** — confirm service works after adding the temporary rule
5. **Document** — if keeping, note the domain, the blocking list, and the reason

Avoid broad wildcard allows (`@@||*.example.com^`) unless the exact subdomain is unknown and every subdomain under the parent is safe. Prefer exact-domain allows.

---

## Candidate categories

### Apple / iCloud / Private Relay / CDN

Apple devices send aggressive `HTTPS`/SVCB (type 65) queries. Broad blocking of Apple CDN domains can break iCloud sync, Continuity, AirDrop, Push Notifications, and Private Relay. iOS clients generate substantial HTTPS-record traffic; avoid blocking these query types for Apple domains.

| Domain pattern | Purpose |
|---|---|
| `mask.icloud.com` | Private Relay ingress |
| `apple-relay.cloudflare.com` | Private Relay egress via Cloudflare |
| `apple-relay.fastly.net` | Private Relay egress via Fastly |
| `bag.itunes.apple.com` | iTunes/App Store update metadata |
| `mesu.apple.com` | macOS/iOS software update catalog |
| `*.icloud.com` | iCloud services (validate per subdomain before wildcarding) |
| `*.cdn-apple.com` | Apple CDN assets |

Note: HTTPS records for Apple CDN are safe to pass through. Blocking type-65 HTTPS records forces fallback to A/AAAA with extra latency and can cause feature degradation.

---

### WiZ

WiZ smart bulbs require cloud access for scheduling, firmware updates, and some app control features.

| Domain pattern | Purpose |
|---|---|
| `scheduler.wiz.to` | WiZ cloud scheduling |
| `fd.wizlighting.com` | WiZ firmware distribution |
| `api.wizlighting.com` | WiZ device API |
| `registration.wizconnected.com` | WiZ device registration |

---

### Roborock

Roborock vacuums sync maps and schedules via cloud.

| Domain pattern | Purpose |
|---|---|
| `*.roborock.com` | Roborock cloud sync, map storage, firmware |
| `*.io.mi.com` | Xiaomi/Roborock IoT backend |
| `*.api.io.mi.com` | Xiaomi device API |

Note: `*.io.mi.com` is shared Xiaomi infrastructure. Validate carefully if other Xiaomi devices are present.

---

### Nest / Google Home

| Domain pattern | Purpose |
|---|---|
| `home.google.com` | Google Home app backend |
| `googlehomefoyer-pa.googleapis.com` | Google Home device state |
| `googlehomegraph-pa.googleapis.com` | Google Home device graph |
| `smartdevicemanagement.googleapis.com` | Nest SDM API |
| `*.googleapis.com` | Google APIs general (validate per subdomain) |

---

### Tibber

| Domain pattern | Purpose |
|---|---|
| `api.tibber.com` | Tibber energy pricing and consumption API |
| `app.tibber.com` | Tibber app backend |
| `*.tibber.com` | Tibber general (validate per subdomain) |

---

### GitHub / Homebrew / npm

Critical for dev workflows. Blocking these breaks package management, script downloads, and CI.

| Domain pattern | Purpose |
|---|---|
| `github.com` | Git hosting |
| `api.github.com` | GitHub REST API |
| `raw.githubusercontent.com` | Raw file content (includes Homebrew bottle downloads) |
| `objects.githubusercontent.com` | GitHub LFS and release assets |
| `ghcr.io` | GitHub Container Registry |
| `formulae.brew.sh` | Homebrew formula browser |
| `registry.npmjs.org` | npm package registry |
| `*.npmjs.com` | npm general |

---

### OpenAI / Claude / Anthropic

| Domain pattern | Purpose |
|---|---|
| `api.openai.com` | OpenAI API |
| `*.openai.com` | OpenAI general |
| `claude.ai` | Claude web UI |
| `api.anthropic.com` | Anthropic API |
| `*.anthropic.com` | Anthropic general |

---

### UniFi / Ubiquiti

UniFi devices reach controller and cloud for updates, remote access, and telemetry.

| Domain pattern | Purpose |
|---|---|
| `unifi.ui.com` | UniFi remote access and cloud portal |
| `firmware-update.ubnt.com` | Firmware update distribution |
| `ping.ubnt.com` | Ubiquiti connectivity check |
| `*.ui.com` | UniFi cloud and account services (validate per subdomain) |
| `*.ubnt.com` | Ubiquiti legacy cloud (validate per subdomain) |

---

## What not to do

- Do not paste raw query log output into this document.
- Do not add domains observed only once without confirming a real block.
- Do not use `@@||*^` or similarly broad wildcards.
- Do not copy entire filter list exception blocks without validating each entry.
- Do not commit real IP addresses or MAC addresses here.
- Do not treat this list as a complete allowlist — it is a starting point for investigation.

---

## Related docs

- [AdGuard change policy](adguard-home-change-policy.md)
- [AdGuard client policy](adguard-home-client-policy.md)
- [AdGuard optimization audit runbook](../runbooks/adguard-optimization-audit.md)
- [DNS architecture](dns-architecture.md)
