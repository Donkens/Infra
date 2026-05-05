# Uptime Kuma Monitor Audit — 2026-05-05

Phase: `Phase 0 read-only`

Status: WARN

Update 2026-05-05, `GO KUMA ADGUARD CLEANUP`: AdGuard monitor cleanup applied.
- ID `5` renamed to `AdGuard DNS resolves proxy.home.lan`; type `dns`; UP.
- ID `6` renamed to `AdGuard UI`; converted from `port` to `http`;
  URL `https://adguard.home.lan/login.html`; `ignore_tls=1`; UP `200 - OK`.
- ID `11` renamed to `AdGuard TCP 443 (paused duplicate)` and paused.
Overall audit status remains WARN because the Proxmox monitor is still absent.

Update 2026-05-05, `GO KUMA HAOS CLEANUP`: HAOS duplicate cleanup applied.
Monitor ID `9` was renamed to `HAOS TCP 8123 (paused duplicate)` and paused.
Monitor ID `10` remains the canonical HAOS HTTP monitor and is UP. Overall
audit status remained WARN because Proxmox and AdGuard cleanup items were open.

Scope:
- Uptime Kuma runtime in Docker VM `102` (`docker`, `192.168.30.10`).
- Kuma URL: `https://kuma.home.lan`.
- Audit source: live Uptime Kuma monitor state, sanitized. No PEM, keys,
  cookies, tokens, passwords, or DB secrets printed.

No changes were made to Uptime Kuma monitors, Caddy, Compose, Docker, UniFi,
DNS, Proxmox, HAOS, containers, or the Kuma DB.

## Executive summary

Kuma is operationally green: all active current monitors are UP. The Docker/Caddy
HTTPS monitors for `proxy`, `kuma`, `dockge`, and `dozzle` match the expected
`tls internal` trust pattern with per-monitor Caddy CA, `auth_method=mtls`,
`ignore_tls=0`, and empty client cert/key fields.

The audit remains WARN because the monitor set still has baseline drift:
- Proxmox monitor is absent, not paused.
- `Docker VM` uses `docker.home.lan` rather than raw IP `192.168.30.10`.
- `Dockge` and `Docker VM` use `maxretries=1` while most others use `0`.

Resolved during AdGuard cleanup 2026-05-05:
- ID `5` renamed `AdGuard DNS resolves proxy.home.lan`; semantics now clear.
- ID `6` converted to `http` monitor `AdGuard UI`; UP `200 - OK`.
- ID `11` paused as `AdGuard TCP 443 (paused duplicate)`.

Resolved during HAOS cleanup:
- ID `9` is now paused and explicitly named `HAOS TCP 8123 (paused duplicate)`.
- ID `10` remains canonical: `HAOS`, HTTP, `http://ha.home.lan:8123/`, UP.

## Monitor inventory

| ID | Name | Type | Target / URL | Method | Interval | Retry interval | Timeout | Max retries | Accepted status | Status | TLS summary | Verdict |
|---:|---|---|---|---|---:|---:|---:|---:|---|---|---|---|
| 1 | Caddy proxy | `http` | `https://proxy.home.lan` | `GET` | 60 | 60 | 48 | 0 | `200-299` | UP: `200 - OK` | `ignore_tls=0`, `auth_method=mtls`, `tls_ca=<CA_PRESENT>`, `tls_cert=<EMPTY>`, `tls_key=<EMPTY>` | PASS |
| 2 | Uptime Kuma | `http` | `https://kuma.home.lan` | `GET` | 60 | 60 | 48 | 0 | `200-299` | UP: `200 - OK` | `ignore_tls=0`, `auth_method=mtls`, `tls_ca=<CA_PRESENT>`, `tls_cert=<EMPTY>`, `tls_key=<EMPTY>` | PASS |
| 5 | AdGuard DNS resolves proxy.home.lan | `dns` | query `proxy.home.lan` via `192.168.1.55`; latest result `Records: 192.168.30.10` | `GET` | 60 | 60 | 48 | 0 | `200-299` | UP | no TLS material | PASS |
| 6 | AdGuard UI | `http` | `https://adguard.home.lan/login.html` | `GET` | 60 | 60 | 48 | 0 | `200-299` | UP: `200 - OK` | `ignore_tls=1` | PASS |
| 7 | Docker VM | `ping` | `docker.home.lan` | `GET` | 60 | 60 | 48 | 1 | `200-299` | UP | no TLS material | PASS/WARN |
| 9 | HAOS TCP 8123 (paused duplicate) | `port` | `ha.home.lan:8123` | `GET` | 60 | 60 | 48 | 0 | `200-299` | PAUSED; latest heartbeat was UP | no TLS material | PASS |
| 10 | HAOS | `http` | `http://ha.home.lan:8123/` | `GET` | 60 | 60 | 48 | 0 | `200-299` | UP: `200 - OK` | no TLS material | PASS |
| 11 | AdGuard TCP 443 (paused duplicate) | `port` | `Adguard.home.lan:443` | `GET` | 60 | 60 | 48 | 0 | `200-299` | PAUSED | no TLS material | PASS |
| 13 | Dockge | `http` | `https://dockge.home.lan` | `GET` | 60 | 60 | 48 | 1 | `200-299` | UP: `200 - OK` | `ignore_tls=0`, `auth_method=mtls`, `tls_ca=<CA_PRESENT>`, `tls_cert=<EMPTY>`, `tls_key=<EMPTY>` | PASS |
| 14 | Dozzle | `http` | `https://dozzle.home.lan` | `GET` | 60 | 60 | 48 | 0 | `200-299` | UP: `200 - OK` | `ignore_tls=0`, `auth_method=mtls`, `tls_ca=<CA_PRESENT>`, `tls_cert=<EMPTY>`, `tls_key=<EMPTY>` | PASS |

