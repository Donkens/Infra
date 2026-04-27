# Services

> Auktoritativ tjänst/port-inventering.
> Status: `live` = verifierad i baseline-doc | `planned` = ej live-verifierad | `verify` = osäker
> Relaterat: `caddy/services.md` (Caddy-routes), `inventory/dns-names.md` (DNS-rewrites).
> Uppdatera vid nya tjänster. Inga secrets här.

## Pi — 192.168.1.55

| Service | Port | Protocol | Status | Note |
|---|---|---|---|---|
| AdGuard Home — DNS | 53 | UDP+TCP | live | `0.0.0.0:53`. Verifierad via `dig @192.168.1.55` från Mac mini 2026-04-26. |
| AdGuard Home — UI | 3000 | HTTP | live | `0.0.0.0:3000`. Konfigurerad i `AdGuardHome.yaml`. Verifierad i Pi baseline. |
| AdGuard Home — HTTPS/UI | 443 | HTTPS | live | TLS-cert: `adguard.home.lan`, serial `47BBFE...`, giltig t.o.m. 2028-07-29. Verifierad via `curl -Ik https://adguard.home.lan` 2026-04-26. |
| AdGuard Home — DoT | 853 | TLS/TCP | live | DNS-over-TLS. Konfigurerad i `AdGuardHome.yaml`. Verifierad via `openssl s_client -connect adguard.home.lan:853` 2026-04-26. |
| AdGuard Home — DoH | 443 `/dns-query` | HTTPS | verify | Endpoint finns om AdGuard HTTPS är aktivt på :443 — ej explicit verifierad i baseline. |
| Unbound | 5335 | UDP+TCP | live | `127.0.0.1@5335` + `::1@5335`. Verifierad via `unbound-control status` i Pi baseline 2026-04-27. |
| Cockpit | 9090 | HTTPS | live | Verifierad via `curl -Ik https://pi.home.lan:9090` 2026-04-26. |
| SSH | 22 | TCP | live | `0.0.0.0` + `[::]`. Verifierad i Pi baseline. |

> AdGuard DDR setting: `handle_ddr=false` sedan 2026-04-26. Inaktiverad medvetet — se `docs/dns-tls-baseline-2026-04-26.md`.

## Opti / Proxmox — 192.168.1.60

| Service | Port | Protocol | Status | Note |
|---|---|---|---|---|
| Proxmox UI | 8006 | HTTPS | planned | DNS-namn live (`proxmox.home.lan` → `192.168.1.60`), men tjänsten ej live-verifierad i denna audit. |

## Docker VM — 192.168.30.10

| Service | Port | Protocol | Status | Note |
|---|---|---|---|---|
| Caddy | 80/443 | HTTP/HTTPS | planned | DNS-namn live (`proxy.home.lan`), tjänst ej live-verifierad i denna audit. |
| Dockge | 5001 | HTTP | planned | via Caddy → `dockge.home.lan`. |
| Uptime Kuma | 3001 | HTTP | planned | via Caddy → `uptime.home.lan`. |
| Dozzle | 8080 | HTTP | planned | via Caddy → `dozzle.home.lan`. |
| Stremio Server | 11470 | HTTP | planned | via Caddy → `stremio.home.lan`. |

## HAOS — 192.168.30.20

| Service | Port | Protocol | Status | Note |
|---|---|---|---|---|
| Home Assistant | 8123 | HTTP | planned | `ha.home.lan` → `192.168.30.20`. Ej via Caddy. DNS-namn live, tjänst ej live-verifierad i denna audit. |

## UDR-7 — 192.168.1.1

| Service | Port | Protocol | Status | Note |
|---|---|---|---|---|
| UniFi UI | 443 | HTTPS | verify | Lokal admin. HTTPS-åtkomst ej explicit verifierad i denna audit. |
| WireGuard | 51820 | UDP | verify | Konfigurerad på UDR-7. Port ej explicit verifierad i denna audit. |
| SSH | 22 | TCP | live | Verifierad via alias: `ssh -o BatchMode=yes -o ConnectTimeout=5 udr 'hostname; date'` 2026-04-26. |
