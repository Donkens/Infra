# Docker Foundation — Opti VM 102

## Status

**Phase 1C-C1 — 2026-05-04** — Caddy + Uptime Kuma live. Dockge and Dozzle compose
files created but not started. DNS rewrites for `kuma.home.lan`, `dockge.home.lan`,
and `dozzle.home.lan` not yet added to AdGuard.

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
| `kuma.home.lan` | `192.168.30.10` | PENDING — run `/tmp/adguard-rewrites.sh` on Pi |
| `dockge.home.lan` | `192.168.30.10` | PENDING — same script |
| `dozzle.home.lan` | `192.168.30.10` | PENDING — same script |

Script written to Pi at `/tmp/adguard-rewrites.sh`. Run via:
```bash
ssh pi 'bash /tmp/adguard-rewrites.sh'
```
Credentials are entered interactively — not stored in chat or history.

## Guardrails

- Caddy binds only `192.168.30.10:80` and `192.168.30.10:443` — no `0.0.0.0`.
- No host ports on Dockge, Uptime Kuma, or Dozzle.
- No `latest` image tags — all pinned.
- Log limits: `max-size: 10m`, `max-file: 3` on all containers.
- `restart: unless-stopped` on all containers.
- No WAN exposure. No Cloudflare tunnel. No Vaultwarden.
- Dozzle Docker socket mounted `:ro`.

## Firewall note

HTTP port 80 from LAN to Docker VM (`192.168.30.10`) is not yet permitted by
UniFi firewall. Only SSH (TCP 22) is allowed from Admin zone. A future rule will
be needed to allow `192.168.30.x:80` access from LAN/Admin zones. No firewall
changes were made in Phase 1C-C1.

## Validation — Phase 1C-C1 (2026-05-04)

All curl validation run from inside Docker VM (`192.168.30.10`) — external HTTP
blocked by UniFi firewall (expected, no HTTP rule exists yet).

| Check | Result |
| --- | --- |
| `docker ps` caddy | `Up`, `192.168.30.10:80→80`, `192.168.30.10:443→443` ✅ |
| `docker ps` uptime-kuma | `Up (healthy)` ✅ |
| `curl http://192.168.30.10/` | `200 OK` ✅ |
| `curl -H Host:proxy.home.lan http://192.168.30.10/` | `200 OK` ✅ |
| `curl -H Host:kuma.home.lan http://192.168.30.10/` | `302 /dashboard` (Uptime Kuma) ✅ |
| `systemctl --failed` | `0 units` ✅ |
| Disk `/` | `2.2G used / 111G free` ✅ |
| HTTP from MBP | blocked by firewall (expected) |

## Next steps

1. Run `/tmp/adguard-rewrites.sh` on Pi to add DNS rewrites for `kuma`, `dockge`, `dozzle`.
2. Validate `curl http://kuma.home.lan` from LAN client (after firewall rule for HTTP is added).
3. Add UniFi firewall rule: allow LAN → `192.168.30.10` TCP 80 (for LAN HTTP access).
4. Start Dockge and Dozzle stacks.
5. Set admin password in Uptime Kuma UI (`http://kuma.home.lan/setup`).
6. Add `tls internal` to Caddyfile and import Caddy root CA into macOS Keychain.
7. Schedule Proxmox backup job (external target).
