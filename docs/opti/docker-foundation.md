# Docker Foundation — Opti VM 102

## Status

**Phase 1C-C1.5 — 2026-05-04** — Caddy + Uptime Kuma nåbara från LAN. DNS-rewrites
för `kuma`, `dockge`, `dozzle` lagda i AdGuard. UniFi firewall-regel
`allow-lan-admin-to-docker-http` (TCP 80, Internal → Docker VM) live. Dockge
compose-fil finns men containern är inte startad. Dozzle körs via Caddy.

**Uptime Kuma monitor audit — 2026-05-05** — Live-state är WARN men grönt:
alla aktiva monitors är UP. Docker/Caddy HTTPS monitors (`proxy`, `kuma`, `dockge`,
`dozzle`) använder per-monitor Caddy CA med `auth_method=mtls`, `ignore_tls=0`,
och tomma client cert/key-fält. HAOS-duplikatet städat: ID `9` pausad, ID `10`
canonical HTTP-monitor. AdGuard-cleanup 2026-05-05: ID `5` omdöpt till `AdGuard
DNS resolves proxy.home.lan`; ID `6` konverterad till HTTP `AdGuard UI`
(`https://adguard.home.lan/login.html`, `ignore_tls=1`, UP `200 - OK`); ID `11`
pausad som `AdGuard TCP 443 (paused duplicate)`. Proxmox-monitor tillagd 2026-05-05 (`GO KUMA ADD PROXMOX PAUSED`): ID `15`,
`http`, `https://proxmox.home.lan:8006`, `GET`, `ignore_tls=1`, `active=0`
(pausad tills Docker VM → Proxmox firewall-scope är löst). Baseline PASS med godkända noter (`GO KUMA DOCS POLICY ONLY` 2026-05-05):
`Docker VM` använder `docker.home.lan` avsiktligt (verifierar DNS-path + host);
`maxretries=1` på `Docker VM` och `Dockge` är accepterad policy.
Se `docs/opti/uptime-kuma-monitor-audit-2026-05-05.md`.

**Phase 1C-C2a — 2026-05-04** — Dozzle live med simple auth (`users.yml` bcrypt,
`DOZZLE_AUTH_PROVIDER=simple`). Docker socket read-only. Ingen host port. Via Caddy.
Dockge ej startad. Validerad (C2a docs) 2026-05-04.

**Phase 1C-C2b — 2026-05-04** — Dockge live. `louislam/dockge:1.4.2` startad via
`docker compose up -d` i `/srv/compose/dockge/`. Lösenord satt vid first-run.
`dockge.home.lan` svarar `200 OK` via Caddy. Docker socket RW (nödvändigt).
Alla befintliga stackar synliga i Dockge UI. Post-C2b backup verifierad.

**Docker backup baseline — 2026-05-04** — Backup-script `scripts/maintenance/docker-vm-backup.sh`
skapat och installerat på Docker VM (`/usr/local/sbin/docker-vm-backup`). Första backup
(`docker-vm-102-backup-20260504-201659.tar.gz`, 296K, 45 entries) körd och verifierad.
Off-host kopia på Mac mini (`/Users/yasse/InfraBackups/docker-vm-102/`). SHA256 matchar
på båda hosts. Restore-test PASS. Se `docs/opti/60-backup-restore.md`.

**Phase 1C-C3b — 2026-05-05** — Caddy `tls internal` live for
`proxy.home.lan`, `kuma.home.lan`, `dozzle.home.lan`, and `dockge.home.lan`.
Existing HTTP routes preserved. `auto_https disable_redirects` is required:
`auto_https off` disables certificate automation and caused TLS handshake failure
during the first attempt. Mac mini and MBP both trust the Caddy root CA for
system `curl` validation as of Phase 1C-C3c.

## Architecture

```
LAN client (*.home.lan)
        │
        ▼
 Caddy :80/:443 (HTTP + HTTPS) ← bind: 192.168.30.10:80/443
        │
  [Docker network: proxy]
   ┌────┴───────────────────────────┐
   │                                │
 uptime-kuma                     dozzle
 :3001 (internal only)           :8080 (internal only, simple auth)

 dockge route exists in Caddy; backend container not started yet
```

