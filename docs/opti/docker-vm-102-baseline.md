# Docker VM 102 — baseline

## Phase 1A — 2026-05-04

VM `102` created as Debian 13 trixie base. No services, no Caddy, no Dockge,
no Uptime Kuma, and no Dozzle were installed in this phase.

## Phase 1B — Docker Engine baseline — 2026-05-04

Docker Engine and the Docker Compose plugin are installed and validated on VM
`102`. This is a runtime baseline only: no long-running containers or services
were deployed. The only container executed was the temporary `hello-world`
validation container.

| Check | Result |
| --- | --- |
| Docker Engine | `29.4.2`, build `055a478` ✅ |
| Docker Compose plugin | `v5.1.3` ✅ |
| `docker.service` | `active` ✅ |
| `/srv/compose` | `drwxrwxr-x`, `yasse:docker` ✅ |
| `/srv/appdata` | `drwxrwxr-x`, `yasse:docker` ✅ |
| `/srv/backups` | `drwxrwxr-x`, `yasse:docker` ✅ |
| Disk `/` | `118G` total, `1.4G` used, `112G` free at validation ✅ |
| `systemctl --failed` | `0` failed units ✅ |
| `yasse` group membership | member of `docker` (`gid 989`) ✅ |
| Runtime test | `sudo docker run --rm hello-world` → `Hello from Docker!` ✅ |

Docker was installed from Docker's official Debian apt repository using the VM's
Debian 13/trixie codename. Package install was limited to Docker Engine,
Docker CLI, containerd, Buildx plugin, and Compose plugin.

> WARN: the shell session active during the install could require a new SSH login
> before `docker` works without `sudo` for user `yasse`. This is expected after
> adding an existing user to the `docker` group. A fresh SSH session should pick
> up the new group membership.

## VM config

| Field | Value |
| --- | --- |
| VMID | `102` |
| Name | `docker` |
| Hostname | `docker` |
| OS | Debian 13 trixie (`debian-13-genericcloud-amd64.qcow2`, 2026-05-01) |
| Machine | `q35` |
| CPU | `host`, `4` vCPU |
| RAM | `12288 MB` (12 GB) |
| Disk | `120 GB` on `local-lvm` (`vm-102-disk-0`), `discard=on`, `iothread=1` |
| Cloud-init | `local-lvm:vm-102-cloudinit` |
| net0 | `virtio`, `vmbr0`, VLAN tag `30` |
| MAC | `BC:24:11:50:9C:4D` |
| IP | `192.168.30.10/24` (static cloud-init) |
| Gateway | `192.168.30.1` |
| DNS | `192.168.1.55` |
| Search domain | `home.lan` |
| SSH user | `yasse` |
| SSH keys | `id_ed25519_macmini` + `id_ed25519_mbp` |
| QGA | `enabled=1`, `qemu-guest-agent` installed and active |
| Serial | `socket` / `vga serial0` |
| onboot | `1` (set after validation PASS) |
| SMBIOS UUID | `20e80295-c856-4b07-b221-0f32acf231a4` |

## Validation results — 2026-05-04

| Check | Result |
| --- | --- |
| `qm status 102` | `running` ✅ |
| SSH from Mac mini | PASS ✅ |
| SSH from MBP | key injected, not yet tested |
| hostname inside VM | `docker` ✅ |
| IP `192.168.30.10/24` | ✅ |
| Gateway `192.168.30.1` ping | PASS ✅ |
| Pi DNS `192.168.1.55` ping | BLOCKED by zone default (expected — DNS queries work) |
| `resolvectl` DNS server | `192.168.1.55` ✅ |
| `resolvectl query ha.home.lan` | `192.168.30.20` via Pi DNS ✅ |
| Internet `ping 1.1.1.1` | PASS ✅ |
| `getent hosts ha.home.lan` | `192.168.30.20` ✅ |
| QGA ping from Proxmox | PASS ✅ |
| onboot=1 | set after PASS ✅ |
| Locale | `en_US.UTF-8` generated and set as default ✅ |

## UniFi firewall rule added

| Policy | ID | Direction | Source | Destination | Port | Action |
| --- | --- | --- | --- | --- | --- | --- |
| `allow-lan-admin-to-docker-ssh` | `69f8842c1bc6e72d2776ddd0` | Internal → Server | Internal zone ANY | `192.168.30.10` | TCP 22 | ALLOW |

`ip_version: BOTH`, `create_allow_respond: true`, index `10002`.
Note: `ip_version` stored as `BOTH` due to MCP/API schema mismatch at time of creation.
Functionally IPv4-only at this IP; can be updated to `IPV4` via UniFi UI if desired.

