# DNS-arkitektur — home.lan

> Single source-of-truth för DNS-auktoritetsmodellen.
> Senast verifierad: 2026-04-29.

## Network authority roles

| Layer | Authority | Role |
|---|---|---|
| DHCP / VLAN / firewall / WiFi | UDR-7 / UniFi | Distributes DNS, owns gateway and client network policy. |
| DNS node | Pi `192.168.1.55` | Runs AdGuard Home and Unbound. |
| Client DNS / forward rewrites | AdGuard Home | LAN-facing DNS, filtering, and service aliases. |
| Recursion / PTR | Unbound | Recursive resolver and local reverse records only. |

## DNS-kedja

```
klient
  └─► AdGuard Home  192.168.1.55 : 53 (UDP/TCP)
                     fd12:3456:7801::55 : 53 (UDP/TCP)
                                  : 443 (DoH  /dns-query)
                                  : 853 (DoT)
        └─► Unbound  127.0.0.1 : 5335
              └─► upstream (rekursiv, internet)
```

- Inga parallella resolvers tillåtna. En kedja, alltid.
- AdGuard är det enda LAN-synliga DNS-gränssnittet.
- Unbound lyssnar enbart på localhost (`127.0.0.1` och `::1`).
- Pi tillhandahåller inte längre `pi.local`/mDNS discovery efter att `avahi-daemon.service` och `avahi-daemon.socket` disabled 2026-04-29. `home.lan` via AdGuard/Unbound är oförändrat.


## Kända upstream-undantag

- `forward-dxcloud.conf` är ett avsiktligt smalt Unbound-undantag för en specifik zone. Den forwardar zonen till Cloudflare (`1.1.1.1`, `1.0.0.1`) och ska inte tolkas som en generell parallell resolver.
- AdGuard `bootstrap_dns` använder Quad9 för bootstrap av krypterad/namnbaserad upstream-kontext. Det är en bootstrap-only dependency, inte klienternas primära DNS-kedja.
- Standardflödet är fortsatt klient -> AdGuard (`192.168.1.55:53`) -> Unbound (`127.0.0.1:5335`) -> rekursiv upstream/root resolution.

## Rollfördelning — vem äger vad

| Record-typ | Auktoritet | Var konfigurerat |
|---|---|---|
| A/AAAA för live hosts och tjänster | **AdGuard Home** — client-facing DNS / rewrites | AdGuard UI / `AdGuardHome.yaml` |
| PTR (reverse DNS) för alla hosts | **Unbound** — `local-data-ptr` | `config/unbound/unbound.conf.d/ptr-local.conf` |
| Rekursiv resolution (internet-namn) | **Unbound** | upstream via root-hints |
| Blocklists / filtering | **AdGuard Home** | filter-listor i AdGuard UI |

### `home.lan`-zonen

AdGuard äger forward lookups för live `home.lan` hosts och tjänster. Klienter ska fråga AdGuard på Pi (`192.168.1.55:53` / `fd12:3456:7801::55:53`), och AdGuard använder Unbound på `127.0.0.1:5335` för rekursiv resolution.

Unbound har `local-zone: "home.lan." static` för reverse/PTR-modellen och `ptr-local.conf` innehåller `local-data-ptr`, inte forward `local-data` A/AAAA-records. En direkt forward-fråga till Unbound, t.ex. `dig @127.0.0.1 -p 5335 pi.home.lan A`, returnerar därför `NXDOMAIN` enligt aktuell baseline.

Duplicera inte forward `.home.lan`-namn i Unbound om auktoritetsmodellen inte avsiktligt ändras. Om en host har både forward och reverse DNS ligger forward i AdGuard och reverse i Unbound.

## DoT / DoH / DDR

| Protokoll | Status | Detalj |
|---|---|---|
| DoT (DNS-over-TLS) | ✅ live | Port `853`. Cert: `adguard.home.lan`, giltig t.o.m. 2028-07-29. |
| DoH (DNS-over-HTTPS) | `verify` | Endpoint `/dns-query` på port `443` — ej explicit verifierad. |
| DDR | ❌ av | `handle_ddr: false` sedan 2026-04-26. Apple DDR orsakade TLS-friction mot privat CA. |
| DNSSEC | ❌ av | `dnssec: false`. Inte aktiverat — Unbound gör inte DNSSEC-validering nedströms. |

## Firewall-enforcement

UDR-7 blockerar DNS-bypass på Default LAN:
- `192.168.1.55` (Pi) → WAN port 53: tillåtet (Pi behöver nå upstream).
- Alla andra LAN-klienter → WAN port 53: blockerat.
- Gateway `192.168.1.1` port 53 internt: blockerat.

Detaljer: [`docs/unifi-firewall-state-2026-04-15.md`](unifi-firewall-state-2026-04-15.md)

## Backup och snapshot

- Live state ägs av Pi (runtime source of truth).
- Saniterade Unbound-snapshots spåras i `config/unbound/`.
- AdGuard-summary (counts only, inga secrets) spåras i `config/adguardhome/AdGuardHome.summary.sanitized.yml`.
- Nightly `infra-auto-sync` exporterar och committar snapshots automatiskt.

## Relaterade dokument

- [`docs/adguard-home-change-policy.md`](adguard-home-change-policy.md) — hur AdGuard ändras säkert
- [`docs/dns-tls-baseline-2026-04-26.md`](dns-tls-baseline-2026-04-26.md) — TLS/DDR cleanup baseline
- [`inventory/dns-names.md`](../inventory/dns-names.md) — fullständig DNS-namnlista
- [`config/unbound/unbound.conf.d/ptr-local.conf`](../config/unbound/unbound.conf.d/ptr-local.conf) — PTR/reverse records

## DNS bypass risk

UDR dnsmasq listens on gateway IPs such as `192.168.1.1`, `192.168.30.1`, and `192.168.40.1`. Firewall policy is required to keep clients on Pi DNS. Default and MLO client bypass checks were verified blocked on 2026-04-28. Server VLAN 30 and IoT-to-gateway DNS behavior need explicit client-side validation before workloads or policy changes.

Current policy inventory: [UniFi firewall](../inventory/unifi-firewall.md).