- `proxy` is a Docker bridge network owned by the Caddy stack.
- Uptime Kuma, Dockge, and Dozzle publish no host ports.
- All access goes through Caddy reverse proxy.
- TLS: Caddy `tls internal` live for LAN HTTPS; HTTP routes remain enabled.

## Compose layout on Docker VM

```
/srv/compose/
  caddy/
    compose.yaml      ← live
    Caddyfile         ← live, auto_https disable_redirects + tls internal
    .env.example
  dockge/
    compose.yaml      ← file exists, container not started
    .env.example
  uptime-kuma/
    compose.yaml      ← live
    .env.example
  dozzle/
    compose.yaml      ← live
    .env.example

/srv/appdata/
  caddy/data/         ← Caddy runtime state (TLS cache etc)
  caddy/config/       ← Caddy autosave
  dockge/             ← live, state present after first-run
  uptime-kuma/        ← SQLite DB (created on first run)
  dozzle/users.yml    ← bcrypt users file, not tracked in Git
```

## Running services — Phase 1C-C2b

| Container | Image | Status | Port binding |
| --- | --- | --- | --- |
| `caddy` | `caddy:2.8.4-alpine` | live ✅ | `192.168.30.10:80→80`, `192.168.30.10:443→443` |
| `uptime-kuma` | `louislam/uptime-kuma:1.23.15` | live ✅ (healthy) | internal only |
| `dozzle` | `amir20/dozzle:v8.11.3` | live ✅ | internal only — auth via `/data/users.yml` |
| `dockge` | `louislam/dockge:1.4.2` | live ✅ | internal only — Docker socket RW |

## Caddyfile — current (HTTP + HTTPS)

```caddyfile
{
  admin off
  auto_https disable_redirects
  log {
    output stderr
    format json
    level INFO
  }
}

:80 { respond "OK" 200 }
http://proxy.home.lan  { respond "Caddy proxy.home.lan — OK" 200 }
https://proxy.home.lan { tls internal; respond "Caddy proxy.home.lan — OK" 200 }
http://kuma.home.lan   { reverse_proxy uptime-kuma:3001 }
https://kuma.home.lan  { tls internal; reverse_proxy uptime-kuma:3001 }
http://dockge.home.lan { reverse_proxy dockge:5001 }
https://dockge.home.lan { tls internal; reverse_proxy dockge:5001 }
http://dozzle.home.lan { reverse_proxy dozzle:8080 }
https://dozzle.home.lan { tls internal; reverse_proxy dozzle:8080 }
```

> `admin off` means `caddy reload` via API does not work — use `docker compose restart`
> for Caddyfile changes until admin socket is re-enabled.

## DNS rewrites — AdGuard (Pi)

| Name | IP | Status |
| --- | --- | --- |
| `proxy.home.lan` | `192.168.30.10` | ✅ live |
| `kuma.home.lan` | `192.168.30.10` | ✅ live — added 2026-05-04 (1C-C1.5) |
| `dockge.home.lan` | `192.168.30.10` | ✅ live — started 2026-05-04 (C2b), `200 OK` verified |
| `dozzle.home.lan` | `192.168.30.10` | ✅ live — added 2026-05-04, service verified C2a |

## Guardrails

- Caddy binds only `192.168.30.10:80` and `192.168.30.10:443` — no `0.0.0.0`.
- No host ports on Dockge, Uptime Kuma, or Dozzle.
- No `latest` image tags — all pinned.
- Log limits: `max-size: 10m`, `max-file: 3` on all containers.
- `restart: unless-stopped` on all containers.
- No WAN exposure. No Cloudflare tunnel. No Vaultwarden.
- Dozzle Docker socket mounted `:ro`.

## Firewall

