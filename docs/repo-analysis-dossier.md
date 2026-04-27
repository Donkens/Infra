# Infra repo analysis dossier

Generated: 2026-04-27
Scope: `/home/pi/repos/infra`
Audience: pasteable sanitized context for ChatGPT analysis

## Summary

This dossier summarizes the Infra repository from a Phase 0 read-only inspection.

Phase 0 was read-only:

- No writes were performed during Phase 0.
- No `sudo` was used during Phase 0.
- No commit or push was performed.
- Raw backups were not read.
- Raw logs were not read.
- Unsanitized `AdGuardHome.yaml` was not read.
- Credentials, sessions, tokens, private keys, and certificate private keys were not read.
- AdGuard rewrites and user rules are summarized as counts/risk, not reproduced as raw lists.

Current conclusion: the repo is useful and mostly coherent, but it needs documentation cleanup and a safer auto-sync staging model before it should be treated as fully mature.

## Repo health

Status: NEEDS WORK

Strong areas:

- Clear canonical agent policy in `AGENTS.md`.
- Clear DNS source-of-truth model: Pi is live operational DNS state, GitHub `main` is canonical history/docs/scripts/sanitized snapshots.
- Pi DNS baseline is well documented.
- Opti/Proxmox plan has strong boundaries and phased runbooks.
- Runtime state and backups are ignored by `.gitignore`.
- Current tracked sensitive-looking path scan found no tracked raw secrets by path name, only `logs/.gitkeep`.

Biggest gaps:

- `docs/restore.md` is incomplete and ends mid-flow.
- `scripts/install/infra-auto-sync.sh` uses broad `git add -A` before automated commit/push.
- Sanitized AdGuard export still contains detailed DNS rewrite/user-rule content; policy prefers counts/summaries for sensitive AdGuard internals.
- `docs/raspberry-pi-baseline.md` contains stale HEAD/current-state commit metadata.
- Restore drills are planned but not documented as completed.

## Source-of-truth model

Confirmed model:

| Layer | Source of truth | Notes |
| --- | --- | --- |
| Live DNS service state | Pi | Pi is the operational source of truth for AdGuard Home and Unbound live state. |
| Repo history/docs/scripts/sanitized snapshots | GitHub `Donkens/Infra` `main` | Canonical history and sanitized repo material. |
| Local Mac repos | Working copies | Should stay clean except ignored local tool state. |
| Raw runtime/backups | Pi-local only | Must not be printed, committed, pasted, or broadly copied. |

Automation model:

- Pi produces nightly sanitized snapshots from live state.
- `infra-auto-sync.timer` triggers snapshot/commit/push automation.
- `state/backups/` is Pi-local backup state and ignored by git.
- `logs/` and `state/` are local runtime directories with `.gitkeep` placeholders only.

Important tension:

- GitHub is canonical for sanitized history, but the Pi is operationally authoritative for DNS state. Any future analysis should treat live service reality and repo snapshots as related but not identical.

## Repo structure

Top-level map:

| Path | Purpose | Status |
| --- | --- | --- |
| `AGENTS.md` | Canonical agent/operator policy | Active |
| `CODEX.md` | Redirects to `AGENTS.md` | Active |
| `README.md` | High-level repo purpose/layout | Active |
| `config/` | Sanitized config snapshots and config templates | Active, sensitive-boundary area |
| `docs/` | Runbooks, baselines, policies, planning docs | Active |
| `inventory/` | Hosts, IP plan, DNS names, VLANs | Active |
| `runbooks/` | Opti phase plans and restore-test checklist | Active |
| `scripts/` | Backup, install, maintenance, debug automation | Active, mixed read/write risk |
| `systemd/` | Unit and timer files | Active templates/snapshots |
| `docker/` | Docker VM compose conventions/examples | Planned/template |
| `caddy/` | Internal reverse-proxy service map | Planned/template |
| `proxmox/` | Proxmox workspace docs/snippets | Planned/template |
| `ansible/` | Placeholder automation layout | Placeholder |
| `.github/workflows/` | CI lint workflow | Active |
| `logs/` | Pi-local runtime logs, ignored except `.gitkeep` | Local state |
| `state/` | Pi-local status/backups, ignored except `.gitkeep` | Local state |

## DNS/Pi architecture

Core DNS chain:

- Client -> AdGuard Home on Pi `192.168.1.55:53`
- AdGuard Home -> Unbound on `127.0.0.1:5335`
- Unbound -> recursive/root/upstream resolution

Pi role:

- Raspberry Pi 3 Model B Plus Rev 1.3.
- Primary DNS node.
- Runs AdGuard Home as policy/UI/TLS front-end.
- Runs Unbound as local recursive/cache resolver.
- Owns sanitized repo snapshots from live DNS config.

Important paths:

| Path | Meaning |
| --- | --- |
| `/home/pi/repos/infra` | Infra repo on Pi |
| `/home/pi/AdGuardHome` | AdGuard Home working directory |
| `/home/pi/AdGuardHome/AdGuardHome.yaml` | Raw AdGuard config, forbidden to print/read broadly |
| `/etc/unbound` | Unbound config directory |
| `/etc/unbound/unbound.conf.d` | Active Unbound include directory |

AdGuard Home sanitized facts:

- Service: `AdGuardHome.service`
- UI: `0.0.0.0:3000`
- Plain DNS: `0.0.0.0:53`
- HTTPS: `443`
- DoT/DoQ port: `853`
- TLS server name: `adguard.home.lan`
- Upstream DNS: local Unbound at `127.0.0.1:5335`
- Protection/filtering: enabled
- Blocking mode: `nxdomain`
- DNSSEC in AdGuard: disabled
- DDR: disabled
- Query log: enabled, memory-only, file logging disabled
- Statistics: enabled
- Rewrites/user rules/clients: documented as counts only in policy; raw lists should not be pasted into analysis artifacts.

Unbound sanitized facts:

- Service: `unbound.service`
- Active listener: loopback on port `5335`
- IPv4 recursion enabled, upstream IPv6 disabled for Tele2 IPv4-only WAN context
- `validator iterator` modules are used
- DNSSEC root trust anchor configured
- Cache/prefetch/serve-expired enabled
- `ptr-local.conf` provides local PTR/A material for `home.lan`
- `31-nih-https-synthetic.conf` provides a local workaround for selected HTTPS/SVCB behavior
- `forward-dxcloud.conf` forwards one documented zone to Cloudflare resolvers

Pi baseline and hardware policy:

- SDRAM OC baseline: `sdram_freq=550`
- Current policy: keep `550`, do not raise to `575` without better cooling and longer stability validation.
- Do not use `force_turbo=1`.
- Pi priority: stability over experiments.

## UDR-7 coverage

Documented role:

- Gateway authority.
- VLAN authority.
- Firewall authority.
- WireGuard authority.

Documented firewall state:

- `docs/unifi-firewall-state-2026-04-14.md` captures early cleanup and DNS source-of-truth state.
- `docs/unifi-firewall-state-2026-04-15.md` documents custom policies including IoT DNS-to-Pi and WAN DNS-bypass blocking.
- UDR-7 is treated as the correct place for VLAN/firewall/WireGuard changes.

Coverage strengths:

- DNS authority split is explicitly documented: AdGuard for forward `home.lan`, Unbound for PTR authority.
- VLAN/firewall decisions for Opti are documented as planned and gated.
- Firewall debug order is standardized: routing -> firewall -> DNS -> application.

Coverage gaps:

- Current UDR-7 live state is documented in dated snapshots, not a single current consolidated baseline.
- Server VLAN 30 is documented as sharing LAN firewall zone until a later `GO firewall` step.
- Exact future firewall commands are not in a final Phase 1 implementation plan.

## Opti/Proxmox coverage

Status:

- Opti/Proxmox material is documentation/templates only until an explicit implementation task says otherwise.
- Network prep is partially completed: Server VLAN 30 and DNS names are documented as live/verified, but Opti trunk is not applied to a physical port and firewall rules are not completed.

Target architecture:

| Component | Role |
| --- | --- |
| Opti | Proxmox hypervisor only |
| VM 101 | HAOS |
| VM 102 | Debian Docker services |
| Pi | DNS primary |
| UDR-7 | Gateway/VLAN/firewall/WireGuard authority |
| Mac mini / MacBook | Admin clients |

Target profiles:

- Target host RAM: `32 GB`
- Low-RAM bootstrap allowed for installation/network validation and light services only.
- Heavy workloads are deferred until RAM target is met.

Planned IP roles:

| Address | Role |
| --- | --- |
| `192.168.1.60` | Opti/Proxmox host management |
| `192.168.30.10` | Docker VM / proxy services |
| `192.168.30.20` | HAOS VM |

Explicit deferrals:

- No Tailscale initially.
- No Jellyfin initially.
- No Vaultwarden until backup destination, backup process, and restore-test are documented and completed.
- No long-lived Proxmox snapshots.
- No WAN port forwards.

Coverage gaps:

- Hardware arrival/RAM state remains open.
- Backup destination is planned but not confirmed.
- Restore-test is a checklist, not completed evidence.
- Firewall zone separation for Server VLAN 30 is pending.

