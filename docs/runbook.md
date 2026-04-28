# Pi DNS Runbook (AdGuard Home + Unbound)

> Kortkommando-referens för Pi DNS-noden.
> Policy för AdGuard-ändringar: [AdGuard Home change policy](adguard-home-change-policy.md).
> DNS-arkitektur och rollfördelning: [dns-architecture.md](dns-architecture.md).
> **Operator-only-kommandon kräver explicit `GO` — se `AGENTS.md § SAFETY`.**

## Read-only checks

Säkert att köra utan approval.

```bash
# Servicestatus
systemctl is-active AdGuardHome.service
systemctl is-active unbound.service

# DNS smoke-test
dig @127.0.0.1 google.com A +short
dig @127.0.0.1 -p 5335 google.com A +short
dig @192.168.1.55 google.com A +short

# Öppna portar (read-only via ss — kräver inte sudo)
ss -tulpn | grep -E ':(53|853|3000|443|5335)\b'
```

## Operator-only / approval required

Dessa kommandon ändrar service-state. Kräver explicit `GO` per `AGENTS.md § SAFETY`.

```bash
# Status (verbose)
sudo systemctl status AdGuardHome --no-pager
sudo systemctl status unbound --no-pager

# Restart
sudo systemctl restart AdGuardHome
sudo systemctl restart unbound

# Loggar
journalctl -u AdGuardHome -n 100 --no-pager
journalctl -u unbound -n 100 --no-pager

# Live-logg
journalctl -fu AdGuardHome
journalctl -fu unbound

# Portar (med sudo för fullständig vy)
sudo ss -tulpn | grep -E ':(53|80|3000)\b'
```

## DNS backup retention
Use `scripts/maintenance/prune-dns-backups.sh` to prune Pi-local DNS backups under `state/backups/`.

Default policy:
- Mode is `--dry-run`.
- `retention_days=45`.
- `min_keep=10`.
- Deletion requires explicit `--apply`.
- `state/backups/latest` and its target are preserved.
- Only direct child directories named `dns-backup-*` under the resolved `state/backups` path are eligible.

Operational usage:
```bash
cd /home/pi/repos/infra
bash scripts/maintenance/prune-dns-backups.sh --dry-run
sudo bash scripts/maintenance/prune-dns-backups.sh --apply
```

`sudo` is needed for `--apply` because backup directories may contain root-owned/read-protected raw backup files.

Safety:
- Inspect dry-run output before `--apply`.
- Do not use manual `rm`.
- Do not use `git clean`.
- Do not use broad `sudo chown` or `sudo chmod`.
- Do not print raw backup contents or config values.

Latest verified run:
- Date: 2026-04-26.
- Before: 70 backup directories.
- Removed: 22 backup directories.
- After: 48 backup directories.
- `state/backups/latest` target was preserved.
- Repo status was clean after apply.
