# Infra repo — kontext och audit 2026-04-28

> Genererat av Claude Code (Phase 0/1 audit).
> Syfte: ge en AI-assistent (ChatGPT eller annan) fullständig kontext om repot,
> infrastrukturen, nuläget och föreslagna förbättringar.
> Uppdatera datumet i filnamnet vid nästa audit.

---

## Översikt

**Repo:** `Donkens/Infra` (`github.com/Donkens/Infra`)
**Ägare:** Yasse
**Syfte:** Source-of-truth för hemma-infrastruktur — DNS-stack, VLAN, hosts, backups, automation och Opti/Proxmox-plan.

---

## Infrastruktur

### Hosts

| Host | Roll | IP | SSH | User | Repo-path |
|---|---|---|---|---|---|
| Raspberry Pi 3B+ | DNS-primär (AdGuard Home + Unbound) | `192.168.1.55` | `ssh pi` | `pi` | `/home/pi/repos/infra` (lowercase) |
| UDR-7 | Gateway, VLAN, firewall, WireGuard | `192.168.1.1` | `ssh udr` | `root` | — |
| Mac mini M1 | Primär admin/compute | `192.168.1.86` | `ssh mini` | `yasse` | `/Users/yasse/repos/Infra` |
| MacBook Pro 2015 | Sekundär admin | `192.168.1.78` | `ssh hd@mbp` | `hd` | `/Users/hd/repos/Infra` |
| Dell OptiPlex 7080 Micro | Proxmox hypervisor (planerad) | `192.168.1.60` | — | — | — |

> Pi repo-path är **lowercase** `/home/pi/repos/infra` — inte `Infra`.
> UDR SSH-user är `root`, inte `ubnt`.

### VLANs

| VLAN | Namn | Subnet | Roll | Status |
|---|---|---|---|---|
| untagged | Default LAN | `192.168.1.0/24` | Trusted LAN, Proxmox host-management | ✅ live |
| 10 | IOT | `192.168.10.0/24` | IoT-enheter | ✅ live |
| 20 | Guest | `192.168.20.0/24` | Gästnät | ⛔ disabled |
| 30 | Server | `192.168.30.0/24` | HAOS + Docker VM | ✅ live |
| 40 | MLO-LAN | `192.168.40.0/24` | 6 GHz WiFi-klienter | ✅ live |

### DNS-kedja

```
client
  └─► AdGuard Home (192.168.1.55:53, :443 DoH, :853 DoT)
        └─► Unbound (127.0.0.1:5335)
              └─► upstream (rekursiv/cache)
```

- **AdGuard Home:** filtering, blocklists, DNS rewrites för tjänste-namn (`.home.lan`).
- **Unbound:** rekursiv resolver, PTR-records och lokala A-records för infra-hosts, `local-zone: "home.lan." static`.
- **DNSSEC:** av (false). DDR: av (handle_ddr=false, sedan 2026-04-26).
- **Parallella resolvers:** förbjudna — en kedja endast.

### DNS-namn (inventory/dns-names.md)

| Namn | IP | Tjänst |
|---|---|---|
| `pi.home.lan` | `192.168.1.55` | Pi DNS-node |
| `opti.home.lan` / `proxmox.home.lan` | `192.168.1.60` | Proxmox host |
| `docker.home.lan` / `proxy.home.lan` | `192.168.30.10` | Docker VM / Caddy |
| `ha.home.lan` / `haos.home.lan` | `192.168.30.20` | Home Assistant OS |
| `dockge.home.lan` | `192.168.30.10` | Dockge via Caddy |
| `uptime.home.lan` | `192.168.30.10` | Uptime Kuma via Caddy |
| `dozzle.home.lan` | `192.168.30.10` | Dozzle via Caddy |
| `stremio.home.lan` | `192.168.30.10` | Stremio via Caddy |

### Opti / Proxmox / Docker / HAOS (planerad)

- **Opti** = Dell OptiPlex 7080 Micro, Proxmox VE, `192.168.1.60`, Default LAN.
- **VM 101** = HAOS, `192.168.30.20`, VLAN 30.
- **VM 102** = Debian Docker, `192.168.30.10`, VLAN 30.
- Caddy-proxy (VM 102) router intern `home.lan`-trafik.
- Dockge, Uptime Kuma, Dozzle, Stremio bakom Caddy.
- Vaultwarden: ej deploy förrän backup + restore-test är klart.
- Tailscale: ej initialt. WireGuard på UDR-7 är primärt.
- Jellyfin: ej initialt.