| Rule | Direction | Port | Status |
| --- | --- | --- | --- |
| `allow-lan-admin-to-docker-ssh` | Internal → Docker VM `192.168.30.10` | TCP 22 | ✅ live Phase 1A |
| `allow-lan-admin-to-docker-http` | Internal → Docker VM `192.168.30.10` | TCP ANY | ⚠️ live Phase 1C-C3a — ID `69f8bb481bc6e72d2776e838`; name stale/broader than intended, currently covers TCP 443 |

No dedicated TCP 443 rule yet. Phase 1C-C3a verified that the TCP 443 path is
already allowed by the existing broader-than-intended Docker HTTP rule. No WAN
forwards.

## Validation — Phase 1C-C3a (2026-05-05)

| Check | Result |
| --- | --- |
| Mac mini → `192.168.30.10:443` | `Connection refused`, not timeout — path reaches Docker/Caddy publish layer |
| MBP → `192.168.30.10:443` | `Connection refused`, not timeout — path reaches Docker/Caddy publish layer |
| Docker VM `ss -lntp` | `192.168.30.10:443` published by Docker |
| Caddy container listen | `:80` only with current HTTP-only Caddyfile |
| UniFi policy detail | `allow-lan-admin-to-docker-http` is `protocol: tcp`, `destination.port_matching_type: ANY`, destination IP `192.168.30.10` |

Readiness: WARN. HTTPS path is firewall-ready for Caddy `tls internal`, but current
UniFi policy is broader than its name and docs originally stated. Later cleanup
should narrow `allow-lan-admin-to-docker-http` to TCP `80` and add a dedicated
`allow-lan-admin-to-docker-https` TCP `443` rule with the same source/destination scope.

## Validation — Phase 1C-C3b (2026-05-05)

| Check | Result |
| --- | --- |
| Pre-change backup | `docker-vm-102-backup-20260505-145939.tar.gz`, SHA256 `2a6cd6e078e9102f6c80fde6d92ecf22c5a2e45764aa324dbccc57cb716f1b78` |
| Caddyfile backup | `/srv/compose/caddy/Caddyfile.pre-c3b-tls-internal-20260505-145948.bak` |
| Caddy validation | PASS before restart |
| Restart scope | Only `caddy` restarted; `uptime-kuma`, `dozzle`, and `dockge` retained uptime |
| Caddy local CA | `Caddy Local Authority - 2026 ECC Root`, SHA256 fingerprint `21:15:4C:3B:5E:AD:15:A5:14:EA:E4:BF:24:FB:CF:50:D3:F1:08:80:2B:DF:93:84:39:4F:63:4A:20:59:5D:34` |
| Mac mini HTTPS system trust | `proxy` `200`, `kuma` `302`, `dozzle` `405`, `dockge` `200` |
| MBP HTTPS system trust | PASS 2026-05-05 C3c: `proxy` `200`, `kuma` `302`, `dozzle` `405` expected HEAD behavior, `dockge` `200` |
| HTTP preserved from Mac mini | `proxy` `200`, `kuma` `302`, `dozzle` `405`, `dockge` `200` |
| HTTP preserved from MBP | `proxy` `200`, `kuma` `302`, `dozzle` `405`, `dockge` `200` |
| Post-change backup | `docker-vm-102-backup-20260505-150235.tar.gz`, SHA256 `60cb0540d8fdca8faec5ad3d248a92ccfc6a2582dc1b5cc50fe9e30d7bb57774` |

Rollback:

```bash
ssh -i ~/.ssh/id_ed25519_mbp yasse@192.168.30.10 'cd /srv/compose/caddy && cp Caddyfile.pre-c3b-tls-internal-20260505-145948.bak Caddyfile && docker compose restart caddy'
```

SSH alias note: `docker` is host-local, not guaranteed across machines. On Mac mini, `ssh docker` may work if configured. On this MBP, `ssh docker` alias is stale/broken; verified MBP access path is `ssh -i ~/.ssh/id_ed25519_mbp yasse@192.168.30.10`. Agents must verify SSH alias before assuming it works.

## Phase 1C-C4 — Uptime Kuma HTTPS monitor move — 2026-05-05

Status: PASS after Phase 1C-C4a per-monitor CA fix.