## Scripts and automation

Script map:

| Script | Category | Purpose | Risk |
| --- | --- | --- | --- |
| `scripts/backup/backup-dns-configs.sh` | backup/export | Creates DNS config backups and optional sanitized repo exports | HIGH: copies raw local backups; export redaction should be strengthened |
| `scripts/debug/debug-https-rr.sh` | debug/apply optional | Diagnoses HTTPS/SVCB RR issue and can apply Unbound drop-in | HIGH with `--apply`: writes `/etc/unbound`, restarts `unbound` |
| `scripts/install/enable-extended-stats.sh` | install/change | Adds Unbound extended statistics | HIGH: edits `/etc/unbound`, restarts `unbound` |
| `scripts/install/infra-auto-sync-install.sh` | install/change | Installs sudoers, binary wrapper, systemd unit/timer | HIGH: writes `/etc/sudoers.d`, `/usr/local/bin`, systemd |
| `scripts/install/infra-auto-sync.sh` | automation | Runs backup export, commits, pushes snapshots | HIGH: uses `git add -A`, commit, push |
| `scripts/install/tune-dns-socket-buffers.sh` | install/change | Tunes Unbound socket buffers | HIGH with apply path: writes `/etc/unbound`, restarts `unbound` |
| `scripts/maintenance/check-backups.sh` | health | Checks latest backup freshness/metadata | LOW/MEDIUM: writes status/log files |
| `scripts/maintenance/dns-health-monitor.sh` | health | Checks AdGuard/Unbound service and DNS queries | LOW/MEDIUM: writes status/log files |
| `scripts/maintenance/dns-health-report.sh` | diagnostic | Prints service, DNS, and recent journal diagnostics | MEDIUM: may expose operational log excerpts if pasted |
| `scripts/maintenance/infra-status.sh` | status | Summarizes latest health state | LOW |
| `scripts/maintenance/monitor-cpu.sh` | diagnostic | Reads CPU frequency/governor | MEDIUM: uses `sudo cat` |
| `scripts/maintenance/prune-dns-backups.sh` | maintenance | Dry-run-first backup retention | HIGH with `--apply`: deletes backup directories, but has strong guards |
| `scripts/maintenance/unbound-mini-top.sh` | diagnostic | Live Unbound stats dashboard | LOW |

Risk notes:

- Automated push is powerful and should be narrowed to explicit safe files.
- Backup creation intentionally touches raw local state; that is acceptable only because raw backup paths are ignored and must not be printed/committed.
- Diagnostic scripts that read journal output are operator tools, not paste-safe outputs.

## Systemd timers/services

Timers:

| Timer | Schedule | Service | Purpose | Risk |
| --- | --- | --- | --- | --- |
| `dns-health.timer` | boot + every 10 min | `dns-health.service` | DNS health monitor | LOW/MEDIUM: writes local logs/state |
| `backup-health.timer` | boot + every 12h | `backup-health.service` | Latest backup freshness check | LOW/MEDIUM: writes local logs/state |
| `infra-auto-sync.timer` | daily 03:00 with randomized delay | `infra-auto-sync.service` | Nightly snapshot + git push | HIGH: automated commit/push |

Services:

| Service | User | ExecStart | Purpose |
| --- | --- | --- | --- |
| `dns-health.service` | `pi` | `/home/pi/repos/infra/scripts/maintenance/dns-health-monitor.sh` | Checks AdGuard/Unbound and DNS queries |
| `backup-health.service` | `pi` | `/home/pi/repos/infra/scripts/maintenance/check-backups.sh` | Checks backup freshness/metadata |
| `infra-auto-sync.service` | `pi` | `/usr/local/bin/infra-auto-sync.sh` | Runs nightly snapshot automation |

Systemd gap:

- The repo stores service/timer definitions, but install state and exact runtime enablement are not represented as a single current consolidated automation baseline document.

## Current documentation map

Important docs:

| File | Summary | Status |
| --- | --- | --- |
| `README.md` | Repo overview, managed hosts, layout, principles | Good |
| `AGENTS.md` | Canonical policy for agents/operators | Strong |
| `CODEX.md` | Redirects to `AGENTS.md` | Good |
| `docs/adguard-home-change-policy.md` | Safe AdGuard inspection/change policy | Strong |
| `docs/raspberry-pi-baseline.md` | Pi DNS baseline, services, paths, health checks | Good but some stale commit metadata |
| `docs/raspberry-pi-3b-plus-sdram-oc-baseline-2026-04-27.md` | Pi SDRAM OC baseline and rollback | Good |
| `docs/dns-tls-baseline-2026-04-26.md` | DNS/TLS/firewall cleanup baseline | Good but dated |
| `docs/runbook.md` | Pi DNS operational commands and backup retention | Useful but mixes operator-only commands |
| `docs/restore.md` | Pi restore guide | Incomplete, needs high-priority patch |
| `docs/codex-templates.md` | Reference templates, explicitly non-authoritative | Good |
| `docs/unifi-firewall-state-2026-04-14.md` | Dated firewall state snapshot | Useful historical snapshot |
| `docs/unifi-firewall-state-2026-04-15.md` | Dated firewall state snapshot | Useful historical snapshot |
| `docs/opti/*.md` | Opti/Proxmox target architecture and boundaries | Good planning coverage |
| `runbooks/opti-*.md` | Phase checklists for Opti implementation | Good planning coverage |
| `runbooks/opti-backup-restore-test.md` | Backup/restore-test checklist | Needs completed evidence later |

## Inventory map

Inventory files:

| File | Coverage | Status |
| --- | --- | --- |
| `inventory/hosts.md` | Pi, UDR-7, Opti, Mac mini, MacBook | Good high-level inventory |
| `inventory/ip-plan.md` | Default LAN and Server VLAN 30 key IPs | Good concise plan |
| `inventory/vlans.md` | Default, IoT, Guest, Server, MLO VLANs | Good, includes Server VLAN 30 details |
| `inventory/dns-names.md` | Internal DNS names and roles | Useful, but should stay as inventory rather than raw AdGuard export |

Inventory summary:

- Hosts: 5 documented host/device classes.
- VLANs: Default LAN, IoT, Guest disabled, Server VLAN 30, MLO-LAN.
- Key DNS/IP roles: Pi DNS, Opti/Proxmox host, Docker VM, HAOS VM.
- DNS names: documented as internal `home.lan` names with live/planned status.

Inventory gaps:

- No single generated current inventory dossier that joins hosts + IPs + VLANs + DNS + source-of-truth notes.
- Some live/planned boundaries are clear in Opti docs but could be made more prominent in inventory files.

## Validation/restore status

Validation coverage present:

- Pi baseline includes service checks, port checks, DNS smoke tests, Unbound status/stats, disk/temp/throttle checks.
- DNS health monitor exists and is timer-driven.
- Backup health monitor exists and is timer-driven.
- Backup retention dry-run/apply workflow is documented.
- CI runs `shellcheck --severity=warning` for `.sh` files.

Restore coverage present:

- `docs/restore.md` exists but is incomplete.
- `runbooks/opti-backup-restore-test.md` defines a restore-test checklist.
- Backup script writes manifests/checksums for restore verification.

Restore gaps:

- Pi DNS restore guide is incomplete.
- No completed Pi restore drill evidence found in docs.
- Opti restore-test is not completed; it is gated/planned.
- No single restore matrix for Pi DNS, AdGuard, Unbound, GitHub repo, systemd timers, Opti VMs, Docker appdata, and HAOS backups.

## Agent safety model

Strong safety controls:

- `AGENTS.md` is canonical.
- `CODEX.md` redirects to `AGENTS.md`.
- Phase 0/1/2 model is explicit for infra/network/remote/system-service work.
- Approval gate is explicit for `sudo`, remote/system changes, force/destructive operations, push, `/etc`, LaunchAgents, and managed files.
- Secrets policy is explicit.
- Raw AdGuard YAML policy is explicit.
- Raw backups are explicitly local sensitive state.
- AdGuard API policy forbids hardcoded credentials and raw API data dumps.

Agent-safe operating principle:

- Read-only discovery first.
- Show exact commands and blast radius before writes.
- Wait for explicit `GO` before Phase 2 writes.
- Use sanitized summaries/counts for AdGuard internals.
- Never print raw backup/config/log/credential material.

Safety gaps:

- `scripts/install/infra-auto-sync.sh` violates the spirit of narrow staging by using `git add -A` in automation.
- Some runbook commands are operator-only and include `sudo` without a clear paste-safe/agent-safe split.
- The sanitized AdGuard export currently contains more detail than the strict count-only policy suggests.

## Risk findings