## PASS items

- Docker/Caddy HTTPS monitors use per-monitor Caddy CA:
  `Caddy proxy`, `Uptime Kuma`, `Dockge`, and `Dozzle`.
- Docker/Caddy HTTPS monitors have `auth_method=mtls`, `tls_ca=<CA_PRESENT>`,
  `tls_cert=<EMPTY>`, `tls_key=<EMPTY>`, and `ignore_tls=0`.
- Dozzle monitor ID `14` uses `GET` and is UP with `200 - OK`.
- All active current monitors are UP.
- HAOS duplicate port monitor ID `9` is paused and clearly named.
- AdGuard monitors ID `5`, `6`, `11` cleaned up 2026-05-05.

## WARN findings

### HAOS duplicate — resolved 2026-05-05

HAOS still exists as two records, but no longer as two active monitors:
- ID `9`: `port` monitor for `ha.home.lan:8123`, renamed
  `HAOS TCP 8123 (paused duplicate)` and paused.
- ID `10`: `http` monitor for `http://ha.home.lan:8123/`, active and UP.

ID `10` is the canonical HAOS monitor.

### Proxmox monitor absent

Baseline expected a Proxmox monitor to exist in paused state while Docker VM to
Proxmox firewall scope remains blocked. Live Kuma state has no Proxmox monitor.

### AdGuard monitors — resolved 2026-05-05

- ID `5` renamed `AdGuard DNS resolves proxy.home.lan`; semantics now explicit.
- ID `6` converted from `port` to `http`; renamed `AdGuard UI`;
  URL `https://adguard.home.lan/login.html`; `ignore_tls=1`; UP `200 - OK`.
- ID `11` renamed `AdGuard TCP 443 (paused duplicate)` and paused.

### Docker VM target form

ID `7` `Docker VM` uses `docker.home.lan` rather than raw IP `192.168.30.10`.
This is acceptable if the monitor is intentionally DNS-dependent. If the
baseline intent is direct host reachability independent of DNS, change the
target to the raw IP in a later approved fix phase.

### Retry consistency

ID `7` `Docker VM` and ID `13` `Dockge` use `maxretries=1`. Most other current
monitors use `maxretries=0`. This is not currently harmful, but the policy
should be documented or normalized.

## Recommended future fix plan

Do not apply these changes without a separate approval gate.

1. HAOS cleanup:
   - Done 2026-05-05 under `GO KUMA HAOS CLEANUP`.
   - Keep ID `10` as the canonical HAOS HTTP monitor.
   - Keep ID `9` paused unless a separate TCP port check is intentionally
     desired later.

2. Proxmox paused monitor:
   - Add a paused Proxmox monitor for `https://proxmox.home.lan:8006`, or
     update baseline to say Proxmox monitoring is absent until firewall scope is
     resolved.

3. AdGuard cleanup:
   - Done 2026-05-05 under `GO KUMA ADGUARD CLEANUP`.
   - ID `5` renamed; ID `6` converted to HTTP and UP; ID `11` paused.

4. Docker VM target policy:
   - Either document `docker.home.lan` as intentional or change ID `7` to
     `192.168.30.10`.

5. Retry policy:
   - Decide whether `maxretries=0` or `maxretries=1` is preferred for the
     baseline and update monitor settings/docs consistently.

## Approval gates

- `GO KUMA FIX MONITORS`
- `GO KUMA ADD PROXMOX PAUSED`
- `GO KUMA ADGUARD CLEANUP`