Initial URL-only attempt failed and was rolled back to keep monitors green:

| Monitor | Attempted URL | Result |
| --- | --- | --- |
| `Caddy proxy` | `https://proxy.home.lan` | DOWN: `unable to get local issuer certificate` |
| `Uptime Kuma` | `https://kuma.home.lan` | DOWN: `unable to get local issuer certificate` |
| `Dockge` | `https://dockge.home.lan` | DOWN/PENDING: `unable to get local issuer certificate` |

Rollback applied immediately via the same Uptime Kuma `editMonitor` path:

| Monitor | Restored URL | Latest status after rollback |
| --- | --- | --- |
| `Caddy proxy` | `http://proxy.home.lan` | UP: `200 - OK` |
| `Uptime Kuma` | `http://kuma.home.lan` | UP: `200 - OK` |
| `Dockge` | `http://dockge.home.lan` | UP: `200 - OK` |

Phase 1C-C4a then applied Caddy `root.crt` PEM as per-monitor `tlsCa` via the
Uptime Kuma `editMonitor` socket API. No compose changes, Caddy changes, UniFi
changes, DNS changes, container restarts, or new monitors.

| Monitor | Current URL | TLS config | Latest status |
| --- | --- | --- | --- |
| `Caddy proxy` | `https://proxy.home.lan` | `auth_method=mtls`, `tls_ca` present, `ignore_tls=0` | UP: `200 - OK` |
| `Uptime Kuma` | `https://kuma.home.lan` | `auth_method=mtls`, `tls_ca` present, `ignore_tls=0` | UP: `200 - OK` |
| `Dockge` | `https://dockge.home.lan` | `auth_method=mtls`, `tls_ca` present, `ignore_tls=0` | UP: `200 - OK` |

Phase 1C-C4b added the missing Dozzle monitor only:

| Monitor | ID | Current URL | Method | TLS config | Latest status |
| --- | ---: | --- | --- | --- | --- |
| `Dozzle` | `14` | `https://dozzle.home.lan` | `GET` | `auth_method=mtls`, `tls_ca` present, `tls_cert` empty, `tls_key` empty, `ignore_tls=0` | UP: `200 - OK` |

Note: Uptime Kuma `1.23.15` exposes the server CA field under `authMethod=mtls`.
Only `tlsCa` is populated; client `tlsCert` and `tlsKey` are empty.

## Validation — Phase 1C-C2a (2026-05-04)

| Check | Result |
| --- | --- |
| `docker ps` caddy | `Up`, `192.168.30.10:80→80`, `192.168.30.10:443→443` ✅ |
| `docker ps` uptime-kuma | `Up (healthy)` ✅ |
| `docker ps` dozzle | `Up`, internal only ✅ |
| `curl -I http://proxy.home.lan` from Mac mini | `200 OK` ✅ |
| `curl -I http://kuma.home.lan` from Mac mini | `302 /dashboard` ✅ |
| `curl -I http://proxy.home.lan` from MBP | `200 OK` ✅ |
| `curl -I http://kuma.home.lan` from MBP | `302 /dashboard` ✅ |
| DNS `kuma/dockge/dozzle.home.lan` from Pi | `192.168.30.10` ✅ |
| DNS `kuma/dockge/dozzle.home.lan` from Mac mini | `192.168.30.10` ✅ |
| `curl http://dozzle.home.lan` (GET) | `200 OK` (login form) — auth active, verified 2026-05-04 ✅ |
| `curl -I http://dozzle.home.lan` (HEAD) | `405 Method Not Allowed` (expected) |
| Dozzle logs | `Connected to Docker`, `Accepting connections :8080`, `Token created` (user logged in) ✅ |
| Dozzle auth | `DOZZLE_AUTH_PROVIDER=simple`, `/data/users.yml` bcrypt, logins work ✅ |
| Docker socket dozzle | `:ro` verified via `docker inspect` ✅ |
| Caddy logs | clean — startup `auto_https off`; streaming errors are client disconnects (expected) ✅ |
| Uptime Kuma logs | `Listening on 3001` ✅ |
| `systemctl --failed` on Docker VM | `0 units` ✅ |
| Disk | `2.2G / 118G` (2%) ✅ |

