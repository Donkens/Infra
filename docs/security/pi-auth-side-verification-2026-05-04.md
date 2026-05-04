# Pi-side Auth Verification — 2026-05-04

Mode: read-only
Source host: Raspberry Pi DNS node (`pi`) / user `pi`
Command origin: SSH session from MacBook Pro (`mbp`) to Pi

## Summary

Status: PASS for GitHub, WARN for lateral SSH from Pi.

Pi can authenticate to GitHub using its dedicated `id_ed25519_github_pi` key. Pi does not currently have clean, documented SSH client config for lateral SSH into `mini`, `mbp`, or `udr`; those checks either failed DNS resolution, failed auth, or failed host-key verification. This is acceptable if Pi is intended to be a DNS/service node rather than an admin source host.

## Host identity

| Item | Value |
|---|---|
| Hostname | `pi` |
| User | `pi` |
| Home | `/home/pi` |
| Kernel | Linux `6.12.75+rpt-rpi-v8` aarch64 |
| Repo path | `/home/pi/repos/infra` |
| Repo remote | `git@github.com:Donkens/Infra.git` |
| Repo status | `main...origin/main` |
| HEAD during check | `951537d docs(pi): add safe cleanup audit` |

## Pi SSH client config summary

### GitHub

| Field | Value |
|---|---|
| Target | `github.com` |
| User | `git` |
| Hostname | `github.com` |
| IdentityFile | `~/.ssh/id_ed25519_github_pi` |
| IdentitiesOnly | yes |
| ForwardAgent | no |
| PubkeyAuthentication | true |
| PasswordAuthentication | yes, client-side default |

### Lateral targets from Pi

Pi has no dedicated host stanzas for these lateral admin targets in the observed expanded config. OpenSSH therefore falls back to default identity candidates and user `pi`.

| Target | Observed user | Observed hostname | IdentitiesOnly | ForwardAgent | Result |
|---|---|---|---:|---:|---|
| `mini` | `pi` | `mini` | no | no | DNS resolution failed |
| `mbp` | `pi` | `mbp` | no | no | Permission denied |
| `udr` | `pi` | `udr` | no | no | Host key verification failed |
| `ha` | `pi` | `ha` | no | no | Not tested |
| `opti` | `pi` | `opti` | no | no | Not tested |

## Local public keys on Pi

| Public key | Fingerprint | Comment |
|---|---|---|
| `/home/pi/.ssh/id_ed25519_github_pi.pub` | `SHA256:w21zRgqkJ5Tc4FZ62SjEC7v77zRVspiCzrRKrsYFUhs` | `pi-github` |

## SSH agent on Pi

No SSH agent keys were loaded or available during the check.

## GitHub auth from Pi

Result: PASS

```text
Hi Donkens! You've successfully authenticated, but GitHub does not provide shell access.
```

## Key-only remote checks from Pi

| Target | Result | Detail |
|---|---:|---|
| `mini` | WARN | `ssh: Could not resolve hostname mini: No address associated with hostname` |
| `mbp` | WARN | `pi@mbp: Permission denied (publickey,password,keyboard-interactive).` |
| `udr` | WARN | `Host key verification failed.` |

## Interpretation

This is a sane security posture if Pi is not meant to be an admin jump host.

Recommended policy:

| Flow | Policy |
|---|---|
| Pi -> GitHub | allowed, required for repo sync/nightly automation |
| Pi -> Mac mini | not required by default |
| Pi -> MacBook Pro | not required by default |
| Pi -> UDR-7 | not required by default unless a specific automation needs it |
| Pi -> HAOS/Opti | not required by default unless a specific automation needs it |

## Follow-ups

1. Keep Pi's GitHub key as a narrow-purpose key for repo sync.
2. Do not turn Pi into a broad SSH admin source unless a concrete automation requires it.
3. If Pi ever needs lateral SSH, add explicit host stanzas with correct users, hostnames, `IdentitiesOnly yes`, `ForwardAgent no`, and pinned host keys.
4. Document any future Pi lateral SSH flow before enabling it.

## Safe command pattern

```bash
ssh -T -o BatchMode=yes -o NumberOfPasswordPrompts=0 -o ConnectTimeout=5 git@github.com
ssh -G github.com | awk '/^(hostname|user|port|identityfile|identitiesonly|forwardagent|passwordauthentication|pubkeyauthentication) / { print }'
```

Do not store private keys, raw tokens, or raw SSH configs in Git.
