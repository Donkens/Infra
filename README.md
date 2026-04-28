# infra

Infrastructure repo for the home network: DNS stack (Pi), config snapshots,
systemd units, and operational scripts.

## Start here

Current source-of-truth entry points:

- [Agent/operator policy](AGENTS.md)
- [Repo map](docs/repo-map.md)
- [DNS names](inventory/dns-names.md)
- [UniFi networks](inventory/unifi-networks.md)
- [UniFi firewall](inventory/unifi-firewall.md)
- [UniFi WiFi](inventory/unifi-wifi.md)
- [DHCP reservations](inventory/dhcp-reservations.md)
- [UDR-7 baseline](docs/udr7-baseline.md)
- [Network validation](docs/network-validation.md)
- [Open network checks](docs/open-network-checks.md)

## Hosts managed
- **Raspberry Pi 3** — AdGuard Home + Unbound (DNS authority)
- **Mac mini M1** — primary compute (`ssh mini`, 192.168.1.86)
- **MacBook Pro 2015** — Intel/OCLP, secondary host
- **UDR-7** — gateway, VLAN routing, zone-based firewall

## Opti / Proxmox workspace
Planning docs for the Dell OptiPlex 7080 Micro live under `docs/opti/`.
Start with [Opti baseline](docs/opti/00-baseline.md),
[IP plan](inventory/ip-plan.md), and
[Phase 0 checklist](runbooks/opti-phase-0.md).

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
