# Server VLAN 30 Isolation Plan — UniFi

Datum: 2026-05-03
Status: **WARN** — Förarbeten klara; zon-flytt och isoleringsregler saknas.

---

## Sammanfattning

Server VLAN 30 (`192.168.30.0/24`) och Default LAN (`192.168.1.0/24`) delar
idag samma UniFi firewall-zon (`Internal`, `677d9959ed22014620a6a981`). Det
innebär att zon-baserade inter-VLAN-regler mellan dessa nät inte kan tillämpas
förrän Server VLAN 30 får en dedikerad zon.

Tre kritiska gap bekräftade via live-analys 2026-05-03:

1. **Ingen Server-zon** — VLAN 30 är i Internal-zonen med Default LAN och MLO.
2. **DNS bypass-gap** — `@192.168.30.1:53` svarar från HAOS; gateway-DNS är
   öppen för VLAN 30 (befintliga DNS-blockningsregler täcker bara
   Default LAN + MLO via `network_ids`, inte Server VLAN 30).
3. **WiZ-regelns zone_id** — `allow-haos-wiz-control` har
   `source.zone_id = 677d9959ed22014620a6a981` (Internal). När VLAN 30 flyttas
   till en ny zon slutar regeln matcha HAOS och WiZ-styrning slutar fungera
   **omedelbart** om inte regeln uppdateras i samma steg.

Isoleringsarbetet är redo för GO Phase 2A (zon-skapande) och Phase 2B
(isoleringsregler) i separata godkänn-block. Docker VM 102 är frånvarande;
inga regler för `.10` skapas förrän VM 102 existerar.

---

## Nuläge

### Nätverkstopologi

| Nätverk | VLAN | Subnet | Gateway | Zon | Zon-ID | Syfte | Åtkomstpostur |
|---|---:|---|---|---|---|---|---|
| Default LAN | untagged | `192.168.30.0/24` | `192.168.1.1` | Internal | `677d9959ed22014620a6a981` | Betrodd admin-LAN, Proxmox-host | Fri intern trafik; DNS-bypass blockad |
| Server VLAN 30 | 30 | `192.168.30.0/24` | `192.168.30.1` | **Internal** ⚠️ | `677d9959ed22014620a6a981` | HAOS VM 101, framtida Docker VM 102 | Delad zon — inga inter-VLAN-regler möjliga |
| IOT | 10 | `192.168.10.0/24` | `192.168.10.1` | IOT | `6980de97e060a06b8ef9b613` | IoT-enheter inkl. WiZ-lampor | DNS till Pi tillåten; WAN DNS blockad |
| MLO-LAN | 40 | `192.168.40.0/24` | `192.168.40.1` | Internal | `677d9959ed22014620a6a981` | 6 GHz WiFi-klienter | DNS-bypass blockad |
| Guest | 20 | `192.168.20.0/24` | `192.168.20.1` | Hotspot | `677d9959ed22014620a6a985` | Gästnät | **Inaktiverat** |
| WireGuard | — | `10.10.10.0/24` | `10.10.10.1` | Vpn | `677d9959ed22014620a6a984` | Fjärr-VPN | Separat VPN-zon |

### Live-enheter i Server VLAN 30

| Enhet | IP | MAC (maskad) | Status |
|---|---|---|---|
| HAOS VM 101 | `192.168.30.20` | `bc:24:11:xx:xx:xx` | Live |
| Docker VM 102 | `192.168.30.10` | okänd | Frånvarande/planerad |

### Nuvarande UniFi-regler relevanta för Server VLAN 30

