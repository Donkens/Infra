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
| `tune-dns-socket-buffers.sh` | Pi | Justera kernel socket-buffertar för DNS |

## maintenance/

| Script | Körs på | Syfte |
|---|---|---|
| `check-backups.sh` | Pi | Kontrollera backup-status |
| `dns-health-monitor.sh` | Pi | Kontinuerlig DNS-hälsokoll |
| `dns-health-report.sh` | Pi | Engångsrapport DNS-hälsa |
| `infra-status.sh` | Pi/Mac — verify before running | Samlad statusöversikt |
| `monitor-cpu.sh` | Pi | CPU-temperatur/belastning |
| `prune-dns-backups.sh` | Pi | Rensa gamla DNS-backuper (default: dry-run, 45 d, min 10). Kräver `--apply` för faktisk borttagning. |
| `unbound-mini-top.sh` | Pi | Realtidsvy Unbound-stats |
