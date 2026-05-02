# Services

## Network control plane

UDR-7 / UniFi is the gateway/controller layer for DHCP, VLANs, firewall, WiFi, and WireGuard. Pi services are runtime DNS services.

Related current inventories:

- [UDR-7 baseline](../docs/udr7-baseline.md)
- [UniFi networks](unifi-networks.md)
- [UniFi firewall](unifi-firewall.md)
- [UniFi WiFi](unifi-wifi.md)
- [DHCP reservations](dhcp-reservations.md)


> Auktoritativ tjänst/port-inventering.
> Status: `live` = verifierad i baseline-doc | `planned` = ej live-verifierad | `verify` = osäker
> DNS records may exist before a service is live. A DNS name resolving is not enough to mark a service `live`; verify the service port/process from the target host or client path first.
> Relaterat: `caddy/services.md` (Caddy-routes), `inventory/dns-names.md` (DNS-rewrites).
> Uppdatera vid nya tjänster. Inga secrets här.

## Pi — 192.168.1.55

| Service | Port | Protocol | Status | Note |
|---|---|---|---|---|
| AdGuard Home — DNS | 53 | UDP+TCP | live | Wildcard listener (`*`:53 / `0.0.0.0:53`) för LAN DNS. Verifierad via `dig @192.168.1.55` från Mac mini 2026-04-26 och Pi service audit 2026-04-28. |
| AdGuard Home — UI | 3000 | HTTP | live | Wildcard listener (`*`:3000). Konfigurerad i `AdGuardHome.yaml`; force-HTTPS/redirect path till :443. Verifierad i Pi service audit 2026-04-28. |
| AdGuard Home — HTTPS/UI | 443 | HTTPS | live | Wildcard listener (`*`:443). TLS-cert: `adguard.home.lan`, serial `47BBFE...`, giltig t.o.m. 2028-07-29. Verifierad via `curl -Ik https://adguard.home.lan` 2026-04-26 och Pi service audit 2026-04-28. |
| AdGuard Home — DoT/DoQ | 853 | TLS/TCP + QUIC/UDP | live | Wildcard listener (`*`:853) för DNS-over-TLS och DNS-over-QUIC. Konfigurerad i `AdGuardHome.yaml`. Verifierad via `openssl s_client -connect adguard.home.lan:853` 2026-04-26 och Pi service audit 2026-04-28. |
| AdGuard Home — DoH | 443 `/dns-query` | HTTPS | live | RFC8484 `POST /dns-query` med `application/dns-message` verifierad från Pi 2026-04-30: `HTTP=200`, DNS `rcode=0`, `answers=2`. |
| Unbound | 5335 | UDP+TCP | live | Local-only runtime listener på `127.0.0.1:5335`; AdGuard upstream. `::1@5335` finns i config men `do-ip6: no` gör IPv6-bind inert. Verifierad via `ss` i Pi service audit 2026-04-28. |
| Cockpit | 9090 | HTTPS | live | Intentional admin UI service. Socket-activated: `cockpit.socket` är enabled och lyssnar på `*`:9090 / `[::]`:9090 även när `cockpit.service` är inactive. Keep enabled. |
| SSH | 22 | TCP | live | LAN/IPv6-exposed listener på `0.0.0.0:22` och `[::]:22`. Verifierad i Pi service audit 2026-04-28. |
| Avahi / mDNS | 5353 + ephemeral UDP | UDP | disabled | `avahi-daemon.service` och `avahi-daemon.socket` är disabled sedan 2026-04-29. Pi annonserar inte längre `pi.local`/mDNS discovery; `home.lan`/AdGuard/Unbound DNS påverkas inte. |

> AdGuard DDR setting: `handle_ddr=false` sedan 2026-04-26. Inaktiverad medvetet — se `docs/dns-tls-baseline-2026-04-26.md`.

### Cleanup state from Pi service audit 2026-04-28

Applied 2026-04-29. Ingen package removal, ingen maskning, och Cockpit lämnades enabled:

- `avahi-daemon.service` / `avahi-daemon.socket` — disabled. Risk/effekt: `pi.local`/mDNS discovery tillhandahålls inte längre av Pi; `home.lan`/AdGuard/Unbound DNS påverkas inte.
- `cloud-init-*` units — disabled post-provision. `cloud-init status` är fortsatt disabled via `/etc/cloud/cloud-init.disabled`; ingen package removal gjord eller rekommenderad.
- Gamla Unbound `.bak*`-filer under `/etc/unbound/unbound.conf.d/` — flyttade till `/etc/unbound/archive/unbound-conf-d-bak-20260429-002313`. De var inte aktiva eftersom Unbound include pattern bara matchar `*.conf`.

## Opti / Proxmox — 192.168.1.60

| Service | Port | Protocol | Status | Note |
|---|---|---|---|---|
| Proxmox UI/API | 8006 | HTTPS | live | Direct IP access: `https://192.168.1.60:8006`. Do not treat `proxmox.home.lan` as verified by this docs-only update. No VMs/CTs exist yet. |

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

UDR-7 is the gateway/controller dependency for network policy. Current baseline: [UDR-7 baseline](../docs/udr7-baseline.md).

| Service | Port | Protocol | Status | Note |
|---|---|---|---|---|
| UniFi UI | 443 | HTTPS | verify | Lokal admin. HTTPS-åtkomst ej explicit verifierad i denna audit. |
| WireGuard | 51820 | UDP | verify | Konfigurerad på UDR-7. Port ej explicit verifierad i denna audit. |
| SSH | 22 | TCP | live | Verifierad via alias: `ssh -o BatchMode=yes -o ConnectTimeout=5 udr 'hostname; date'` 2026-04-26. |