| Regel | Aktiverad | Åtgärd | Källa | Destination | Port | Täcker VLAN 30? |
|---|---|---|---|---|---|---|
| `IoT DNS to Pi` | ja | ALLOW | IOT zone (ANY) | Internal zone IP `192.168.1.55` | 53 | Nej |
| `block-iot-to-wan-dns-bypass` | ja | BLOCK | IOT zone (ANY) | External zone | 53 | Nej |
| `allow-pi-dns-upstream-to-wan-udp` | ja | ALLOW | Internal zone IP `192.168.1.55` | External zone | UDP 53 | Nej (källa är Pi, ej VLAN 30) |
| `allow-pi-dns-upstream-to-wan-tcp` | ja | ALLOW | Internal zone IP `192.168.1.55` | External zone | TCP 53 | Nej |
| `block-internal-gateway-dns-udp` | ja | BLOCK | Internal zone networks `Default LAN`, `MLO-LAN` | Gateway IPs `192.168.1.1`, `192.168.40.1` | UDP 53 | **Nej** ⚠️ — `69ee65711bc6e72d27744844` saknas |
| `block-internal-gateway-dns-tcp` | ja | BLOCK | Internal zone networks `Default LAN`, `MLO-LAN` | Gateway IPs `192.168.1.1`, `192.168.40.1` | TCP 53 | **Nej** ⚠️ |
| `block-internal-wan-dns-udp` | ja | BLOCK | Internal zone networks `Default LAN`, `MLO-LAN` | External zone | UDP 53 | **Nej** ⚠️ |
| `block-internal-wan-dns-tcp` | ja | BLOCK | Internal zone networks `Default LAN`, `MLO-LAN` | External zone | TCP 53 | **Nej** ⚠️ |
| `allow-haos-wiz-control` | **ja** | ALLOW | Internal zone IP `192.168.30.20` | IOT zone `wiz-bulbs-ipv4` | UDP 38899-38900 | Ja — men **bryts vid zon-flytt** |
| `allow-haos-wiz-icmp-temp` | **nej** | ALLOW | Internal zone IP `192.168.30.20` | IOT zone `wiz-bulbs-ipv4` | ICMP | Inaktiverad 2026-05-03 |

### WAN port forwards — relevans för VLAN 30

| Regel | Port | Protokoll | Destination | Relevant? |
|---|---|---|---|---|
| `qBittorrent-TCP` | 52829 | TCP | `null` (ej `.30`) | Nej |
| `qBittorrent-UDP` | 52829 | UDP | `null` | Nej |
| `qBittorrent-MBP-TCP` | 21272 | TCP | `null` | Nej |
| `qBittorrent-MBP-UDP` | 21272 | UDP | `null` | Nej |

Inga WAN port forwards pekar mot VLAN 30 eller HAOS. Bekräftat.

---

## Live-anslutningstester — 2026-05-03

Utförda read-only från Mac mini (Default LAN, `192.168.1.86`) och via SSH till
HAOS (`192.168.30.20`). Inga ändringar gjordes.

| Test | Resultat | Notering |
|---|---|---|
| Default LAN admin → HAOS `192.168.30.20:8123` | ✅ PASS | `nc -vz` succeeded |
| HAOS → gateway `192.168.30.1` (ICMP) | ✅ PASS | 2/2 paket |
| HAOS → Pi DNS `192.168.1.55` (ICMP) | ✅ PASS | 2/2 paket |
| HAOS → Pi DNS `@192.168.1.55:53` | ✅ PASS | Svarar korrekt |
| HAOS → Internet `1.1.1.1` (ICMP) | ✅ PASS | 2/2 paket |
| HAOS → Default LAN broad `192.168.1.86` (ICMP) | ❌ 100% förlust | Förmodligen macOS-firewall på Mac mini; se notering |
| **HAOS → gateway DNS bypass `@192.168.30.1:53`** | ⚠️ **SVARAR** | **GAP — dnsmasq servar VLAN 30** |
| HAOS → WAN DNS `@1.1.1.1:53` | ej testat | (Mac mini → `@1.1.1.1` timed out — WAN DNS block fungerar för Default LAN) |
| HAOS → WiZ-lampa `192.168.10.129` (ICMP) | ❌ 100% förlust | Förväntat — ICMP-regeln är inaktiverad |
| Mac mini → `@1.1.1.1:53` | ✅ Blockad (timeout) | WAN DNS-bypass-block fungerar för Default LAN |
| Mac mini → `@192.168.30.1:53` | ⚠️ Svarar | Cross-VLAN DNS-query passerar (ej kritiskt för isolering) |

