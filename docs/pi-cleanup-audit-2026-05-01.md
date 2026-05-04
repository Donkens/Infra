# Pi DNS Node — Safe Cleanup Audit (Phase 0–5)

**Datum:** 2026-05-01
**Audit-typ:** Read-only (Phase 0). Inga ändringar gjorda.
**Operatör:** Claude Cowork (kör SSH från `mbp` → `pi` / `mini`)
**Begränsning:** Inga deletes, inga service-restarts, ingen sudo-write.

---

## 1. Executive Summary

Pi:n är frisk och inte hårt belastad: **17 % disk** använt på SD-kortets root (4,5 GB av 29 GB), 555 Mi RAM tillgängligt, uptime 3 d 21 h, AdGuardHome + Unbound aktiva, alla timers grönt, off-Pi backup synkad i natt 04:30. Ingenting måste städas akut.

Tre kategorier sticker ut som städbara utan operativ risk:

| # | Kategori | Påverkan | Risk |
| - | -------- | -------- | ---- |
| 1 | `~/.vscode-server` (721 M) — två gamla server-versioner kvarlevande | -350 M | LOW efter VSCode-omstart |
| 2 | `~/.claude/remote/ccd-cli/2.1.87` (218 M) — gammal Claude Code-CLI | -218 M om ej använd | LOW |
| 3 | `/var/cache/apt` (154 M) + swcatalog (18 M) — regenererbar paket-cache | -170 M | LOW |

I `state/backups/` finns **55 backup-dirs**. `prune-dns-backups.sh` (dry-run kör jag nedan) säger att **5 av dem ligger utanför 45-dagars retention** och kan tas bort utan att bryta `latest`-symlinken eller min-keep=10. Total vinst där är `<1 MB`; pengen är inte i backup-mappen, den är i utvecklarverktygen.

Värda att besluta manuellt: `cockpit.service` kör (om du inte använder Cockpit web-UI är det rimligt att stoppa+disable), ett pre-update binärt AdGuard-backup `agh-backup/AdGuardHome` (32 M, daterat 2026-03-11), och två "stray" manual-backups i `/home/pi/` rotad.

**Total realistisk vinst om allt LOW genomförs:** ~750–800 M (mest VSCode + ccd-cli + apt-cache). Ingenting av detta är operativt kritiskt.

---

## 2. Disk Usage Overview

```
df -h /
Filsystem      Storlek Använt Ledigt Anv% Monterat på
/dev/mmcblk0p2     29G   4,5G    24G  17% /

free -h
              totalt      använt       fritt       delat  buff/cache
Minne:         905Mi       350Mi       104Mi       8,8Mi       474Mi  (avail: 555Mi)

uptime: 10:10:29 up 3 days, 21:10, load 0,00 0,00 0,00
journalctl --disk-usage: 7.6M
```

**Inga inode-problem** (5 % på root). Swap använd 512 K (zram). `/tmp` är tmpfs (152K använt). Diskbild stabil.

### Top-level på root (`du / -d 1`)

| Path | Storlek |
| ---- | ------: |
| `/usr` | 1,7 G |
| `/var` | 1,3 G |
| `/home` | 1,1 G |
| `/root` | 561 M |
| `/boot` | 40 M |
| `/etc` | 5,2 M |

### `/home/pi` breakdown

| Path | Storlek | Anteckning |
| ---- | ------: | ---------- |
| `.vscode-server` | **721 M** | Två CLI-server-versioner + extensions |
| `.claude` | **230 M** | mest `remote/ccd-cli/2.1.87` |
| `AdGuardHome` | 76 M | inkl. 31 M `agh-backup` (gammalt binär) |
| `repos` | 15 M | `infra` repo |
| `.dotnet` | 248 K | bara `corefx`-stub, oklart varför installerat |
| `bin`, `.config`, `.ssh`, `.cache`, `.local` | <100 K vardera | normalt |
| `sudoers-backup-20260426-223819` | 8 K | manual leftover |
| `systemd-unit-backups-20260428-212025` | 12 K | manual leftover (refererad i docs) |

---

