# Docker Foundation — Opti VM 102

## Status

**Phase 1C-C1.5 — 2026-05-04** — Caddy + Uptime Kuma nåbara från LAN. DNS-rewrites
för `kuma`, `dockge`, `dozzle` lagda i AdGuard. UniFi firewall-regel
`allow-lan-admin-to-docker-http` (TCP 80, Internal → Docker VM) live. Dockge och
Dozzle compose-filer finns men containrarna är inte startade.

## Architecture

```
LAN client (*.home.lan)
        │
        ▼
 Caddy :80 (HTTP)           ← only bind: 192.168.30.10:80/443
        │
  [Docker network: proxy]
   ┌────┴──────────────────┐
   │                       │
 uptime-kuma            (dockge, dozzle — planned)
 :3001 (internal only)
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
    compose.yaml      ← file exists, container not started
    .env.example

/srv/appdata/
  caddy/data/         ← Caddy runtime state (TLS cache etc)
  caddy/config/       ← Caddy autosave
  dockge/             ← created, empty
  uptime-kuma/        ← SQLite DB (created on first run)
```

## Running services — Phase 1C-C1

| Container | Image | Status | Port binding |
| --- | --- | --- | --- |
| `caddy` | `caddy:2.8.4-alpine` | live ✅ | `192.168.30.10:80→80`, `192.168.30.10:443→443` |
| `uptime-kuma` | `louislam/uptime-kuma:1.23.15` | live ✅ (healthy) | internal only |

## Planned services (compose files exist, not started)

| Container | Image | Planned DNS |
| --- | --- | --- |
| `dockge` | `louislam/dockge:1.4.2` | `dockge.home.lan` |
| `dozzle` | `amir20/dozzle:v8.11.3` | `dozzle.home.lan` |

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

## DNS rewrites — AdGuard (Pi)

| Name | IP | Status |
| --- | --- | --- |
| `proxy.home.lan` | `192.168.30.10` | ✅ live |
| `kuma.home.lan` | `192.168.30.10` | ✅ live — added 2026-05-04 (1C-C1.5) |
| `dockge.home.lan` | `192.168.30.10` | ✅ live — added 2026-05-04 (1C-C1.5) |
| `dozzle.home.lan` | `192.168.30.10` | ✅ live — added 2026-05-04 (1C-C1.5) |

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

## Validation — Phase 1C-C1.5 (2026-05-04)

| Check | Result |
| --- | --- |
| `docker ps` caddy | `Up`, `192.168.30.10:80→80`, `192.168.30.10:443→443` ✅ |
| `docker ps` uptime-kuma | `Up (healthy)` ✅ |
| `curl -I http://proxy.home.lan` from Mac mini | `200 OK` ✅ |
| `curl -I http://kuma.home.lan` from Mac mini | `302 /dashboard` ✅ |
| `curl -I http://proxy.home.lan` from MBP | `200 OK` ✅ |
| `curl -I http://kuma.home.lan` from MBP | `302 /dashboard` ✅ |
| DNS `kuma/dockge/dozzle.home.lan` from Pi | `192.168.30.10` ✅ |
| DNS `kuma/dockge/dozzle.home.lan` from Mac mini | `192.168.30.10` ✅ |
| `systemctl --failed` on Docker VM | `0 units` ✅ |
| Caddy logs | clean — startup `auto_https off`, no errors ✅ |
| Uptime Kuma logs | `Listening on 3001`, `No user, need setup` ✅ |

## Next steps

1. ~~DNS rewrites kuma/dockge/dozzle~~ ✅ done 2026-05-04
2. ~~UniFi firewall TCP 80~~ ✅ done 2026-05-04
3. ~~curl-validering från Mac mini + MBP~~ ✅ done 2026-05-04
4. Set admin password in Uptime Kuma UI (`http://kuma.home.lan/setup`).
5. Start Dockge and Dozzle stacks (separate phase).
6. Add `tls internal` to Caddyfile + import Caddy root CA into macOS Keychain.
7. Schedule Proxmox backup job (external target).