> **Notering HAOS → Mac mini:** 100% paketförlust kan bero på macOS Application
> Firewall eller macOS stealth-läge, inte nödvändigtvis en UniFi-block. Faktisk
> HTTP/TCP-åtkomst testades ej. Eftersom Default LAN och Server VLAN 30 är i
> samma zon (`Internal`) finns ingen UniFi-regel som blockerar detta idag.

---

## Gap-analys

### G1 — Ingen dedikerad Server-zon (KRITISK)

Server VLAN 30 (`69ee65711bc6e72d27744844`) är i `Internal`-zonen
(`677d9959ed22014620a6a981`) tillsammans med Default LAN och MLO-LAN. UniFi:s
zon-baserade firewall kan inte tillämpa inter-VLAN-regler mellan nätverk inom
samma zon. Isolation är omöjlig utan att flytta VLAN 30 till en egen zon.

**Åtgärd:** Skapa `Server`-zon (custom zone), flytta VLAN 30 dit — Phase 2A.

### G2 — DNS bypass via gateway öppen (HÖG)

`dig @192.168.30.1 pi.home.lan A` svarar `192.168.1.55` från HAOS. Befintliga
DNS-blockningsregler (`block-internal-gateway-dns-udp/tcp`) har
`matching_target: NETWORK` med `network_ids: [Default LAN, MLO-LAN]` — Server
VLAN 30:s network_id (`69ee65711bc6e72d27744844`) saknas. Resultat: VLAN 30
klienter kan använda UDR dnsmasq som DNS-resolver, kringgå Pi DNS.

**Åtgärd:** Lägg till DNS bypass-block för Server-zonen — Phase 2B regel F och G.

### G3 — `allow-haos-wiz-control` source zone bryts vid zon-flytt (KRITISK)

Regeln har `source.zone_id = 677d9959ed22014620a6a981` (Internal). När VLAN 30
flyttas till Server-zonen hamnar HAOS (`192.168.30.20`) utanför Internal-zonen
och regeln matchar inte längre. WiZ-styrning slutar fungera **omedelbart**
vid zon-flytten om inte regelns `source.zone_id` uppdateras till den nya
Server-zonens ID i samma operation.

**Åtgärd:** Uppdatera `allow-haos-wiz-control.source.zone_id` till ny Server-zon
ID i samma steg som zon-flytten — Phase 2A.

### G4 — Inga isoleringsregler Server → Default LAN (MEDIUM tills zone-flytt)

Eftersom båda nätverk är i Internal-zonen finns ingen möjlighet att blockera
Server VLAN 30 → Default LAN. Live-test visar att HAOS → Mac mini (ICMP) ger
100% förlust, men detta kan vara macOS-firewall. TCP-access till Proxmox UI
(8006), SSH (22) på Default LAN-enheter är sannolikt öppen.

**Åtgärd:** Lägg till `block-server-to-internal` (catch-all) efter specifika
ALLOW-regler — Phase 2B regel D.

### G5 — Server VLAN 30 WAN DNS bypass (MEDIUM)

HAOS → `@1.1.1.1:53` testades ej direkt från HAOS i detta pass, men Mac mini
(Default LAN) → `@1.1.1.1` timed out bekräftar att WAN DNS-block fungerar för
Default LAN. VLAN 30 saknar en motsvarande `block-server-wan-dns-udp/tcp`-regel.

**Åtgärd:** Lägg till WAN DNS bypass-block för Server-zonen — Phase 2B regel E.

---

## Nödvändiga trafikflöden

Dessa flöden måste bevaras efter isolering:

| Nr | Källa | Destination | Port/Protokoll | Motivering |
|---|---|---|---|---|
| 1 | `192.168.30.0/24` | `192.168.1.55` | TCP+UDP 53 | Pi DNS — HAOS och framtida Docker VM |
| 2 | `192.168.30.0/24` | `192.168.30.1` | DHCP | Gateway — adress och standard-route |
| 3 | `192.168.30.0/24` | Internet/WAN | Alla (efter DNS-bypass-block) | HAOS uppdateringar, HA cloud, NTP |
| 4 | `192.168.1.0/24` (admin) | `192.168.30.20:8123` | TCP 8123 | HAOS UI från betrodda admin-enheter |
| 5 | `192.168.30.20` | `wiz-bulbs-ipv4` (IoT) | UDP 38899-38900 | WiZ-lampstyrning via HAOS |
| 6 | Established/related | — | — | Returtrafik (hanteras automatiskt av conntrack) |
| 7 | `192.168.1.0/24` → `.30.10` | `192.168.30.10` | SSH 22, HTTP/HTTPS 80/443 | **Framtida Docker VM 102 — ej aktivt** |