## 3. Största enskilda filer (>10 M)

```
228M  /home/pi/.claude/remote/ccd-cli/2.1.87                                 (binär, 2026-03-30)
122M  /home/pi/.vscode-server/cli/servers/Stable-cfbea10c.../server/node     (2026-03-04)  ← gammal
122M  /home/pi/.vscode-server/cli/servers/Stable-41dd792b.../server/node     (2026-03-04)  ← duplicate
68M   /var/cache/apt/srcpkgcache.bin                                          (regenererbar)
68M   /var/cache/apt/pkgcache.bin                                             (regenererbar)
55M   /home/pi/.vscode-server/extensions/timonwong.shellcheck-0.39.2.../shellcheck
36M   /home/pi/.vscode-server/extensions/tamasfe.even-better-toml-0.21.2/.../server.js
36M   /home/pi/.vscode-server/extensions/tamasfe.even-better-toml-0.21.2/.../server-worker.js
32M   /home/pi/AdGuardHome/agh-backup/AdGuardHome                             (gammal binär 2026-03-11)
32M   /home/pi/AdGuardHome/AdGuardHome                                        (live, 2026-04-17)
26M   /home/pi/.vscode-server/code-cfbea10c... / code-41dd792b...
13M   /var/cache/apt/archives/raspi-firmware_*.deb                            (.deb redan installerad)
```

Två oberoende **Stable-`<commit-sha>`** under `.vscode-server/cli/servers/` — det är två olika VSCode-versioner som connectat in. Den gamla används inte längre. Tillsammans är de 350 M+ av identisk Node.js-runtime.

---

## 4. Backups på Pi

### `state/backups` (managed)

55 dirs + 1 symlink (`latest` -> `dns-backup-20260501_030452`). 7.7 M totalt. Range 2026-03-12 → 2026-05-01.

`prune-dns-backups.sh` (read-only dry-run, körd nu):

```
backup_dir=/home/pi/repos/infra/state/backups
mode=dry-run | retention_days=45 | min_keep=10
total_backups=55  candidates=5
preserved_latest_target=.../dns-backup-20260501_030452
DRY-RUN would remove:
  dns-backup-20260316_030154
  dns-backup-20260315_030104
  dns-backup-20260314_030024
  dns-backup-20260313_030024
  dns-backup-20260312_030214
```

Allt managed via timer + script. Inga manuella änd­ringar behövs här utöver att eventuellt köra `--apply`.

### Manuella snapshots i samma katalog

`dns-backup-20260413_105638`, `_110428` (~1 h isär)
`dns-backup-20260427_201909`, `_202053` (~2 min isär)

Ingen funktionell skada, men de duplicerade snapshotsen sparar nästan inget och stör retention-räkningen marginellt. NEEDS MANUAL REVIEW.

### Stray "manual" backups i `/home/pi`

| Path | Innehåll | Refererad? |
| ---- | -------- | ---------- |
| `/home/pi/sudoers-backup-20260426-223819/` | 1 fil `pi-diagnostics` (671 B) | **Nej** (ingen träff i repo) |
| `/home/pi/systemd-unit-backups-20260428-212025/` | `dns-health.service`, `backup-health.service` | **Ja** — `docs/health-rollout-2026-04-28.md` har stigen hårdkodad i sin runbook |

### AdGuard pre-update binär backup

`/home/pi/AdGuardHome/agh-backup/AdGuardHome` — 32 M binär från 2026-03-11. Den nuvarande är från 2026-04-17. Ingen referens till `agh-backup` i repo. Sannolikt skapad manuellt vid en uppdatering som rollback-target.

### `.claude.json` backups

5 stycken (`backups/.claude.json.backup.17720*`) från 2026-02-25/26 — Claude desktop genererade automatiskt vid migrering. ~13 K totalt.

### Övriga `.old`-filer