---

## Repo-struktur

```
inventory/      Maskinläsbar infradata: hosts, IP, VLAN, DNS, tjänster, identity-map
docs/           Bakgrund, policy, baselines, historiska snapshots
docs/opti/      Opti/Proxmox/HAOS/Docker planeringsdokument (00–90)
runbooks/       Steg-för-steg operativa guider
scripts/        Körbara scripts (backup, debug, install, maintenance)
caddy/          Caddy route-map och config-examples
config/         Saniterade config-snapshots (adguardhome, unbound, ssh, sysctl)
docker/         Docker compose examples och konventioner
proxmox/        Proxmox snippets och VM-docs
systemd/        Systemd units och timers
state/          Pi-lokal runtime-state — aldrig tracked (gitignore)
logs/           Pi-lokal logs — aldrig tracked (gitignore)
ansible/        Placeholder (tom)
AGENTS.md       Auktoritativ agent-policy — läs alltid denna först
```

---

## Agent-policy (AGENTS.md)

Alla AI-agenter och operatörer MÅSTE läsa `AGENTS.md` innan audit eller write.

Nyckelregler:
- **Phase 0** = read-only. Inga writes, commits, pushes.
- **Phase 1** = visa plan och exakta kommandon. Utför ej.
- **Phase 2** = utför ENBART efter explicit `GO`.
- Hard-blockade kommandon: `rm -rf *`, `git push --force`, `git reset --hard`, `sudo rm`, `DROP TABLE`, `git add -A`, `git add .`
- Kräver approval: `sudo`, writes utanför repo, `/etc/`, push till remote, `--force`.
- Svara på svenska (summaries, planering). Håll paths, kommandon och tekniska termer på originalspråk.
- Scripting standard: `set -euo pipefail`, `readonly SCRIPT_DIR`, `log()`, `die()`.

### Host-verifiering (OBLIGATORISK)

Innan audit eller write — kör och cross-checka mot `inventory/identity-map.md`:
```bash
hostname; whoami; id; echo "$HOME"; uname -a
cat ~/.machine-identity 2>/dev/null || echo "no identity file"
```
Om värden konfliktar: **stanna och rapportera**.

---

## Automation

Tre aktiva systemd-timers på Pi:

| Timer | Schema | Syfte | Risk |
|---|---|---|---|
| `dns-health.timer` | Var 10:e min | DNS-hälsokoll (AdGuard + Unbound) | LÅG |
| `backup-health.timer` | Var 12:e tim | Kontroll av backup-färskhet | LÅG |
| `infra-auto-sync.timer` | 03:00 nightly | Config-snapshot + git commit + push | HÖG |

`infra-auto-sync` staging-allowlist (enbart dessa paths auto-stagas):
- `config/adguardhome/AdGuardHome.summary.sanitized.yml`
- `config/adguardhome/README.md`
- `config/unbound/unbound.conf`
- `config/unbound/unbound.conf.d/*.conf`

---

## Säkerhets- och secrets-policy

- Inga secrets, privata nycklar, tokens, lösenord eller certifikat-privkeys i repot.
- Raw `AdGuardHome.yaml` får aldrig committas, printas eller pastas.
- `.gitignore` exkluderar: `*.key`, `*.pem`, `*.p12`, `.env`, `secrets/`, `state/backups/`, `logs/`.
- Saniterade summaries only i `config/adguardhome/`.
- Alla cert-paths dokumenteras (ej innehåll).

---

## Phase 0 Audit — Findings (2026-04-28)

### Gap 1 — DNS-auktoritetsmodellen odokumenterad som helhet (PRIORITET 1)

Nuläge: modellen är splittrad över `AGENTS.md`, `inventory/dns-names.md`, `config/unbound/unbound.conf.d/ptr-local.conf` och `docs/adguard-home-change-policy.md`. Inget enskilt dokument förklarar vem som äger vilka record-typer.

Konsekvens: AI-agenter måste läsa 4+ filer för att förstå authority-modellen. Risk för felaktiga parallella resolvers.

### Gap 2 — 5 scripts saknar `set -euo pipefail` (PRIORITET 2)

Per AGENTS.md scripting standard. Dessa har bara `set -u` eller ingenting:

| Script | Nuläge |
|---|---|
| `scripts/maintenance/dns-health-monitor.sh` | `set -u` |
| `scripts/maintenance/check-backups.sh` | `set -u` |
| `scripts/maintenance/dns-health-report.sh` | `set -u` |
| `scripts/maintenance/infra-status.sh` | `set -u` |
| `scripts/maintenance/unbound-mini-top.sh` | (ingenting) |