Flöden som ska blockeras:

| Nr | Källa | Destination | Port | Motivering |
|---|---|---|---|---|
| B1 | `192.168.30.0/24` | `192.168.1.0/24` (utom Pi DNS) | Alla | Isolera Server från Default LAN |
| B2 | `192.168.30.0/24` | `192.168.30.1` / `192.168.1.1` | TCP+UDP 53 | Gateway DNS bypass |
| B3 | `192.168.30.0/24` | WAN | TCP+UDP 53 | WAN DNS bypass |
| B4 | WAN inbound | `192.168.30.0/24` | Alla | Inga WAN port forwards till Server |

---

## Föreslagen zon-modell

### Nuläge

```
Internal-zon (677d9959ed22014620a6a981)
├── Default LAN (192.168.1.0/24)   ← admin, trusted
├── Server VLAN 30 (192.168.30.0/24)  ← ⚠️ delar zon med admin-LAN
└── MLO-LAN (192.168.40.0/24)      ← 6 GHz WiFi

IOT-zon (6980de97e060a06b8ef9b613)
└── IOT VLAN 10 (192.168.10.0/24)  ← WiZ-lampor, Roborock
```

### Målläge efter Phase 2A + 2B

```
Internal-zon (677d9959ed22014620a6a981)
├── Default LAN (192.168.1.0/24)   ← admin, trusted
└── MLO-LAN (192.168.40.0/24)      ← 6 GHz WiFi (oförändrad)

Server-zon (ny zon — ID okänd tills skapad)
└── Server VLAN 30 (192.168.30.0/24)  ← HAOS VM 101, framtida Docker VM 102

IOT-zon (6980de97e060a06b8ef9b613)
└── IOT VLAN 10 (192.168.10.0/24)  ← oförändrad
```

**Risk med zon-flytt:** När VLAN 30 flyttas från Internal till Server-zon
påverkas alla regler som refererar `zone_id = Internal` och matchar
`192.168.30.0/24` eller HAOS `192.168.30.20`. Den enda befintliga regeln som
brister är `allow-haos-wiz-control` — denna **måste** uppdateras i samma steg
som zon-flytten. Befintliga DNS-blockningsregler för Internal-zonen matchar
already via `network_ids` (ej ANY), så de påverkas inte.

En ny custom zone har sannolikt default-DROP för inter-zon-trafik (som IOT-zonen
vars trafik styrs av explicita regler). Verify default-policyn efter skapande,
innan zon-flytt genomförs.

---

## Föreslagna regler

### Phase 2A — Atomär operation: skapa zon + flytta VLAN + uppdatera WiZ-regel

Dessa tre steg måste utföras i ett sammanhängande godkänt fönster. Om steg 2 eller
3 missas bryts HAOS-anslutning eller WiZ-styrning direkt.

| Steg | Åtgärd | Motivering |
|---|---|---|
| 2A-1 | Skapa Server-zon (custom zone, `zone_key: ""`) | Förutsättning för VLAN-flytt |
| 2A-2 | Tilldela Server VLAN 30 (`69ee65711bc6e72d27744844`) till ny Server-zon | Aktiverar zon-baserad isolering |
| 2A-3 | Uppdatera `allow-haos-wiz-control` (`69f687011bc6e72d277674c3`) `source.zone_id` → ny Server-zon ID | Förhindrar att WiZ-styrning bryts |
| 2A-4 | Validera: HAOS UI nåbar, WiZ-lampor svarar på HA-dashboard | Bekräfta att ingen regression uppstod |