| Path | Datum | Anteckning |
| ---- | ----- | ---------- |
| `/home/pi/.ssh/known_hosts.old` | 2025-12-02 | gammal known_hosts före auto-write |
| `/home/pi/AdGuardHome/data/filters/1764554713.txt.old` | 2026-01-14 | filter-snapshot ersatt |
| `/var/lib/unbound/root.key.broken-1764521099` | 2025-11-30 | misslyckad root-key uppdatering, ersatt |
| `/var/cache/debconf/templates.dat-old`, `config.dat-old` | 2026-04-10 | debconf migration leftover (~1.9 M) |

---

## 5. Loggar

`/var/log` totalt **940 K** — extremt rent. Logrotate fungerar.

Repo-loggar:

| Path | Storlek |
| ---- | ------: |
| `/home/pi/repos/infra/logs/backup-health.log` | 28 K (145 rader, från 2026-02-23) |
| `/home/pi/repos/infra/logs/dns-health.log` | <100 K |
| `/home/pi/repos/infra/logs/dns-health-fail.log` | 129 B (sista entry 2026-03-15) |
| `/home/pi/repos/infra/logs/dns-health.log.1.gz` | rotated |

Gamla `>30d` loggar i `/var/log` (icke-uttömmande):

```
2025-11-24  /var/log/bootstrap.log               (0 byte — kan tas bort eller lämnas)
2026-02-03  /var/log/cloud-init.log.1.gz         (113 K)
2026-03-02  /var/log/cloud-init.log              (336 K)
2026-03-02  /var/log/cloud-init-output.log       (40 K)
+ alla *.gz från logrotate (apt, dpkg, alternatives, unattended-upgrades) — managed
```

**`cloud-init*` loggar (~470 K)** härstammar från första-boot. Inte längre relevanta. Allt annat i `/var/log` hanteras av `logrotate.timer` och behöver inget manuellt ingrepp.

---

## 6. Cache & Temp

| Path | Storlek | Status |
| ---- | ------: | ------ |
| `/var/cache/apt/archives` | 23 M | Regenererbar — `apt-get clean` |
| `/var/cache/apt/pkgcache.bin` | 66 M | Regenererbar — `apt-get clean` |
| `/var/cache/apt/srcpkgcache.bin` | 66 M | Regenererbar — `apt-get clean` |
| `/var/cache/swcatalog/cache/*.xb` | 18 M | Regenererbar (PackageKit) |
| `/var/cache/man` | 1.8 M | Regenererbar (`mandb`) |
| `/var/cache/cracklib` | 464 K | KEEP (PAM password-validering) |
| `/var/cache/debconf/templates.dat-old` | 1.8 M | Migration leftover |
| `/home/pi/.cache/zsh/zcompdump` | 50 K | Regenererbar |
| `/home/pi/.cache/Microsoft/DeveloperTools/deviceid` | 36 B | Microsoft-tool leftover |
| `/tmp/*` | 152 K | systemd-managed (tmpfs, försvinner vid reboot) |
| `/var/tmp/systemd-private-*` | 36 K | systemd-managed |

`apt autoremove` säger 0 paket att ta bort. `dpkg -l | awk '/^rc/'` ger **`rpi-connect-lite`** kvar i config-only-state efter avinstall.

Notera **`shellcheck_0.10.0-1_arm64.deb` (4.9 M, 2024-03-17)** ligger fortfarande i `/var/cache/apt/archives`. En `apt-get clean` rensar den.

---

## 7. Repo-restfiler

```
find /home/pi/repos/infra -type f \( -iname '*.bak' -o -iname '*.old' \
  -o -iname '*.save' -o -iname '*.orig' -o -iname '*~' -o -iname '*.tmp' \
  -o -iname '*.swp' \) -not -path './.git/*'
```

**Ingen träff.** Repo-trädet är rent från restfiler.

---

## 8. Paket / tjänster som potentiellt är bloat

