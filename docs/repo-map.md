# Repo map

> Which file owns what for agents and operators.

## Source-of-truth map

| Area | Source-of-truth | Notes |
|---|---|---|
| Agent/operator policy | [AGENTS.md](../AGENTS.md) | Canonical for agent behavior and safety gates. |
| Repo overview | [README.md](../README.md) | Human entry point; `AGENTS.md` wins on policy conflicts. |
| DNS names | [inventory/dns-names.md](../inventory/dns-names.md) | Important live and planned `home.lan` names. |
| DNS architecture | [docs/dns-architecture.md](dns-architecture.md) | Authority model: AdGuard, Unbound, UDR, Pi. |
| Pi runtime/DNS baseline | [docs/raspberry-pi-baseline.md](raspberry-pi-baseline.md) | Sanitized Pi DNS baseline. |
| UDR7 baseline | [docs/udr7-baseline.md](udr7-baseline.md) | Gateway/controller baseline. |
| UniFi networks/VLANs | [inventory/unifi-networks.md](../inventory/unifi-networks.md) | Current UniFi network inventory. |
| UniFi firewall | [inventory/unifi-firewall.md](../inventory/unifi-firewall.md) | Current custom firewall policy inventory. |
| UniFi WiFi/SSID | [inventory/unifi-wifi.md](../inventory/unifi-wifi.md) | Current WLAN/SSID inventory. |
| DHCP reservations | [inventory/dhcp-reservations.md](../inventory/dhcp-reservations.md) | Important fixed-IP reservations with masked MACs. |
| VLAN summary | [inventory/vlans.md](../inventory/vlans.md) | Compact VLAN summary; defer details to UniFi network inventory. |
| Services/ports | [inventory/services.md](../inventory/services.md) | Service status and port inventory. |
| Validation commands | [docs/network-validation.md](network-validation.md) | Read-only validation command set. |
| Open follow-ups | [docs/open-network-checks.md](open-network-checks.md) | Current network validation backlog. |
| Opti/Proxmox plan | [docs/opti/](opti/) | Planning docs only until explicit implementation task. |
| Restore | [docs/restore.md](restore.md) | Pi DNS restore guide and constraints. |
| Automation | [docs/automation.md](automation.md) | Timers, scripts, Git behavior, and risk boundaries. |
| Historical snapshots | dated docs | Historical unless explicitly marked current. |
| Pi maintenance checklist | [docs/pi-maintenance-checklist.md](pi-maintenance-checklist.md) | Recurring read-only checklist; weekly/monthly/post-reboot. |
| Security boundaries | [docs/security-boundaries.md](security-boundaries.md) | What may and may not be stored in Git. |
| Health rollout history | [docs/health-rollout-2026-04-28.md](health-rollout-2026-04-28.md) | Record of 2026-04-28 unit hardening rollout. |
| Pi reboot validation | [runbooks/pi-reboot-validation.md](../runbooks/pi-reboot-validation.md) | Read-only post-reboot validation runbook. |
| Backup-health timer verification | [runbooks/verify-backup-health-timer.md](../runbooks/verify-backup-health-timer.md) | Verify automatic backup-health timer after rollout. |
| Unbound optimization audit | [runbooks/unbound-optimization-audit.md](../runbooks/unbound-optimization-audit.md) | Read-only Unbound performance and stability audit. |
| AdGuard optimization audit | [runbooks/adguard-optimization-audit.md](../runbooks/adguard-optimization-audit.md) | Read-only AdGuard Home performance and stability audit. |
| AdGuard client policy | [docs/adguard-home-client-policy.md](adguard-home-client-policy.md) | Proposed client group strategy (PLANNED, not live). |
| AdGuard false-positive allowlist | [docs/adguard-home-false-positive-allowlist.md](adguard-home-false-positive-allowlist.md) | Candidate safe domains by service category. |
| Local runtime state | `state/`, `logs/` | Ignored/local only except `.gitkeep`; never source-of-truth for Git. |

## Precedence principles

- If current inventory and historical docs say different things, current inventory wins.
- If `README.md` and `AGENTS.md` differ, `AGENTS.md` wins.
- Raw runtime/backups never win over repo policy and must not be committed.
- Planned DNS names are not live services until runtime validation proves the service path.