**Obs:** Beroende på UDR:s default-policy för ny custom zone kan HAOS förlora
anslutning till Pi DNS och Internet direkt vid zon-flytten. Rekommendation: skapa
ALLOW-regler (regel A–C nedan) **innan** VLAN 30 tilldelas ny zon, för att säkra
kontinuitet.

### Phase 2B — Isoleringsregler (efter 2A)

| Prioritet | Namn | Källa | Destination | Port | Åtgärd | Risk om saknas | Återställning |
|---|---|---|---|---|---|---|---|
| A | `allow-server-to-pi-dns-udp` | Server-zon ANY | Internal-zon IP `192.168.1.55` | UDP 53 | ALLOW | HAOS + Docker VM 102 kan inte lösa DNS | Ta bort regeln |
| B | `allow-server-to-pi-dns-tcp` | Server-zon ANY | Internal-zon IP `192.168.1.55` | TCP 53 | ALLOW | DNS fallback missar | Ta bort regeln |
| C | `allow-server-to-wan` | Server-zon ANY | External-zon ANY | Alla (utom port 53) | ALLOW | HAOS kan inte nå internet | Ta bort regeln |
| D | `allow-lan-admin-to-haos` | Internal-zon ANY | Server-zon IP `192.168.30.20` | TCP 8123 | ALLOW | Admin kan inte nå HAOS UI | Ta bort regeln |
| E | `block-server-wan-dns-udp` | Server-zon ANY | External-zon ANY | UDP 53 | BLOCK | HAOS kan kringgå Pi DNS mot WAN | Ta bort regeln |
| F | `block-server-wan-dns-tcp` | Server-zon ANY | External-zon ANY | TCP 53 | BLOCK | Se ovan | Ta bort regeln |
| G | `block-server-gateway-dns-udp` | Server-zon ANY | Gateway-zon IP `192.168.30.1` | UDP 53 | BLOCK | HAOS kan använda UDR dnsmasq | Ta bort regeln |
| H | `block-server-gateway-dns-tcp` | Server-zon ANY | Gateway-zon IP `192.168.30.1` | TCP 53 | BLOCK | Se ovan | Ta bort regeln |
| I | `block-server-to-internal` | Server-zon ANY | Internal-zon ANY | Alla | BLOCK | Server VLAN 30 kan nå Default LAN fritt | Ta bort regeln |

**Regelordning — kritisk:**

Regler tillämpas i stigande `rule_index`. Inom varje zon-par gäller:

```
Server → Internal:
  10000  allow-server-to-pi-dns-udp  (A)
  10001  allow-server-to-pi-dns-tcp  (B)
  10002  block-server-to-internal    (I) ← måste komma EFTER A och B

Server → External:
  10000  block-server-wan-dns-udp    (E) ← måste komma FÖRE C
  10001  block-server-wan-dns-tcp    (F)
  10002  allow-server-to-wan         (C)

Server → Gateway:
  10000  block-server-gateway-dns-udp (G)
  10001  block-server-gateway-dns-tcp (H)

Internal → Server:
  10000  allow-lan-admin-to-haos     (D)
```

### Befintliga regler — uppdateringar

| Regel | Nuläge | Åtgärd | Motivering |
|---|---|---|---|
| `allow-haos-wiz-control` (`69f687011bc6e72d277674c3`) | `source.zone_id = Internal` | Uppdatera `source.zone_id` → ny Server-zon ID | HAOS flyttas ut ur Internal-zonen |
| `allow-haos-wiz-icmp-temp` (`69f687011bc6e72d277674c6`) | Inaktiverad | Radera via UniFi UI | Temporär valideringsregel; inte längre behövd |

### Framtida regler — ej aktivera förrän VM 102 existerar

| Namn | Källa | Destination | Port | Åtgärd | Villkor |
|---|---|---|---|---|---|
| `allow-lan-admin-to-docker` | Internal-zon admin IPs | Server-zon IP `192.168.30.10` | TCP 22, 80, 443 | ALLOW | VM 102 live och validerad |

---

## WiZ / IoT flödesaudit

### Nuläge

`allow-haos-wiz-control` (`69f687011bc6e72d277674c3`) är aktiv och tillåter:
- Källa: HAOS `192.168.30.20` (Internal-zon)
- Destination: `wiz-bulbs-ipv4` (`192.168.10.129`, `.131`, `.133`, `.134`, `.174`) i IOT-zonen
- Protokoll: UDP 38899-38900
- `rule_index`: 10000

