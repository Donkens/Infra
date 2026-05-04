# UDR-side Auth Verification — 2026-05-04

Mode: read-only
Source host: UniFi Dream Router 7 (`udrhomelan`) / user `root`
Command origin: SSH session from MacBook Pro (`mbp`) to UDR

## Summary

Status: PASS with cleanup notes.

UDR-7 has a minimal SSH server-side auth surface: the active `/root/.ssh/authorized_keys` file contains the expected `udr7` key and the `neoserver@macmini` key. No private SSH key files were observed in `/root/.ssh`, which is the desired posture for the router. UDR should remain an SSH target, not an admin source/jump host.

## Host identity

| Item | Value |
|---|---|
| Hostname | `udrhomelan` |
| User | `root` |
| Home | `/root` |
| Kernel | Linux `5.4.213-ui-ipq5322-wireless` aarch64 |
| Role | Gateway/router |

## SSH directory state

| Path | Mode/size | Note |
|---|---:|---|
| `/root/.ssh` | `drwx------` | Correct private SSH directory mode |
| `/root/.ssh/authorized_keys` | `rw-------`, 185 B | Active authorized keys |
| `/root/.ssh/known_hosts` | `rw-r--r--`, 444 B | 2 known-host entries |

## Active authorized keys

| Fingerprint | Comment |
|---|---|
| `SHA256:zorJul5YiPwIV2PkmKghWE/yn7Nl7M9u7mh0MPYZ5Lw` | `udr7` |
| `SHA256:UbErkFhmVHGXGAdvn4Znzm09AMBKsqLeexWlYLIcLQc` | `neoserver@macmini` |

## Local SSH tooling on UDR

| Tool | Path |
|---|---|
| `ssh` | `/usr/bin/ssh` |
| `ssh-keygen` | `/usr/bin/ssh-keygen` |

## Files observed in `/root/.ssh`

| File | Mode/size | Classification |
|---|---:|---|
| `authorized_keys` | `rw-------`, 185 B | active config |
| `known_hosts` | `rw-r--r--`, 444 B | metadata |
| `authorized_keys.bak-20260401-145446` | `rw-------`, 282 B | old backup |
| `authorized_keys.pre-retire-$TS.bak` | `rw-------`, 282 B | old backup with literal `$TS` in filename |
| `authorized_keys.pre-retire-$TS.meta.txt` | `rw-r--r--`, 550 B | old metadata with literal `$TS` in filename |
| `authorized_keys.pre-retire-20260422-210930.bak` | `rw-------`, 282 B | old backup |
| `authorized_keys.pre-retire-20260422-210930.meta.txt` | `rw-r--r--`, 562 B | old metadata |
| `authorized_keys.retire.e6Cq6Y` | `rw-------`, 0 B | empty retire/temp file |

## Private key posture

No private key files were observed in `/root/.ssh` during this check. This is good: UDR should not hold client private keys unless a specific, documented automation requires outbound SSH from the router.

## Interpretation

This is a sane router posture:

| Flow | Policy |
|---|---|
| Mac mini -> UDR | allowed, key-only auth verified elsewhere |
| MacBook -> UDR | allowed, key-only auth verified elsewhere |
| UDR -> other hosts | not required by default |
| UDR -> GitHub | not required by default |
| UDR as jump host | discouraged |

## Follow-ups

1. Keep UDR as an SSH target, not an SSH source/jump host.
2. Keep no private keys on UDR unless a concrete automation requires it.
3. Consider moving old `authorized_keys.*bak` and `*.meta.txt` files off-router or into a documented quarantine later, after confirming they are no longer needed.
4. The literal `$TS` filenames indicate an earlier shell variable expansion bug; harmless, but good cleanup candidates.
5. Leave active `authorized_keys` untouched unless rotating keys.

## Safe command pattern

```sh
ssh udr 'hostname; whoami; ls -ld /root/.ssh; ls -l /root/.ssh; while IFS= read -r line; do [ -n "$line" ] && printf "%s\n" "$line" | ssh-keygen -lf - 2>/dev/null || true; done < /root/.ssh/authorized_keys'
```

Do not store private keys, raw router configs, or secrets in Git.