`dns-health-monitor.sh` och `check-backups.sh` körs av systemd-timers — pipe-fel kan passera obemärkt.

### Gap 3 — Dangling reference i `docs/automation.md` (PRIORITET 3)

Rad 155 refererar `docs/repo-analysis-dossier.md` — en fil som är explicit gitignorerad och aldrig existerar i repot. Länken är alltid bruten.

### Gap 4 — Duplicerade UniFi firewall state-dokument (PRIORITET 4)

`docs/unifi-firewall-state-2026-04-14.md` (50 rader) och `docs/unifi-firewall-state-2026-04-15.md` (84 rader) är överlappande. Oklart vilket som är auktoritativt current state.

### Gap 5 — `docs/runbook.md` saknar struktur (PRIORITET 5)

20-raders bash-cheat-sheet utan scenario-headers, approval-gate-reminder eller success criteria. Kontrasterar mot kvaliteten i `docs/adguard-home-change-policy.md` och `docs/restore.md`.

### Gap 6 — Firewall cross-reference saknas i `inventory/vlans.md` (PRIORITET 6)

VLAN 30 nämner "GO firewall step" utan länk till aktuellt firewall-state-dokument.

---

## Phase 1 — Föreslagen patch-plan

> Ej utförd. Kräver explicit `GO PHASE 2` för genomförande.

### Ändring 1 — Skapa `docs/dns-architecture.md` (ny fil)

**Why:** Ingen fil samlar DNS-auktoritetsmodellen.  
**Benefit:** Agenter förstår direkt vem som äger vad — minskar risk för parallella resolvers.  
**Risk:** Låg. Ny fil, inga befintliga filer ändras.  
**Innehåll:** DNS-kedja, AdGuard-roll, Unbound-roll (PTR + infra A-records), DNSSEC/DoT/DoH/DDR-status, source-of-truth per record-typ.

### Ändring 2 — `set -euo pipefail` i 5 maintenance scripts

**Why:** AGENTS.md standard. Systemd-timers kör dessa.  
**Benefit:** Pipe-fel avbryter script istället för att tyst fortsätta.  
**Risk:** Låg. Scripts är read-heavy diagnostics.  
**Files:** `dns-health-monitor.sh`, `check-backups.sh`, `dns-health-report.sh`, `infra-status.sh`, `unbound-mini-top.sh`  
**Change:** `set -u` → `set -euo pipefail` (eller lägg till om det saknas helt).

### Ändring 3 — Ta bort dangling reference i `docs/automation.md`

**Why:** Rad 155 pekar på gitignorerad fil.  
**Benefit:** Ingen bruten länk.  
**Risk:** Ingen.  
**Files:** `docs/automation.md` rad 155 — ta bort `- [Repo analysis dossier](repo-analysis-dossier.md)`.

### Ändring 4 — Markera `docs/unifi-firewall-state-2026-04-14.md` som superseded

**Why:** Två överlappande dokument, oklart vilket som gäller.  
**Benefit:** Tydlighet — `-04-15` är current state.  
**Risk:** Ingen.  
**Files:** `docs/unifi-firewall-state-2026-04-14.md` — lägg till superseded-notering under rubriken.

### Ändring 5 — Förbättra `docs/runbook.md` med minimal struktur

**Why:** Nuvarande fil är osäker att använda utan kontext om vilka kommandon som kräver approval.  
**Benefit:** Tydlig uppdelning read-only vs operator-only + reminder om AGENTS.md § SAFETY.  
**Risk:** Låg.  
**Files:** `docs/runbook.md` — lägg till section-headers och approval-gate-reminder.

### Ändring 6 — Firewall cross-reference i `inventory/vlans.md`

**Why:** VLAN 30 refererar "GO firewall step" utan länk.  
**Benefit:** Agenter hittar aktuellt firewall-state direkt från VLAN-inventariet.  
**Risk:** Ingen.  
**Files:** `inventory/vlans.md` — lägg till länk till `../docs/unifi-firewall-state-2026-04-15.md`.

---

## Approvals

För att köra alla 6 ändringar: `GO PHASE 2`  
För selektiva ändringar: `GO PHASE 2 ändringar 1 2 3`

---

*Fil skapad av Claude Code — Donkens/Infra audit 2026-04-28*