Live-test 2026-05-03 visar att ICMP till `192.168.10.129` blockeras (100%
förlust) — det är korrekt beteende eftersom `allow-haos-wiz-icmp-temp` är
inaktiverad. WiZ UDP-styrning (38899-38900) testades inte direkt men HAOS
dashboard visar 5 WiZ-enheter, 20 entities, 0 missing areas — WiZ-integration
fungerar.

### Risk vid zon-flytt

Efter Phase 2A måste `allow-haos-wiz-control.source.zone_id` uppdateras till
den nya Server-zonens ID. Om detta missas tappar HAOS WiZ-styrning direkt.

### Ytterligare WiZ-flöden att verifiera

WiZ-lampor (IoT VLAN 10) kan skicka status-callbacks tillbaka till HAOS:

| Flöde | Port | Status |
|---|---|---|
| HAOS → WiZ (styrning) | UDP 38899 | ✅ Tillåten via `allow-haos-wiz-control` |
| HAOS → WiZ (discovery) | UDP 38900 | ✅ Tillåten via `allow-haos-wiz-control` |
| WiZ → HAOS (callback) | UDP — källport 38899-38900 → HAOS | ⚠️ Beroende av conntrack ESTABLISHED; explicit ALLOW saknas |

Conntrack hanterar established/related return traffic automatiskt i UniFi
zone-based firewall. WiZ-callbacks faller sannolikt under ESTABLISHED-regeln.
Verifiera i HAOS loggar efter Phase 2A att WiZ-lampstatus fortfarande
uppdateras.

---

## Valideringsplan

Utförs read-only efter Phase 2A och 2B. Inga ändringar.

### Efter Phase 2A (zon-flytt)

| Test | Förväntat | Metod |
|---|---|---|
| HAOS UI nåbar från Default LAN | ✅ HTTP 200 `http://192.168.30.20:8123` | `nc -vz 192.168.30.20 8123` från Mac mini |
| HAOS → Pi DNS | ✅ Svarar | `ssh ha 'dig @192.168.1.55 pi.home.lan A +short'` |
| HAOS → Internet | ✅ ICMP pass | `ssh ha 'ping -c2 1.1.1.1'` |
| WiZ-enheter synliga i HAOS | ✅ 5 devices, 20 entities | HAOS dashboard kontroll |
| Proxmox host `192.168.1.60` nåbar | ✅ SSH pass | `ssh opti 'uptime'` |
| Pi DNS `192.168.1.55` healthy | ✅ AdGuard OK | `ssh pi 'systemctl is-active AdGuardHome'` |

### Efter Phase 2B (isoleringsregler)

| Test | Förväntat | Metod |
|---|---|---|
| HAOS UI från Default LAN | ✅ HTTP 200 | `nc -vz 192.168.30.20 8123` från Mac mini |
| HAOS → Pi DNS (TCP+UDP 53) | ✅ Svarar | `ssh ha 'dig @192.168.1.55 pi.home.lan A +short'` |
| HAOS → Internet | ✅ ICMP pass | `ssh ha 'ping -c2 1.1.1.1'` |
| HAOS → gateway DNS `@192.168.30.1` | ❌ Timeout (blockad) | `ssh ha 'dig @192.168.30.1 pi.home.lan A +short +time=2 +tries=1'` |
| HAOS → WAN DNS `@1.1.1.1:53` | ❌ Timeout (blockad) | `ssh ha 'dig @1.1.1.1 cloudflare.com A +short +time=2 +tries=1'` |
| HAOS → Default LAN arbitrary (`192.168.1.86`) | ❌ Timeout/drop | `ssh ha 'nc -vz -w3 192.168.1.86 22'` |
| HAOS → Proxmox UI `192.168.1.60:8006` | ❌ Timeout/drop | `ssh ha 'nc -vz -w3 192.168.1.60 8006'` |
| Default LAN → HAOS `192.168.30.20:8123` | ✅ Succeed | `nc -vz 192.168.30.20 8123` från Mac mini |
| WiZ-styrning | ✅ 5 devices aktiva | HAOS dashboard |

