# HAOS-side Auth Verification — 2026-05-04

Mode: read-only
Source host: Home Assistant SSH add-on container (`a0d7b954-ssh`) / user `hassio`
Command origin: SSH session from MacBook Pro (`mbp`) to HAOS SSH target

## Summary

Status: PASS with notes.

The HAOS SSH target is an SSH add-on/container environment rather than a normal full Linux host. It is reachable as user `hassio`, but no `$HOME/.ssh` directory contents, `authorized_keys`, local public keys, private keys, or `known_hosts` were observed from the shell context checked here. This is acceptable for HAOS/add-on SSH where key management may be handled by the add-on supervisor/config layer rather than persisted in `/home/hassio/.ssh`.

No private SSH key files were observed. No Home Assistant tokens, secrets, or raw configs were printed.

## Host identity

| Item | Value |
|---|---|
| Runtime hostname | `a0d7b954-ssh` |
| User | `hassio` |
| Home | `/home/hassio` |
| Kernel | Linux `6.12.77-haos` x86_64 |
| Role | Home Assistant OS SSH add-on / admin shell target |

## SSH directory state

| Item | Result |
|---|---|
| `$HOME/.ssh` listing | no output observed |
| `$HOME/.ssh/authorized_keys` | not present in checked shell context |
| Local SSH public keys | none observed |
| Private/other SSH files | none observed |
| `known_hosts` | not present |

## Authorized keys fingerprints

No `authorized_keys` file was present in `/home/hassio/.ssh` during this check.

This does not necessarily mean SSH auth is unmanaged or broken. The session itself succeeded, and HAOS SSH add-ons often keep authorized keys in add-on configuration or supervisor-managed storage rather than a conventional user-level `authorized_keys` file.

## SSH tooling

| Tool | Result |
|---|---|
| `ssh` | `/usr/bin/ssh`, OpenSSH_10.2p1, OpenSSL 3.5.6 |
| `ssh-keygen` | `/usr/bin/ssh-keygen` present |

## Home Assistant CLI

| Check | Result |
|---|---|
| `command -v ha` | `/usr/bin/ha` |
| `ha --version` | unavailable or blocked in this shell context |

## Interpretation

This is a sane posture for the HAOS SSH add-on as long as HAOS remains an admin target and not a source/jump host.

| Flow | Policy |
|---|---|
| Mac mini -> HAOS | allowed if needed for HA admin/troubleshooting |
| MacBook -> HAOS | allowed if needed for HA admin/troubleshooting |
| HAOS -> other hosts | not required by default |
| HAOS -> GitHub | not required by default |
| HAOS as jump host | discouraged |

## Follow-ups

1. Treat HAOS SSH as an admin target only, not a general jump host.
2. Do not place persistent private keys inside the HAOS SSH add-on unless a concrete automation requires it.
3. If HAOS SSH authorized keys need to be audited later, inspect the add-on configuration through Home Assistant UI or a sanitized supervisor-safe method, not by dumping raw secrets/configs.
4. Keep HA tokens, long-lived access tokens, add-on options, and `secrets.yaml` out of Git and chats.
5. If HAOS later needs GitHub or repo access, create a dedicated narrow-scope key and document it separately.

## Safe command pattern

```sh
ssh ha 'hostname; whoami; echo "$HOME"; uname -a; command -v ssh; command -v ssh-keygen; command -v ha || true'
```

Do not print Home Assistant tokens, raw add-on options, `secrets.yaml`, or private SSH keys.
