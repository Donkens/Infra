# Opti-side Auth Verification — 2026-05-04

Mode: read-only, interrupted during SSH tooling check
Source host: Opti / Proxmox host (`opti`) / user `root`
Command origin: SSH session from MacBook Pro (`mbp`) to Opti

## Summary

Status: PASS with notes.

Opti is reachable over SSH as `root` and has a Proxmox-style SSH layout where `/root/.ssh/authorized_keys` is a symlink to `/etc/pve/priv/authorized_keys`. The active authorized keys include Opti's own RSA key, the MacBook key, and the Mac mini key. Unlike UDR, Opti does have a local private key (`/root/.ssh/id_rsa`), which is normal for Proxmox cluster/host SSH behavior but should be treated as sensitive host material and not copied into the repo.

The check was interrupted at the SSH tooling section because `ssh-keygen -h` on OpenSSH starts an interactive host-certificate flow rather than printing help. No private key material was printed.

## Host identity

| Item | Value |
|---|---|
| Hostname | `opti` |
| User | `root` |
| Home | `/root` |
| Kernel | Linux `7.0.0-3-pve` x86_64 |
| Role | Proxmox / compute host |

## SSH directory state

| Path | Mode/size | Note |
|---|---:|---|
| `/root/.ssh` | `drwx------` | Correct private SSH directory mode |
| `/root/.ssh/authorized_keys` | symlink | Points to `/etc/pve/priv/authorized_keys` |
| `/root/.ssh/config` | `rw-r-----`, 117 B | Local SSH client config metadata only observed |
| `/root/.ssh/id_rsa` | `rw-------`, 3369 B | Local private key present; expected/sensitive on Proxmox-style host |
| `/root/.ssh/id_rsa.pub` | `rw-r--r--`, 735 B | Public key for Opti root key |

## Active authorized keys

| Fingerprint | Comment |
|---|---|
| `SHA256:8Z/XMMS3r38QrvOfa+eHrEnfVByC96poAo+5/RSkXOM` | `root@opti` |
| `SHA256:Tc/gNhhJ+/Cwkui/1T36YVwHSs1quLjGK7J0MbItpaU` | no comment |
| `SHA256:IxV/v8tpNBG542/yNj1g3nz1AbwGnpQfbJwQJZx+9A0` | `macmini@home.lan` |

## Local public keys on Opti

| Public key | Fingerprint | Comment |
|---|---|---|
| `/root/.ssh/id_rsa.pub` | `SHA256:8Z/XMMS3r38QrvOfa+eHrEnfVByC96poAo+5/RSkXOM` | `root@opti` |

## Local private/other SSH files metadata only

| File | Mode/size | Classification |
|---|---:|---|
| `/root/.ssh/id_rsa` | `rw-------`, 3369 B | private host key; sensitive, do not print/copy |
| `/root/.ssh/config` | `rw-r-----`, 117 B | local SSH config metadata only |

## SSH tooling

| Tool | Result |
|---|---|
| `ssh` | `/usr/bin/ssh`, OpenSSH_10.0p2 Debian-7+deb13u2, OpenSSL 3.5.5 |
| `ssh-keygen` | `/usr/bin/ssh-keygen` present |

Note: `ssh-keygen -h` was accidentally used as a help check and began an interactive key/certificate-related flow. The command was interrupted with Ctrl-C. Future checks should use `ssh-keygen -V` or `ssh-keygen -?` patterns only if needed, or simply check `command -v ssh-keygen`.

## Interpretation

This is a sane initial Proxmox host posture:

| Flow | Policy |
|---|---|
| Mac mini -> Opti | allowed, admin flow |
| MacBook -> Opti | allowed, admin flow |
| Opti -> GitHub | not verified here; allow only if needed for repo/compose automation |
| Opti -> Pi/UDR/Macs | not required by default |
| Opti as broad jump host | discouraged unless explicitly documented |

## Follow-ups

1. Verify `/root/.ssh/config` content later using a sanitized read; do not print secrets if any are present.
2. Verify whether Opti has a local Infra repo after Proxmox/bootstrap stabilizes.
3. Keep the local `/root/.ssh/id_rsa` private key off Git and out of chats.
4. If Opti needs GitHub access, prefer a dedicated Opti GitHub deploy/user key with narrow scope rather than reusing Mac keys.
5. Add future VM-level auth docs separately for Docker VM and HAOS VM; do not mix host auth and guest auth.

## Safer command pattern for future checks

```sh
ssh opti 'hostname; whoami; uname -a; ls -ld /root/.ssh; ls -l /root/.ssh; while IFS= read -r line; do [ -n "$line" ] && printf "%s\n" "$line" | ssh-keygen -lf - 2>/dev/null || true; done < /root/.ssh/authorized_keys'
```

Do not print private keys, raw Proxmox cluster secrets, or raw SSH config if it contains secrets.
