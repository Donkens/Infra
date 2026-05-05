# Identity Map

> Canonical host/user/repo baseline for this infrastructure.
> Human owner: **Yasse**
> ⚠️ Local Unix user differs by host — never assume username from context alone.
> Last verified: 2026-05-05

## Host Table

| Role | Hostname | DNS name | IP(s) | SSH alias | SSH user | Local user | HOME | Arch | OS | Brew prefix | Repo path | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| MacBook Pro 2015 — secondary Intel Mac, Cowork/admin client | `mbp` | `mbp.home.lan` | `192.168.1.78` | `ssh hd@mbp` / Desktop Commander | `hd` | `hd` | `/Users/hd` | x86_64 (Intel) | macOS 15.7.5 Sequoia | `/usr/local` | `/Users/hd/repos/Infra` | OCLP. Cowork runs here. |
| Mac mini M1 — primary ARM Mac, compute/scripts/automation | `mini` | `macmini.home.lan` | eth: `192.168.1.86` / wifi: `192.168.1.84` | `ssh mini` | `yasse` | `yasse` | `/Users/yasse` | arm64 (M1 T8103) | macOS 26.5 beta | `/opt/homebrew` | `/Users/yasse/repos/Infra` | Primary admin Mac. macOS beta as of 2026-04-27. |
| Raspberry Pi 3B+ — DNS node | `pi` | `pi.home.lan` | `192.168.1.55` | `ssh pi` | `pi` | `pi` | `/home/pi` | aarch64 | Debian 13 trixie, kernel 6.12.75 | n/a | `/home/pi/repos/infra` | AdGuard Home + Unbound. **Repo path is lowercase `infra`.** |
| UDR-7 — gateway, VLAN, firewall, WireGuard | `udrhomelan` | `udr.home.lan` | `192.168.1.1` | `ssh udr` | `root` | `root` | `/root` | aarch64 | Linux 5.4.213 (UniFi firmware) | n/a | n/a | **SSH user is `root`, not `ubnt`.** Hostname is `udrhomelan`. No persistent custom state written to router (firmware may reset). |
| Opti — Proxmox VE hypervisor, VM host | `opti` | `opti.home.lan` | `192.168.1.60` | `ssh opti` (config.local) | `root` | `root` | `/root` | x86_64 | Proxmox VE 9.1.0, kernel 7.0.0-3-pve | n/a | n/a | Single NVMe 476.9GB. VMs: 101 haos (VLAN30), 102 docker (VLAN30). Backup jobs in `/etc/pve/jobs.cfg`. SSH key: `id_ed25519_macmini`. |

## Agent Verification Rules

Before any audit or write, an agent **must**:

1. Read `~/.machine-identity` if it exists on the current host.
2. Verify with: `hostname`, `whoami`, `id`, `echo "$HOME"`, `uname -a`.
3. Cross-check against this table — if values conflict, **stop and report**.
4. If the target host differs from the current host, SSH and verify the remote host separately.

See `AGENTS.md § HOST VERIFICATION` for the full policy.
See `docs/agent-host-verification.md` for the operator runbook.

## Common Pitfalls

- Workspace/sandbox path is **not** the target host.
- `/Users/hd` does not prove MacBook — verify `hostname` too.
- `/Users/yasse` does not prove Mac mini — verify `hostname` too.
- iCloud symlinks may appear on multiple Macs simultaneously.
- UDR SSH user is `root`, not `ubnt`. UDR hostname is `udrhomelan`.
- Pi repo path is **lowercase**: `/home/pi/repos/infra` (not `Infra`).
- Mac mini and MacBook share the same GitHub remote — always confirm local identity before writes.

## No Secrets

No credentials, tokens, private keys, or passwords belong in this file.
