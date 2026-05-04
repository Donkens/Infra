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
| Proxmox UI/API | 8006 | HTTPS | live | Direct IP access: `https://192.168.1.60:8006`; DNS alias: `https://proxmox.home.lan:8006`. HAOS VM `101` exists; Docker VM not yet created. |

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
| Home Assistant | 8123 | HTTP | live | Direct access: `http://192.168.30.20:8123`; aliases `ha.home.lan` and `haos.home.lan` resolve to `192.168.30.20`. Ej via Caddy. Runtime and first full backup baseline validated 2026-05-02. Backup: `haos-onboarding-baseline-2026-05-02-full`; resolution clean after `ha resolution check run backups`. |
| Advanced SSH & Web Terminal | 22 | SSH | live | Add-on slug `a0d7b954_ssh`. Key-only SSH from MacBook and Mac mini verified; password auth not used. MacBook uses `id_ed25519_mbp`; Mac mini uses `id_ed25519_macmini`. `/home/hassio/.zshenv` exists to load the Supervisor environment for non-interactive `zsh` commands. Direct alias checks can authenticate even if `ha` CLI returns `unauthorized`; validate HA CLI environment separately when needed. |
| WiZ integration | — | — | live | WiZ integration added 2026-05-03. Five WiZ bulbs / 20 entities on IoT VLAN 10 (`192.168.10.129`, `.131`, `.133`, `.134`, `.174`). Areas: `4F823E` Kitchen, `4F8388` Bathroom, `4F8602` Living Room, `4F8818` Living Room, `4F8888` Hallway. HAOS controls them via firewall rule `allow-haos-wiz-control` (UDP 38899-38900, Server→IoT zone). IP group: `wiz-bulbs-ipv4`. Full backup: `haos-wiz-baseline-2026-05-03-full`, slug `3e602056`, `full`, `2026-05-03T18:47:34.215668+00:00`, `0.22 MB`; resolution clean. |
| Yeelight integration | `55443` | TCP | pending | Yeelight Bedroom on IoT VLAN 10 (`192.168.10.150`, MAC `28:6c:07:xx:xx:xx`), model `color`, FW v76. LAN Control enabled. DHCP reservation `yeelight-bedroom` pending. Firewall rule `allow-haos-yeelight-control` (HAOS→Yeelight TCP 55443, Server→IoT zone) pending. Add via HA UI: Settings → Devices & services → Add Integration → Yeelight → IP `192.168.10.150`. |

## UDR-7 — 192.168.1.1

UDR-7 is the gateway/controller dependency for network policy. Current baseline: [UDR-7 baseline](../docs/udr7-baseline.md).

| Service | Port | Protocol | Status | Note |
|---|---|---|---|---|
| UniFi UI | 443 | HTTPS | verify | Lokal admin. HTTPS-åtkomst ej explicit verifierad i denna audit. |
| WireGuard | 51820 | UDP | verify | Konfigurerad på UDR-7. Port ej explicit verifierad i denna audit. |
| SSH | 22 | TCP | live | Verifierad via alias: `ssh -o BatchMode=yes -o ConnectTimeout=5 udr 'hostname; date'` 2026-04-26. |