## Uptime Kuma monitors — baseline 2026-05-04

> Live audit 2026-05-05 supersedes the older green-only baseline below for
> operational truth. Current status is WARN, with all monitors UP. See
> `docs/opti/uptime-kuma-monitor-audit-2026-05-05.md`.

| Monitor | Type | Target | Expected | Status |
| --- | --- | --- | --- | --- |
| AdGuard UI | Port | `Adguard.home.lan:443` | TCP open | 🟢 UP — WARN: duplicate TCP 443 signal with `Adguard Web` |
| Adguard Web | Port | `Adguard.home.lan:443` | TCP open | 🟢 UP — WARN: duplicate TCP 443 signal with `AdGuard UI` |
| AdGuard DNS | DNS | `proxy.home.lan` via `192.168.1.55` → `192.168.30.10` | resolves | 🟢 UP — WARN: name/target unclear |
| Docker VM | Ping/reachability | `docker.home.lan` | reachable | 🟢 UP — acceptable if DNS-dependent target is intended; `maxretries=1` |
| HAOS | HTTP(S) + paused duplicate | ID `10` `http://ha.home.lan:8123/`; ID `9` `ha.home.lan:8123` | `200 OK`; duplicate paused | 🟢 UP — ID `10` canonical; ID `9` renamed `HAOS TCP 8123 (paused duplicate)` and paused 2026-05-05 |
| Uptime Kuma | HTTP(S) | `https://kuma.home.lan` | `200 OK` | 🟢 UP — per-monitor Caddy `tlsCa`, `auth_method=mtls` |
| Caddy proxy | HTTP(S) | `https://proxy.home.lan` | `200 OK` | 🟢 UP — per-monitor Caddy `tlsCa`, `auth_method=mtls` |
| Dockge | HTTP(S) | `https://dockge.home.lan` | `200 OK` | 🟢 UP — per-monitor Caddy `tlsCa`, `auth_method=mtls`; `maxretries=1` |
| Dozzle | HTTP(S) | `https://dozzle.home.lan` | `200 OK` after redirect to login | 🟢 UP — monitor ID `14`, method `GET`, per-monitor Caddy `tlsCa`, `auth_method=mtls` |
| Proxmox | HTTP(S) | `https://proxmox.home.lan:8006` | `200 OK` | ⚠️ ABSENT — expected paused monitor is not present in live Kuma DB |

> Remaining approval gates for future cleanup: `GO KUMA FIX MONITORS`,
> `GO KUMA ADD PROXMOX PAUSED`, `GO KUMA ADGUARD CLEANUP`.

## Next steps

1. ~~DNS rewrites kuma/dockge/dozzle~~ ✅ done 2026-05-04
2. ~~UniFi firewall TCP 80~~ ✅ done 2026-05-04
3. ~~curl-validering från Mac mini + MBP~~ ✅ done 2026-05-04
4. ~~Admin-lösenord + Uptime Kuma baseline monitors~~ ✅ done 2026-05-04
5. ~~Dozzle (C2a) — simple auth, socket RO~~ ✅ done 2026-05-04
6. ~~Dozzle C2a validation docs~~ ✅ done 2026-05-04
7. ~~Docker backup baseline~~ ✅ done 2026-05-04 — script + restore-test PASS
8. ~~Start Dockge (C2b)~~ ✅ done 2026-05-04 — `200 OK`, password set, all stacks visible.
9. ~~Add `tls internal` to Caddyfile + import Caddy root CA into macOS Keychain~~ ✅ Caddy TLS live 2026-05-05; Mac mini and MBP trust PASS.
10. ~~Add Dozzle monitor explicitly~~ ✅ done 2026-05-05 (C4b), monitor ID `14`.
11. Schedule Proxmox backup job (external target).
12. Lös firewall-scope Docker VM → Proxmox och aktivera Proxmox-monitor.