## DHCP reservation

MAC `BC:24:11:50:9C:4D` — full MAC known. UniFi fixed-IP reservation confirmed
live: `use_fixedip: true`, `fixed_ip: 192.168.30.10`, verified 2026-05-04.
UniFi client name: `Docker VM 102`. Note: `Debian Docker VM · VLAN 30 · 192.168.30.10 · Proxmox VMID 102`.

## DNS status

- `docker.home.lan` → `192.168.30.10` — pre-configured in AdGuard, status LIVE for host access
- `proxy.home.lan` → `192.168.30.10` — pre-configured in AdGuard, status PENDING (Caddy/service not yet running)

## Filesystem layout

| Path | Owner/group | Mode | Purpose |
| --- | --- | --- | --- |
| `/srv/compose` | `yasse:docker` | `775` | Docker Compose projects |
| `/srv/appdata` | `yasse:docker` | `775` | Persistent app data/configs |
| `/srv/backups` | `yasse:docker` | `775` | Local backup staging/export area |

## Target resource profile

| Profile | CPU | RAM | Disk |
| --- | ---: | ---: | ---: |
| Current (Phase 1A/1B) | `4 vCPU` | `12 GB` | `120 GB` |
| Target (`32 GB` host) | `6 vCPU` | `18 GB` | `200 GB` |

## WARN items

- Pi DNS ICMP blocked from Server zone — expected behaviour, not a gap.
- `docker.home.lan` resolves to `127.0.1.1` from inside the VM itself (cloud-init
  `/etc/hosts` entry). External resolution via AdGuard returns `192.168.30.10`
  correctly.
- `qemu-guest-agent` not pre-installed in Debian genericcloud image; installed
  manually in Phase 1A. Package: `qemu-guest-agent 1:10.0.8+ds-0+deb13u1+b1`.
- ~~UniFi DHCP fixed-IP reservation not yet created.~~ **Resolved 2026-05-04:** `use_fixedip: true` confirmed.
- `ip_version: BOTH` on firewall rule — functionally correct but cosmetically
  differs from HAOS-SSH rule (`IPV4`). Update via UI if desired.
- Docker group membership may require a fresh SSH login before `docker` works
  without `sudo` for user `yasse`.

## Phase 1C-A — Backup gate — 2026-05-04

Interim Proxmox-level backup of VM 102 completed before any Docker services
were deployed. This establishes a clean rollback point.

| Field | Value |
| --- | --- |
| Backup file | `vzdump-qemu-102-2026_05_04-16_45_42.vma.zst` |
| Backup date | 2026-05-04 16:45:42 CEST |
| Mode | `snapshot`, QGA fs-freeze succeeded ✅ |
| Compressed size | `579 MB` |
| SHA256 | `068a0d55cf4149ae2e931c0fb3dd7c71e1999d61b28c25eb1f57f165e295808c` |
| SHA256 match | ✅ identical on Opti and Mac mini |
| Off-host path | `/Users/yasse/InfraBackups/proxmox-dumps/vzdump-qemu-102-2026_05_04-16_45_42.vma.zst` |
| VM status after | `running` |

See `docs/opti/60-backup-restore.md` for full backup policy and architecture notes.

> **Interim note:** This is not a scheduled job and not the final backup
> architecture. A proper scheduled backup target (external USB SSD or NFS) and
> a documented restore-test are still required before critical workloads are
> deployed.

## Not done in Phase 1A/1B/1C-A

- No Caddy.
- No Dockge.
- No Uptime Kuma.
- No Dozzle.
- No node_exporter.
- No long-running containers or services.
- ~~Docker Engine not installed.~~ **Resolved Phase 1B 2026-05-04.**
- ~~No compose runtime baseline.~~ **Resolved Phase 1B 2026-05-04: Compose plugin `v5.1.3`.**
- ~~No UniFi DHCP reservation.~~ Confirmed live 2026-05-04.
- ~~No Proxmox backup for VM 102.~~ **Resolved Phase 1C-A 2026-05-04: interim backup + off-host copy verified.**
- No scheduled Proxmox backup job.
- No restore-test for VM 102.

## Next step — Phase 1C-B/C

Deploy first lightweight Docker service stack (Caddy/Dockge/Uptime Kuma/Dozzle)
as separate, audited steps. Requires DNS rewrites in AdGuard for
`dockge.home.lan`, `kuma.home.lan`, `dozzle.home.lan` before deploy. No
Vaultwarden, Jellyfin, media/download-heavy workloads, or WAN exposure until
backup and restore policy is upgraded.
