# Scripts

Scripts i detta repo körs primärt på **Pi** eller **Mac**.
Läs `AGENTS.md § ENVIRONMENT` för iCloud-sökvägar och symlink-policy innan du kör något.

> De flesta infra-scripts bor i iCloud, inte i detta repo.
> iCloud-paths (verifiera faktisk placering innan du redigerar):
> - `~/Library/Mobile Documents/com~apple~CloudDocs/Projects/scripts/`
> - `~/Library/Mobile Documents/com~apple~CloudDocs/Scripts/` (legacy)
>
> `~/bin` innehåller symlinkar in i dessa paths — duplicera inte.

## backup/

| Script | Körs på | Syfte |
|---|---|---|
| `backup-dns-configs.sh` | Pi | Säkerhetskopiera AdGuard Home + Unbound-config till `state/backups/` |
| `export-pi-dns-backups` | Pi | Least-privilege wrapper för read-only tar export av `/home/pi/repos/infra/state/backups` via `/usr/local/sbin/export-pi-dns-backups` |

## debug/

| Script | Körs på | Syfte |
|---|---|---|
| `debug-https-rr.sh` | Mac/Pi — verify before running | Debugga HTTPS DNS resource records |

## install/

| Script | Körs på | Syfte |
|---|---|---|
| `enable-extended-stats.sh` | Pi | Aktivera utökad Unbound-statistik |
| `infra-auto-sync-install.sh` | Pi | Installera auto-sync systemd timer på Pi (`/usr/local/bin/infra-auto-sync.sh`) |
| `infra-auto-sync.sh` | Pi | Körs av `infra-auto-sync.timer` — synkar repo-exports nightly |
| `install-pi-sudo-wrappers.sh` | Pi | Installerar root-owned wrappers till `/usr/local/sbin/` och exakt sudoers allowlist för `pi` |
| `tune-dns-socket-buffers.sh` | Pi | Justera kernel socket-buffertar för DNS |

## sudo-wrappers/

| Script | Körs på | Syfte |
|---|---|---|
| `infra-dns-status` | Pi via `/usr/local/sbin/` | Kompakt DNS/service/timer/log/disk-status |
| `infra-unbound-validate-reload` | Pi via `/usr/local/sbin/` | Validera Unbound config och reload `unbound` |
| `infra-dns-reload` | Pi via `/usr/local/sbin/` | Säker DNS reload path med smoke tests |
| `infra-dns-restart` | Pi via `/usr/local/sbin/` | Högre risk: restart `unbound` + `AdGuardHome`; kräver separat approval live |
| `infra-adguard-safe-restart` | Pi via `/usr/local/sbin/` | Högre risk: restart `AdGuardHome` utan att exponera raw config; kräver separat approval live |
| `infra-health-report` | Pi via `/usr/local/sbin/` | Kompakt agentvänlig health report |
| `infra-backup-health-check` | Pi via `/usr/local/sbin/` | Read-only backup health check |
| `infra-restore-drill-check` | Pi via `/usr/local/sbin/` | Read-only restore drill readiness check |

## maintenance/

| Script | Körs på | Syfte |
|---|---|---|
| `check-backups.sh` | Pi | Kontrollera backup-status |
| `check-dns-authority.sh` | Pi | Verifiera DNS authority-modellen: AdGuard forward, Unbound recursion/PTR |
| `dns-health-monitor.sh` | Pi | Kontinuerlig DNS-hälsokoll |
| `dns-health-report.sh` | Pi | Engångsrapport DNS-hälsa |
| `infra-status.sh` | Pi/Mac — verify before running | Samlad statusöversikt |
| `monitor-cpu.sh` | Pi | CPU-temperatur/belastning |
| `prune-dns-backups.sh` | Pi | Rensa gamla DNS-backuper (default: dry-run, 45 d, min 10). Kräver `--apply` för faktisk borttagning. |
| `docker-vm-backup.sh` | Docker VM 102 | Backup `/srv/compose` + `/srv/appdata` till `/srv/backups/docker-vm-102/`. Installerat som `/usr/local/sbin/docker-vm-backup` (root:root 755). Kör: `sudo /usr/local/sbin/docker-vm-backup`. SHA256-checksum inkluderat. Retention: 7 backups. Off-host: rsync till Mac mini `/Users/yasse/InfraBackups/docker-vm-102/`. |
| `sync-pi-dns-backups-offpi.sh` | Mac mini | Recurring off-Pi sync av Pi DNS backups till encrypted sparsebundle (`/Volumes/pi-dns-backups/pi/state-backups`) |
| `unbound-mini-top.sh` | Pi | Realtidsvy Unbound-stats |