| Item | Status | Kommentar |
| ---- | ------ | --------- |
| `cockpit.service` + `cockpit.socket` + `cockpit-wsinstance-*` | running, enabled | Web-admin på :9090 — bara värt att behålla om du faktiskt använder web-UI:t. Tar några MB + processer + öppnar TLS-port. |
| `rpi-connect-lite` (rc-state) | bara konfig kvar | Avinstallerad men config-files ligger kvar. `apt-get purge` rensar. |
| `unattended-upgrades` | enabled | Säkerhetsuppdateringar — KEEP |
| `udisks2.service` | running | Disk-management D-Bus — Pi behöver det för `lsblk` etc. KEEP såvida du inte vill skala bort. |
| `.dotnet/corefx` (12 K i `/home/pi`) | inerter | Verkar vara stub från ett vscode-extension-installation. Helt orefererat i repo. SAFE TO REVIEW. |
| 667 paket installerade | normalt för trixie + AGH | Inget systematiskt bloat-mönster |

`apt list --installed` har inga uppenbara orelaterade desktop-paket. Pi:n är hyfsat slimmad.

---

## 9. Dependency Check — vad används?

Live-services och timers från `systemctl`:

```
running services:
  AdGuardHome.service        (live)
  unbound.service            (live)
  cockpit*                    (live)  ← se ovan
  + standard-systemd

active timers (next/last):
  dns-health.timer            10 min loop      → dns-health-monitor.sh
  backup-health.timer         12 h loop        → check-backups.sh
  pi-io-watch.timer           30 min override  → /usr/local/bin/pi-io-watch.sh
  infra-auto-sync.timer       nightly 03:00   → /usr/local/bin/infra-auto-sync.sh
  apt-daily / apt-daily-upgrade / logrotate / fstrim / dpkg-db-backup / man-db
  e2scrub_all / rpi-zram-writeback / systemd-tmpfiles-clean
```

Senaste health-checks (read-only):

```
state/dns-health.last:    [2026-05-01 10:03:50] status=OK adguard=active unbound=active q53=OK q5335=OK
state/backup-health.last: [2026-05-01 09:23:00] status=OK backups=55 age_h=6 latest=dns-backup-20260501_030452 manifest=ok sha256=ok
```

Repo-grep efter referenser till städkandidaterna:

| Kandidat | Refererad i repo? | Beslut |
| -------- | ----------------- | ------ |
| `state/backups/*` | Tjänster (`check-backups.sh`, `prune-dns-backups.sh`, `sync-pi-dns-backups-offpi.sh`), AGENTS.md, automation.md, runbook.md, security-boundaries.md, restore.md | **DO NOT TOUCH manuellt — använd prune-script** |
| `state/backups/latest` (symlink) | Refererad i prune + sync + runbook | **DO NOT TOUCH** |
| `agh-backup` | **Ingen träff** i repo | SAFE TO ARCHIVE |
| `sudoers-backup-20260426-223819` | **Ingen träff** | SAFE TO DELETE (innehåller endast `pi-diagnostics`) |
| `systemd-unit-backups-20260428-212025` | Refereras i `docs/health-rollout-2026-04-28.md` (rollback-stigar) | NEEDS MANUAL REVIEW (uppdatera doc först eller arkivera tillsammans) |
| `cloud-init.log*` | Ingen träff | SAFE TO DELETE |
| `shellcheck_0.10.0-1_arm64.deb` | apt-cache | SAFE (`apt-get clean`) |
| `root.key.broken-1764521099` | Ingen träff | SAFE TO DELETE |
| `.vscode-server`, `.claude/remote` | Inga träffar (ej tracked) | LOW risk att rensa cache |

---

## 10. Off-Pi Backup på Mac mini

```
host: mini  (Darwin 25.5.0 arm64)
target: /Users/yasse/InfraBackups/pi-dns-backups.sparsebundle
sparsebundle:  band-size=8388608, virtual=2 GiB, faktisk=54 M (8 bands)
mounted:       /dev/disk5s1 -> /Volumes/pi-dns-backups (apfs, noowners)
volume use:    6.3 M (struktur: /Volumes/pi-dns-backups/pi/...)

launchd:       com.yasse.pi-dns-backups.offpi-sync (loaded)
plist:         ~/Library/LaunchAgents/com.yasse.pi-dns-backups.offpi-sync.plist
schedule:      StartCalendarInterval Hour=4 Minute=30 (daily 04:30)
program:       /Users/yasse/repos/Infra/scripts/maintenance/sync-pi-dns-backups-offpi.sh
logs:          ~/Library/Logs/pi-dns-backups/offpi-sync.{log,err.log,last}
last log mtime:    2026-05-01 04:30  ← senaste sync = idag morgon (frisk)
last band write:   2026-04-30 10:13  (data faktiskt skriven förra körningen)
```