| Priority | Finding | Evidence | Impact |
| --- | --- | --- | --- |
| HIGH | Automated broad staging before push | `infra-auto-sync.sh` uses `git add -A` | Could commit unintended sanitized or unsanitized files if ignore rules fail or new files appear |
| HIGH | Restore guide incomplete | `docs/restore.md` ends during clone setup | Restore process is not reproducible from docs alone |
| HIGH | Sanitized AdGuard export is too detailed for pasteable analysis | `config/adguardhome/AdGuardHome.yaml.sanitized` includes detailed internal DNS/user-rule structures | Internal DNS map/rules may be overexposed in external analysis contexts |
| MEDIUM | Stale baseline metadata | Pi baseline references older HEAD from prior capture | Could confuse repo-state analysis |
| MEDIUM | Auto-sync push runs from Pi | `infra-auto-sync.timer` and service description | Operationally useful, but should have tight guardrails and monitoring |
| MEDIUM | Mixed live vs planned inventory | Opti DNS names/VLAN prep marked live while host implementation is pending | Readers may overestimate deployed workload state |
| MEDIUM | Dated UDR docs only | Firewall docs are snapshots from 2026-04-14/15 | Current consolidated firewall state is not obvious |
| MEDIUM | Diagnostic outputs can expose logs | health report reads `journalctl` snippets | Manual paste risk if outputs include sensitive context |
| LOW | Script style inconsistent | Some scripts lack full repo scripting standard header | Maintainability issue |
| LOW | CI only shellcheck | No markdown/link validation or policy checks | Docs regressions can pass CI |

## Recommended changes

| Priority | File | Type | Recommendation | Why |
| --- | --- | --- | --- | --- |
| HIGH | `docs/restore.md` | docs-only | Complete Pi DNS restore guide end-to-end | Restore is currently not reproducible from docs |
| HIGH | `scripts/install/infra-auto-sync.sh` | script-change | Replace `git add -A` with explicit allowlist staging | Reduces accidental commit/push risk |
| HIGH | `scripts/backup/backup-dns-configs.sh` | script-change | Export AdGuard sanitized snapshot as policy-aligned summary/counts or split detailed export into local-only ignored artifact | Avoids overexposing rewrites/user rules |
| HIGH | `docs/repo-analysis-dossier.md` | docs-only | Keep this sanitized dossier as pasteable current-state context | Makes future ChatGPT analysis safer |
| MEDIUM | `docs/raspberry-pi-baseline.md` | docs-only | Refresh repo metadata and date-sensitive current-state fields | Avoids stale facts |
| MEDIUM | `docs/runbook.md` | docs-only | Split agent-safe read-only commands from operator-only `sudo` commands | Reduces accidental unsafe execution |
| MEDIUM | `docs/automation.md` | docs-only | Add consolidated automation map for timers/services/scripts/write paths | Makes auto-sync and health behavior auditable |
| MEDIUM | `docs/unifi-firewall-current.md` | docs-only | Add current consolidated UDR-7 firewall/VLAN state | Reduces reliance on dated snapshots |
| MEDIUM | `runbooks/opti-backup-restore-test.md` | docs-only | Add evidence template and completion section | Turns checklist into audit trail |
| LOW | `.github/workflows/lint.yml` | CI/docs | Add markdown lint/checks for broken code fences/trailing spaces if desired | Prevents docs formatting regressions |

## Suggested patch order

1. Complete `docs/restore.md`.
2. Add/keep `docs/repo-analysis-dossier.md` as sanitized repo context.
3. Change `infra-auto-sync.sh` from `git add -A` to explicit allowlist staging.
4. Tighten `backup-dns-configs.sh` sanitized AdGuard export policy.
5. Refresh `docs/raspberry-pi-baseline.md` current repo metadata.
6. Add `docs/automation.md` for timers/services/scripts/write paths.
7. Split `docs/runbook.md` into agent-safe read-only checks and operator-only commands.
8. Add current consolidated UDR-7 firewall/VLAN baseline.
9. Add restore-drill evidence template and later completed restore evidence.
10. Extend CI with Markdown/code-fence/trailing-space validation if useful.

## Open questions

- Should `config/adguardhome/AdGuardHome.yaml.sanitized` remain a detailed sanitized YAML snapshot, or should it become a reduced summary artifact with counts only?
- Should `infra-auto-sync.timer` continue pushing directly to GitHub, or should it create local commits only and leave push manual?
- What exact files should be allowlisted for nightly auto-sync staging?
- Is the Pi DNS restore process tested on real hardware, a spare SD card, or only documented conceptually?
- Should UDR-7 firewall state be consolidated into one current baseline doc instead of dated snapshots only?
- When Opti arrives, what RAM size is actually installed, and should low-RAM bootstrap be used?
- What is the first backup destination for Opti/Proxmox/HAOS/Docker: USB-SSD only, or USB-SSD plus later offsite?
- Should internal DNS inventory include full names in pasteable docs, or should external-analysis dossiers always use summarized service categories?
