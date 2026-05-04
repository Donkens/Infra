# Docker Foundation — Opti VM 102

## Status

**Phase 1C-C1.5 — 2026-05-04** — Caddy + Uptime Kuma nåbara från LAN. DNS-rewrites
för `kuma`, `dockge`, `dozzle` lagda i AdGuard. UniFi firewall-regel
`allow-lan-admin-to-docker-http` (TCP 80, Internal → Docker VM) live. Dockge
compose-fil finns men containern är inte startad. Dozzle körs via Caddy.

**Uptime Kuma baseline — 2026-05-04** — Admin-lösenord satt. Sex aktiva gröna
monitors konfigurerade (se nedan). Proxmox-monitor pausad p.g.a. firewall-scope.

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

## Architecture

```
LAN client (*.home.lan)
        │
        ▼
 Caddy :80 (HTTP)           ← only bind: 192.168.30.10:80/443
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
- TLS: `auto_https off` in Phase 1C-C1. Add `tls internal` or ACME in a later phase.

## Compose layout on Docker VM

```
/srv/compose/
  caddy/
    compose.yaml      ← live
    Caddyfile         ← live, auto_https off
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

## Caddyfile — current (HTTP-only)

```caddyfile
{
  admin off
  auto_https off
  log { output stderr; format json; level INFO }
}

:80 { respond "OK" 200 }
http://proxy.home.lan  { respond "Caddy proxy.home.lan — OK" 200 }
http://kuma.home.lan   { reverse_proxy uptime-kuma:3001 }
http://dockge.home.lan { reverse_proxy dockge:5001 }
http://dozzle.home.lan { reverse_proxy dozzle:8080 }
```

> `admin off` means `caddy reload` via API does not work — use `docker compose restart`
> for Caddyfile changes until admin socket is re-enabled.
>
> `dockge.home.lan` DNS and Caddy route exist, but Dockge is intentionally not
> started yet. Expect backend failure there until Phase 1C-C2b.

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
| `allow-lan-admin-to-docker-http` | Internal → Docker VM `192.168.30.10` | TCP 80 | ✅ live Phase 1C-C1.5 — ID `69f8bb481bc6e72d2776e838` |

No TCP 443 yet (TLS not enabled). No WAN forwards.

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

| Monitor | Type | Target | Expected | Status |
| --- | --- | --- | --- | --- |
| AdGuard UI | HTTP(S) | `https://adguard.home.lan` | `200 OK` | 🟢 UP |
| AdGuard DNS | DNS | A `adguard.home.lan` → `192.168.30.10` resolve check | resolves | 🟢 UP |
| Docker VM | Ping/reachability | `192.168.30.10` | reachable | 🟢 UP |
| HAOS | HTTP(S) | `http://192.168.30.20:8123` | `200 OK` | 🟢 UP |
| Uptime Kuma | HTTP(S) | `http://kuma.home.lan` | `200 OK` | 🟢 UP |
| Caddy proxy | HTTP(S) | `http://proxy.home.lan` | `200 OK` | 🟢 UP |
| Proxmox | HTTP(S) | `https://proxmox.home.lan:8006` | `200 OK` | ⏸ PAUSED — Docker VM ligger i Server VLAN 30, ej Default LAN; firewall blockerar Docker VM → Proxmox. Aktivera när scope är löst. |

> AdGuard DNS-monitor verifierar A-record för `adguard.home.lan` mot `192.168.30.10`
> (Docker VM IP). Detta är ett DNS-funktionstest, inte ett reachability-test mot Pi.
> Duplikat/felkonfigurerad HAOS-monitor städad bort 2026-05-04.

## Next steps

1. ~~DNS rewrites kuma/dockge/dozzle~~ ✅ done 2026-05-04
2. ~~UniFi firewall TCP 80~~ ✅ done 2026-05-04
3. ~~curl-validering från Mac mini + MBP~~ ✅ done 2026-05-04
4. ~~Admin-lösenord + Uptime Kuma baseline monitors~~ ✅ done 2026-05-04
5. ~~Dozzle (C2a) — simple auth, socket RO~~ ✅ done 2026-05-04
6. ~~Dozzle C2a validation docs~~ ✅ done 2026-05-04
7. ~~Docker backup baseline~~ ✅ done 2026-05-04 — script + restore-test PASS
8. ~~Start Dockge (C2b)~~ ✅ done 2026-05-04 — `200 OK`, password set, all stacks visible.
9. Add `tls internal` to Caddyfile + import Caddy root CA into macOS Keychain.
10. Schedule Proxmox backup job (external target).
11. Lös firewall-scope Docker VM → Proxmox och aktivera Proxmox-monitor.