**Status: Off-Pi backup är intakt och kör schemalagt.** Observation: senaste sync skapade ingen ny data på bands (last write 2026-04-30) — kan betyda att inget nytt fanns att skriva, vilket är OK med rsync-baserad sync mot färska Pi-backups. Värt att kolla i `offpi-sync.log` om du vill verifiera.

`offpi-sync.err.log` är 251 B, dvs ev. info-meddelanden men inte stora errors.

---

## 11. Repo-sync mellan hosts (för kontext)

| Host | HEAD | Status mot origin/main |
| ---- | ---- | ---------------------- |
| `pi`  | `3955825` (idag 03:04 nightly snapshot) | up-to-date |
| `mini`| `7dd5b17` | **behind 1** (saknar nattens snapshot) |
| `mbp` | `a117f4f` | **behind 3** |

Inga uncommitted changes på någon host. Inget kritiskt; bara kosmetiskt.

Origin har en extra branch `claude/analyze-repo-improvements-HJgo1` (mergad PR #11).

---

## 12. Riskklassad cleanup-tabell

| Path / item | Size | Age (dgr) | Category | Risk | Recommendation | Why |
| ----------- | ---: | --------: | -------- | ---- | -------------- | --- |
| `state/backups/dns-backup-20260312..20260316` (5 st) | ~520 K | 46–50 | Managed retention | LOW | DELETE via `prune-dns-backups.sh --apply` | Utanför 45-d retention, prune-script preserverar `latest` och min-keep=10 |
| `~/.vscode-server/cli/servers/Stable-cfbea10c…` | ~250 M | 58 | Dev-tool cache | LOW | ARCHIVE FIRST → DELETE | Ej längre använd VSCode-version. VSCode reinstaller på connect. |
| `~/.vscode-server/cli/servers/Stable-41dd792b…` | ~250 M | 24 | Dev-tool cache | LOW (verifiera senast använd) | REVIEW då DELETE | Den nyare av de två. Förmodligen aktiv om du använt Remote-SSH nyligen. |
| `~/.claude/remote/ccd-cli/2.1.87` | 218 M | 32 | Claude Code CLI | LOW (om ej används) | REVIEW → DELETE | Bara om du inte kör Claude Code direkt på Pi. |
| `~/.claude/backups/.claude.json.backup.17720*` (5 st) | ~13 K | 65 | App migration backup | LOW | DELETE | Claude-app gamla migration backups. |
| `~/.claude/session-env/*` (5 dirs, mest tomma) | ~20 K | varierande | Stale session | LOW | REVIEW | Kan ha aktiva refs i `~/.claude/projects/`. |
| `/var/cache/apt/archives/*` (incl. shellcheck_0.10.0) | 23 M | upp till 770 | Apt cache | LOW | DELETE via `apt-get clean` | Standardprocedur, regenererbar. |
| `/var/cache/apt/{pkg,srcpkg}cache.bin` | 130 M | dagliga | Apt index | LOW | DELETE via `apt-get clean` | Regenererar vid nästa `apt update`. |
| `/var/cache/swcatalog/cache/*.xb` | 18 M | 16 | PackageKit cache | LOW | DELETE | Regenererbar. |
| `/var/cache/debconf/templates.dat-old`, `config.dat-old` | 1.9 M | 21 | Migration leftover | LOW | DELETE | Debconf migration backup; kan bort efter ~30 d. |
| `/var/log/cloud-init*` | 470 K | 60 | First-boot logs | LOW | DELETE | Bara relevant vid problem dagar efter init. |
| `/var/log/bootstrap.log` (0 byte) | 0 | 158 | First-boot log | LOW | DELETE | Tom fil från SD-imaging. |
| `/var/lib/unbound/root.key.broken-1764521099` | 1.3 K | 152 | Unbound rotnyckel-restavfall | LOW | DELETE | Trasig root.key från setup, ersatt. |
| `/home/pi/.ssh/known_hosts.old` | 1.1 K | 150 | SSH known-hosts backup | LOW | DELETE | Gammal kopia. |
| `/home/pi/AdGuardHome/data/filters/1764554713.txt.old` | 122 B | 107 | Filter-snapshot | LOW | DELETE | Ersatt blocklist-fil. |
| `/home/pi/.cache/zsh/zcompdump` | 50 K | 81 | zsh completion cache | LOW | DELETE (regenererar) | Onödig att städa men säkert. |
| `/home/pi/.cache/Microsoft/DeveloperTools/deviceid` | 36 B | 81 | MS DevTool leftover | LOW | DELETE | Skräp från ett gammalt vscode-extension. |
| `/home/pi/sudoers-backup-20260426-223819/` | 8 K | 5 | Manual leftover | LOW | DELETE (efter att kolla `pi-diagnostics`) | Ingen referens i repo. Filen `pi-diagnostics` är 671 B, kontrollera innehåll först. |
| `/home/pi/systemd-unit-backups-20260428-212025/` | 12 K | 3 | Manual rollback | MEDIUM | ARCHIVE FIRST | `docs/health-rollout-2026-04-28.md` refererar till stigen. Uppdatera doc innan delete eller flytta tillsammans. |
| `/home/pi/AdGuardHome/agh-backup/AdGuardHome` (binär) | 32 M | 51 | Pre-update binary | MEDIUM | ARCHIVE FIRST | Manuell rollback-target före AdGuardHome-uppgradering. Behåll om du kan tänkas vilja rulla tillbaka. |
| `dns-backup-20260413_105638`, `_110428` (1 h isär) | ~320 K | 18 | Duplicate manual | LOW | REVIEW | Två snapshots inom 1 h — kanske ena räcker. Inom retention. |
| `dns-backup-20260427_201909`, `_202053` (~2 min isär) | ~320 K | 4 | Duplicate manual | LOW | REVIEW | Två snapshots inom 2 min. Antagligen test-trigger. |
| `~/.dotnet/corefx` | 12 K | 30 | Stub install | LOW | REVIEW → DELETE | Ingen referens, oklart hur det hamnade. |
| `cockpit.service`/`cockpit.socket` | RAM/CPU | live | Web admin UI | MEDIUM | REVIEW | Stoppa+disable om du inte använder Cockpit på :9090. Ingen disk-vinst, men minskar attack-yta. |
| `rpi-connect-lite` (rc-state) | <1 K | varierande | Config-files only | LOW | DELETE via `apt-get purge` | Paket avinstallerat, bara config kvar. |
| `state/backups/` (managed) | 7.7 M | – | Live backup-state | CRITICAL | DO NOT TOUCH manuellt | Endast via `prune-dns-backups.sh`. |
| `state/backups/latest` symlink | – | – | Live ref | CRITICAL | DO NOT TOUCH | Refererad av check-script och off-Pi sync. |
| `/home/pi/AdGuardHome` (live state) | 76 M (ex. agh-backup) | – | Live AdGuard | CRITICAL | DO NOT TOUCH | Live filtreringstjänst. |
| `/etc/unbound`, `/var/lib/unbound/root.key`, `root.hints` | – | – | Live Unbound | CRITICAL | DO NOT TOUCH | Live resolver-state. |
| `~/.vscode-server/extensions/*` | 126 M | aktiv | Active extensions | KEEP (om VSCode used) | KEEP | Om du använder Remote-SSH i VSCode. |

**Risknivåer:** LOW = säkert | MEDIUM = arkivera först | HIGH = extra kontroll | CRITICAL = DO NOT TOUCH

---

## 13. Rekommenderad cleanup-plan (prioritetsordning)

1. **Tier 1 — Ren paket-cache** (ingen risk, störst förhållande vinst/risk):
   - `apt-get clean` → frigör ~150 M.
   - Tom debconf migration-leftovers (~2 M).

2. **Tier 2 — Hantera dev-tool cache**:
   - Inspektera vilken VSCode-server du använder, ta bort den oanvända (~250 M).
   - Inspektera om Claude Code CLI behövs på Pi; annars ta bort `~/.claude/remote/ccd-cli/2.1.87` (~218 M).
   - Tom `~/.claude/backups/.claude.json.backup.*` (~13 K).

3. **Tier 3 — Engångs first-boot/setup-rester**:
   - `/var/log/cloud-init*`, `/var/log/bootstrap.log`
   - `/var/lib/unbound/root.key.broken-*`
   - `/home/pi/.ssh/known_hosts.old`
   - AGH `*.txt.old` filter-rest

4. **Tier 4 — Manuella backup-rester** (efter granskning):
   - Verifiera innehåll i `/home/pi/sudoers-backup-20260426-223819/pi-diagnostics`, sedan delete.
   - Beslut om `agh-backup/AdGuardHome` (32 M binär) — keep eller arkivera off-Pi.
   - Beslut om `systemd-unit-backups-20260428-212025/` (uppdatera doc-referens om delete).

5. **Tier 5 — Managed prune** (separat, säker)
   - `prune-dns-backups.sh --apply` tar bort 5 dirs utanför 45-d retention. Symlink + min-keep skyddade.

6. **Tier 6 — Service review** (optional):
   - Bestäm om Cockpit ska köra. Om inte: `systemctl disable --now cockpit.socket cockpit.service`.
   - `apt-get purge rpi-connect-lite` (config-files only).

7. **Tier 7 — Repo sync** (kosmetiskt):
   - `git pull` på `mini` och `mbp` för att komma ifatt nattens snapshot.

Allt görs **bara efter** att du skriver `GO CLEANUP`. Phase 6 nedan listar exakta kommandon.

---

## 14. Phase 6 — Commands to run after `GO CLEANUP`

> **Förslag:** flytta osäkra kandidater till en quarantine-mapp först (`mv` istället för `rm`). Bara säker LOW-risk regenererbar cache rensas direkt.

### Steg 0 — Skapa quarantine + safety baseline

```bash
ssh pi 'mkdir -p ~/cleanup-quarantine-20260501 && \
        df -h / | tee ~/cleanup-quarantine-20260501/df-before.txt && \
        free -h | tee -a ~/cleanup-quarantine-20260501/df-before.txt && \
        date | tee -a ~/cleanup-quarantine-20260501/df-before.txt'
```

### Tier 1 — Apt cache + debconf leftovers (direkt delete; regenererbart)

```bash
ssh pi 'sudo apt-get clean'
ssh pi 'sudo rm -f /var/cache/debconf/templates.dat-old /var/cache/debconf/config.dat-old'
# swcatalog är PackageKit-managed — ej rekommenderat att radera manuellt; lämna.
```

### Tier 2 — Dev-tool caches (efter manuell verifiering)

```bash
# 1) Verifiera VSCode-server timestamps + vilket commit-id som är aktivt:
ssh pi 'ls -la ~/.vscode-server/cli/servers/'

# 2) (Efter granskning, om du inte använder den äldre Stable-cfbea10c... versionen)
ssh pi 'mv ~/.vscode-server/cli/servers/Stable-cfbea10c5ffb233ea9177d34726e6056e89913dc \
            ~/cleanup-quarantine-20260501/vscode-server-Stable-cfbea10c'

# 3) (Optionellt) Claude Code CLI om ej används direkt på Pi:
ssh pi 'mv ~/.claude/remote ~/cleanup-quarantine-20260501/claude-remote'

# 4) Gamla .claude.json migration backups (säker delete):
ssh pi 'mv ~/.claude/backups/.claude.json.backup.* ~/cleanup-quarantine-20260501/ 2>/dev/null'
```

### Tier 3 — First-boot/setup-rester

```bash
ssh pi 'sudo mv /var/log/cloud-init.log /var/log/cloud-init-output.log /var/log/cloud-init.log.1.gz \
                ~/cleanup-quarantine-20260501/ 2>/dev/null; \
        sudo mv /var/log/bootstrap.log ~/cleanup-quarantine-20260501/ 2>/dev/null'

ssh pi 'sudo mv /var/lib/unbound/root.key.broken-1764521099 ~/cleanup-quarantine-20260501/'
ssh pi 'mv ~/.ssh/known_hosts.old ~/cleanup-quarantine-20260501/'
ssh pi 'sudo mv /home/pi/AdGuardHome/data/filters/1764554713.txt.old ~/cleanup-quarantine-20260501/'
```

### Tier 4 — Manuella backup-rester (efter inspektion)

```bash
# Inspektera först:
ssh pi 'cat /home/pi/sudoers-backup-20260426-223819/pi-diagnostics'

# Sedan flytta (inte delete):
ssh pi 'mv /home/pi/sudoers-backup-20260426-223819 ~/cleanup-quarantine-20260501/'

# AdGuard agh-backup binär — ARKIVERA off-Pi först om du vill behålla rollback:
ssh pi 'mv /home/pi/AdGuardHome/agh-backup ~/cleanup-quarantine-20260501/agh-backup'
# (Kopiera ev. till mini om du vill behålla:)
# scp -r pi:~/cleanup-quarantine-20260501/agh-backup mini:/Users/yasse/InfraBackups/

# systemd-unit-backups: uppdatera doc-referens FÖRST, sedan flytta.
# (Inte i denna körning utan separat task.)
```

### Tier 5 — Managed DNS-backup prune (separat, kontrollerad)

```bash
# Dry-run igen för att se exakt vad som tas bort:
ssh pi 'sudo /home/pi/repos/infra/scripts/maintenance/prune-dns-backups.sh'

# Apply:
ssh pi 'sudo /home/pi/repos/infra/scripts/maintenance/prune-dns-backups.sh --apply'
```

### Tier 6 — Service review (optional, kräver separat beslut)

```bash
# Bara om du beslutat att stoppa Cockpit:
ssh pi 'sudo systemctl disable --now cockpit.socket cockpit.service'

# Purga rpi-connect-lite config-files:
ssh pi 'sudo apt-get purge -y rpi-connect-lite'
ssh pi 'sudo apt-get autoremove -y'   # bör inte ta bort något extra (verifierat: 0)
```

### Tier 7 — Repo-sync på Mac-hosts (kosmetiskt)

```bash
ssh mini 'cd /Users/yasse/repos/Infra && git pull --ff-only'
# På mbp (lokal):
cd /Users/hd/repos/Infra && git pull --ff-only
```

### Verifiering EFTER varje tier

```bash
ssh pi 'df -h / && free -h && \
        systemctl is-active AdGuardHome unbound dns-health.timer backup-health.timer && \
        dig @127.0.0.1 +time=2 +tries=1 pi.home.lan +short && \
        dig @127.0.0.1 +time=2 +tries=1 cloudflare.com +short | head -2 && \
        cd /home/pi/repos/infra && git status -sb'
```

Förväntat: `active`, IP för pi.home.lan, IP för cloudflare.com, repo clean. Om något felar: titta i `~/cleanup-quarantine-20260501/` för restore.

### Final cleanup (efter ~7 dagar utan problem)

```bash
ssh pi 'du -sh ~/cleanup-quarantine-20260501 && \
        # Backa upp innehållsförteckningen först:
        find ~/cleanup-quarantine-20260501 -type f > ~/cleanup-quarantine-20260501.manifest && \
        rm -rf ~/cleanup-quarantine-20260501'
```

---

## 15. Sammanfattning

Pi:n är **inte i kris**. Det finns rimliga vinster (~750 M) i devtool-caches och apt-cache, men ingenting brådskar. Den enda **infrastrukturellt riktiga** städningen är att låta `prune-dns-backups.sh --apply` köra för att hålla retention deterministiskt — den tar några hundra kB. Övriga vinster är hygien.

**Inget gjordes.** Allt ovan är förslag. Säg `GO CLEANUP` när du vill börja, och i vilken ordning (Tier 1 / 1+5 / "allt utom 6" etc.) — jag kan köra steg för steg med verifiering mellan.