---

## Återställningsplan

### Om Phase 2A orsakar avbrott

```bash
# 1. Flytta Server VLAN 30 tillbaka till Internal-zonen via UniFi UI eller API
#    UniFi: Settings → Networks → Server → Firewall Zone → Internal

# 2. Återställ allow-haos-wiz-control source.zone_id till Internal:
#    Settings → Security → Traffic & Firewall Rules → allow-haos-wiz-control
#    Source zone → Internal

# 3. Validera:
nc -vz 192.168.30.20 8123
ssh ha 'dig @192.168.1.55 pi.home.lan A +short'
```

### Om Phase 2B orsakar DNS-avbrott för HAOS

```bash
# Inaktivera block-server-to-internal och block-server-gateway-dns-* via UniFi UI
# Settings → Security → Traffic & Firewall Rules → togglea av

# Validera:
ssh ha 'dig @192.168.1.55 pi.home.lan A +short'
```

### Om WiZ-styrning bryts

```bash
# Verifiera att allow-haos-wiz-control.source.zone_id är ny Server-zon ID
# Om ej: uppdatera source.zone_id → ny Server-zon ID

# HAOS Developer Tools → Template:
# {{ states('light.kitchen') }}
# Kontrollera att entities är tillgängliga
```

---

## Godkännandeblock

---

### [APPROVAL REQUIRED] GO unifi-server-zone-create Phase 2A

```
Action:   1. Skapa Server-zon (custom zone) i UniFi Network
          2. Pre-skapa ALLOW-regler: Server→Internal (Pi DNS), Server→External (WAN),
             Internal→Server (HAOS 8123)
          3. Flytta Server VLAN 30 (69ee65711bc6e72d27744844) till ny Server-zon
          4. Uppdatera allow-haos-wiz-control (69f687011bc6e72d277674c3)
             source.zone_id → ny Server-zon ID

Reason:   Server VLAN 30 och Default LAN delar idag Internal-zonen. Zon-baserade
          inter-VLAN-regler kan inte tillämpas förrän VLAN 30 har en dedikerad zon.

Risk:     HÖG om steg 4 missas — WiZ-styrning bryts omedelbart.
          MEDIUM om steg 2 (pre-ALLOW-regler) missas — HAOS kan tappa DNS och
          internet beroende på ny zons default-policy.
          MITIGERAT AV:
          - Pre-skapa ALLOW-regler (steg 2) innan VLAN-flytt (steg 3)
          - HAOS SSH öppen under hela ändringen för validering
          - Steg 4 (WiZ-regel) körs direkt efter steg 3 i samma session

Rollback: Flytta Server VLAN 30 tillbaka till Internal-zonen.
          Återställ allow-haos-wiz-control.source.zone_id → 677d9959ed22014620a6a981 (Internal).
          Validera: nc -vz 192.168.30.20 8123 + ssh ha 'dig @192.168.1.55 ...'

Kräver innan GO:
  - HAOS SSH session öppen
  - UniFi UI dashboard synlig
  - DNS och HAOS UI bekräftade live precis innan
  - Phase 2B regler (se nedan) förberedda men ej aktiverade
```

---

### [APPROVAL REQUIRED] GO unifi-server-isolation-rules Phase 2B

