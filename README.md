# infra

Infrastructure repo for the home network: DNS stack (Pi), config snapshots,
systemd units, and operational scripts.

## Hosts managed
- **Raspberry Pi 3** — AdGuard Home + Unbound (DNS authority)
- **Mac mini M1** — primary compute (`ssh mini`, 192.168.1.86)
- **MacBook Pro 2015** — Intel/OCLP, secondary host
- **UDR-7** — gateway, VLAN routing, zone-based firewall

## Layout
- `config/`     Service configs (AdGuardHome, Unbound, SSH)
- `systemd/`    Unit + timer files
- `scripts/`    Install / maintenance / backup scripts
- `docs/`       Runbooks, restore guides, agent templates
- `ansible/`    Optional automation (placeholder)
- `logs/`, `state/`  Local-only, gitignored

## Principles
- `AGENTS.md` is canonical policy for AI agents and repo operators.
- GitHub `Donkens/Infra` `main` is canonical for repo history, docs, scripts, and sanitized snapshots.
- Pi is the operational source of truth for live DNS service state.
- Mac repos are working copies.
- iCloud scripts may exist as operational/local script storage, but are not canonical repo source of truth.
- One DNS chain: AdGuard → Unbound → upstream — no splits
- Pi = stability > experiments. No Docker on Pi3, native systemd only.
- Scripts: portable, ARM/Intel-safe, no hardcoded secrets

## Agent instructions
See `AGENTS.md`. If this README and `AGENTS.md` differ, `AGENTS.md` wins.
