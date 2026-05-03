# Proxmox SSH hardening plan — opti

Date: 2026-05-03

## Status

Phase 2A completed. Minimal SSH hardening applied to Proxmox host `opti` via
drop-in file. No Proxmox restart or reboot was performed. No firewall, rpcbind,
network, or HAOS changes were made.

## Scope

- Host: `opti` (`192.168.1.60`)
- File created: `/etc/ssh/sshd_config.d/99-hardening.conf`
- Method: `systemctl reload ssh` (no restart; existing sessions preserved)

## Before and after

| Parameter | Before | After |
| --- | --- | --- |
| `permitrootlogin` | `yes` | `prohibit-password` (key-only root) |
| `passwordauthentication` | `yes` | `no` |
| `pubkeyauthentication` | `yes` | `yes` (unchanged) |
| `kbdinteractiveauthentication` | `no` | `no` (unchanged) |
| `x11forwarding` | `yes` | `no` |
| `allowtcpforwarding` | `yes` | `no` |
| `gatewayports` | `no` | `no` (unchanged) |

> **Note:** `sshd -T` reports `prohibit-password` as `without-password` — these
> are canonical synonyms in OpenSSH. The effective behaviour is identical: root
> may authenticate with a public key but not with a password.

## Drop-in file

`/etc/ssh/sshd_config.d/99-hardening.conf`:

```
PasswordAuthentication no
X11Forwarding no
AllowTcpForwarding no
PermitRootLogin prohibit-password
```

Permissions: `644 root:root`.

## Backup created

`/etc/ssh/sshd_config.bak.20260503-230735` — pre-hardening copy of base config.

## Authorized keys

`/root/.ssh/authorized_keys` → symlink to `/etc/pve/priv/authorized_keys`.
Three keys at time of hardening:

- `ssh-rsa` — opti host key (internal Proxmox use)
- `ssh-ed25519` — MacBook (`mbp`, `192.168.1.78`)
- `ssh-ed25519 macmini@home.lan` — Mac mini (`mini`, `192.168.1.86`/`.84`)

## Admin client validation

| Client | Test | Result |
| --- | --- | --- |
| MBP `192.168.1.78` | `ssh opti 'echo NEW_SESSION_CURRENT_CLIENT_OK'` | ✅ PASS |
| Mac mini `192.168.1.86` | `ssh mini 'ssh opti "echo NEW_SESSION_MINI_OK"'` | ✅ PASS |

Both clients opened new key-authenticated sessions after `systemctl reload ssh`.

## Impact

| System | Impact |
| --- | --- |
| Proxmox Web UI (8006) | None — WebUI uses its own auth stack, not sshd |
| HAOS VM 101 | None — `issues: []`, `suggestions: []`, `unhealthy: []`, `unsupported: []` |
| Running SSH sessions | None — `reload` preserves established sessions |
| Cluster/corosync | N/A — standalone single-node |

## What was NOT changed

- `PermitRootLogin no` — not set; root key-only (`prohibit-password`) is the
  safe intermediate state. Setting `no` requires a verified non-root admin
  sudo path first.
- Firewall: no PVE firewall rules were added or changed.
- `rpcbind`: not touched; reviewed separately under GO firewall-review.
- HAOS, Pi, UDR, DNS, VLANs, UniFi: not touched.

## Rollback procedure

```bash
ssh opti 'rm -f /etc/ssh/sshd_config.d/99-hardening.conf && systemctl reload ssh'
```

This restores the Debian/Proxmox default behaviour (password auth allowed,
X11/TCP forwarding allowed, root login unrestricted).

## Next steps

| Step | Status |
| --- | --- |
| Create non-root admin user with sudo | pending — enables future `PermitRootLogin no` |
| PVE host firewall allowlist design | pending — GO firewall-review Phase 2A |
| rpcbind review and disable | pending — GO firewall-review Phase 2A |
| Server VLAN 30 isolation | pending — separate UniFi GO |