```
Action:   Lägg till zone-policies för Server-zonen:
          A. allow-server-to-pi-dns-udp   Server→Internal IP 192.168.1.55  UDP 53  ALLOW
          B. allow-server-to-pi-dns-tcp   Server→Internal IP 192.168.1.55  TCP 53  ALLOW
          C. allow-server-to-wan          Server→External ANY               Alla    ALLOW
          D. allow-lan-admin-to-haos      Internal→Server  IP 192.168.30.20  TCP 8123  ALLOW
          E. block-server-wan-dns-udp     Server→External  ANY              UDP 53  BLOCK
          F. block-server-wan-dns-tcp     Server→External  ANY              TCP 53  BLOCK
          G. block-server-gateway-dns-udp Server→Gateway   IP 192.168.30.1  UDP 53  BLOCK
          H. block-server-gateway-dns-tcp Server→Gateway   IP 192.168.30.1  TCP 53  BLOCK
          I. block-server-to-internal     Server→Internal  ANY              Alla    BLOCK

          Regelordning (rule_index):
          Server→Internal:  A=10000, B=10001, I=10002
          Server→External:  E=10000, F=10001, C=10002
          Server→Gateway:   G=10000, H=10001
          Internal→Server:  D=10000

          Radera: allow-haos-wiz-icmp-temp (69f687011bc6e72d277674c6) — temporär regel

Reason:   Stänga DNS bypass-gapen (G2, G5) och isolera Server VLAN 30 från
          Default LAN (G4) medan nödvändig trafik bevaras.

Risk:     MEDIUM — fel regel_index-ordning kan blockera Pi DNS för HAOS.
          MITIGERAT AV:
          - Regler A+B skapas med lägre index än I
          - Regler E+F skapas med lägre index än C
          - SSH till HAOS hålls öppen under ändringen
          - Validera DNS direkt efter varje regel-grupp läggs till

Rollback: Inaktivera/radera de nya reglerna i omvänd ordning via UniFi UI.
          Börja med block-server-to-internal (I), sedan DNS-blocken (E-H).
          Validera: ssh ha 'dig @192.168.1.55 pi.home.lan A +short'

Valideringschecklista:
  [ ] HAOS → @192.168.1.55:53 — PASS
  [ ] HAOS → 1.1.1.1 ICMP — PASS
  [ ] HAOS → @192.168.30.1:53 — TIMEOUT (blockad)
  [ ] HAOS → @1.1.1.1:53 — TIMEOUT (blockad)
  [ ] nc -vz 192.168.30.20 8123 från Mac mini — PASS
  [ ] HAOS → 192.168.1.86:22 — TIMEOUT/DROP (blockad)
  [ ] WiZ — 5 devices aktiva i HAOS dashboard

Kräver innan GO:
  - Phase 2A genomförd och validerad
  - HAOS UI nåbar, DNS fungerar
  - Server-zon ID känd
```

---

### [APPROVAL REQUIRED] GO unifi-wiz-haos-flow-audit

```
Action:   Read-only audit av WiZ ↔ HAOS trafikflöden efter Phase 2A + 2B.
          Verifiera att:
          - WiZ UDP 38899-38900 (HAOS → WiZ) fortfarande fungerar
          - WiZ status-callbacks (WiZ → HAOS conntrack ESTABLISHED) fungerar
          - Inga WiZ-entiteter är unavailable i HAOS
          - allow-haos-wiz-icmp-temp är raderad

Reason:   WiZ-regeln byttes käll-zon vid Phase 2A. Conntrack-beteende för
          callback-trafik (IoT → Server) behöver verifieras i live-miljö.

Risk:     LÅG — read-only verifiering, inga ändringar.

Rollback: Om WiZ-entiteter är unavailable: verifiera att allow-haos-wiz-control
          source.zone_id = ny Server-zon ID och att rule_index=10000 i IOT-zonen.
          Om callback blockeras: lägg till explicit ALLOW IoT→Server
          IP 192.168.30.20 UDP källport 38899-38900 som komplement.

Kräver innan GO:
  - Phase 2A och 2B genomförda
  - Minst 10 minuter drift för att WiZ-callbacks ska synas
```

---

## Administrativa noter

- Docker VM 102 (`192.168.30.10`) är frånvarande. Inga regler för `.10` skapas
  förrän VM 102 existerar och är validerad.
- `allow-haos-wiz-icmp-temp` (`69f687011bc6e72d277674c6`) är inaktiverad och
  ska raderas via UniFi UI under Phase 2B.
- Proxmox host `192.168.1.60` på Default LAN berörs inte av zon-flytten.
  PVE-hostens firewall (`host.fw`) är separat och täcker redan enbart
  `192.168.1.0/24` inkommande.
- Inga ändringar av Pi, AdGuard, Unbound, Proxmox, HAOS, SSH, backups.
- Inga WAN port forwards berör VLAN 30. Bekräftat.
