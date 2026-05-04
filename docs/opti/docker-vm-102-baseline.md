# Docker VM 102 — baseline

## Phase 1A — 2026-05-04

VM `102` created as Debian 13 trixie base. Docker Engine not yet installed.
No services, no Caddy, no Dockge, no Uptime Kuma, no Dozzle in this phase.

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

MAC `BC:24:11:50:9C:4D` — full MAC known. UniFi fixed-IP reservation for
`192.168.30.10` not yet created. Create via UniFi UI or MCP in Phase 1B to
prevent IP conflict if VM reboots before DHCP is locked.

## DNS status

- `docker.home.lan` → `192.168.30.10` — pre-configured in AdGuard, status PENDING (VM live, DNS already resolves)
- `proxy.home.lan` → `192.168.30.10` — pre-configured in AdGuard, status PENDING (service not yet running)

## Target resource profile

| Profile | CPU | RAM | Disk |
| --- | ---: | ---: | ---: |
| Current (Phase 1A) | `4 vCPU` | `12 GB` | `120 GB` |
| Target (`32 GB` host) | `6 vCPU` | `18 GB` | `200 GB` |

## WARN items

- Pi DNS ICMP blocked from Server zone — expected behaviour, not a gap.
- `docker.home.lan` resolves to `127.0.1.1` from inside the VM itself (cloud-init
  `/etc/hosts` entry). External resolution via AdGuard returns `192.168.30.10`
  correctly.
- `qemu-guest-agent` not pre-installed in Debian genericcloud image; installed
  manually in Phase 1A. Package: `qemu-guest-agent 1:10.0.8+ds-0+deb13u1+b1`.
- UniFi DHCP fixed-IP reservation not yet created for `BC:24:11:50:9C:4D`.
- `ip_version: BOTH` on firewall rule — functionally correct but cosmetically
  differs from HAOS-SSH rule (`IPV4`). Update via UI if desired.

## Not done in Phase 1A

- Docker Engine not installed.
- No compose, no services.
- No UniFi DHCP reservation.
- No Proxmox backup job update to include VM 102.
- No node_exporter.

## Next step — Phase 1B

Install Docker Engine + Compose plugin, create `/srv/compose` and `/srv/appdata`
filesystem layout, validate `docker run hello-world`.
