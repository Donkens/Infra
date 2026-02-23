# infra (Pi)
This repo tracks Raspberry Pi infra (Pi3): DNS stack + systemd units + scripts.
## Layout
- config/        Service configs (AdGuardHome, Unbound, SSH)
- systemd/       Unit + timer files
- scripts/       Install/maintenance/backup scripts
- ansible/       Optional automation (inventory/playbooks/roles)
- docs/          Notes/runbooks
- logs/, state/  Local-only (gitignored)
## Principles
- Pi = infra (DNS) → stability > experiments
- Prefer native services + systemd (no Docker on Pi3)
