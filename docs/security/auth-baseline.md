# Auth Baseline

Last verified: 2026-05-04 14:42 CEST
Source host: Mac mini (`mini`) / user `yasse`
Mode: read-only inventory from local SSH config and remote key-only checks

## Summary

Status: PASS with notes.

This document records the current SSH authentication baseline for the home infrastructure. It intentionally stores only key fingerprints, host roles, users, and policy notes. It must not contain private keys, raw tokens, raw secrets, or full sensitive config files.

## GitHub / repo baseline

| Item | Value |
|---|---|
| GitHub account | `Donkens` |
| Repo remote | `git@github.com:Donkens/Infra.git` |
| Default branch | `main` |
| Local repo host | `mini` |
| Local repo path | `/Users/yasse/repos/Infra` |
| Local status during check | `main...origin/main` |

Note: `gh` CLI was not installed on the Mac mini during this inventory, so GitHub account SSH-key registration was not verified from the local CLI.

## Local admin host: Mac mini

| Item | Value |
|---|---|
| Hostname | `mini` |
| User | `yasse` |
| Home | `/Users/yasse` |
| OS | macOS Darwin 25.5.0 ARM64 |
| Role | Primary admin/client host |

## SSH client config summary from Mac mini

| Target | SSH user | Hostname | IdentityFile | IdentitiesOnly | ForwardAgent |
|---|---|---|---|---:|---:|
| GitHub | `git` | `github.com` | `~/.ssh/id_ed25519_mbp` | yes | no |
| Pi | `pi` | `pi.home.lan` | `~/.ssh/id_ed25519_pi` | yes | no |
| Mac mini | `yasse` | `macmini.home.lan` | `~/.ssh/id_ed25519_macmini` | yes | yes |
| MacBook Pro | `hd` | `mbp.home.lan` | `~/.ssh/id_ed25519_mbp` | yes | no |
| UDR-7 | `root` | `udr.home.lan` | `~/.ssh/id_ed25519_udr2` | yes | no |
| HAOS | `hassio` | `ha.home.lan` | `~/.ssh/id_ed25519_macmini` | yes | no |
| Opti | `root` | `opti.home.lan` | `~/.ssh/id_ed25519_macmini` | yes | no |

Note: `PasswordAuthentication` appeared as `yes` in the client-side expanded config. This does not prove the server accepts password login; it only means the local client does not globally disable password auth for these hosts. For automation and audits, use `BatchMode=yes` and `NumberOfPasswordPrompts=0`.

## Local public key inventory on Mac mini

| Public key | Fingerprint | Comment |
|---|---|---|
| `ecdsa-sha2-nistp256-shellfish@iphone-enclave-02122025.pub` | `SHA256:rZWqMKnZ2Ta0LToejW7dsCrqJQW+jkAX2eyjZKJhcms` | `ShellFish@iPhone-Enclave-02122025` |
| `id_ed25519_github.pub` | `SHA256:KGHIqwLNXxv2S3eNL0pme25KXfowcq3qdlUZONP9WRA` | `github` |
| `id_ed25519_macmini.pub` | `SHA256:IxV/v8tpNBG542/yNj1g3nz1AbwGnpQfbJwQJZx+9A0` | `macmini@home.lan` |
| `id_ed25519_mbp.pub` | `SHA256:Tc/gNhhJ+/Cwkui/1T36YVwHSs1quLjGK7J0MbItpaU` | `mbp@home.lan` |
| `id_ed25519_neoserver.pub` | `SHA256:UbErkFhmVHGXGAdvn4Znzm09AMBKsqLeexWlYLIcLQc` | `neoserver@macmini` |
| `id_ed25519_pi_claude.pub` | `SHA256:J0jYnqsGMKBAGIViLuTGvjthNWdvSNAhGwMUOMC+skc` | `pi-claude-nopass` |
| `id_ed25519_pi.pub` | `SHA256:U1atPM5FFTUrHPYE9dg4w1Yr0hye9XovIC2VJhy3M5w` | `pi@home.lan` |
| `id_ed25519_udr2.pub` | `SHA256:zorJul5YiPwIV2PkmKghWE/yn7Nl7M9u7mh0MPYZ5Lw` | `udr7` |
| `id_ed25519.pub` | `SHA256:omWAIS2qDhY7kIZYFW66Q2iPMSbavF+y4re8Ll7aaCI` | `yasse@Mac-mini.local` |

## SSH agent loaded keys on Mac mini

| Fingerprint | Comment |
|---|---|
| `SHA256:U1atPM5FFTUrHPYE9dg4w1Yr0hye9XovIC2VJhy3M5w` | none shown |
| `SHA256:IxV/v8tpNBG542/yNj1g3nz1AbwGnpQfbJwQJZx+9A0` | none shown |
| `SHA256:Tc/gNhhJ+/Cwkui/1T36YVwHSs1quLjGK7J0MbItpaU` | none shown |
| `SHA256:zorJul5YiPwIV2PkmKghWE/yn7Nl7M9u7mh0MPYZ5Lw` | `udr7` |

## Remote key-only checks

The following checks succeeded with `BatchMode=yes`, `NumberOfPasswordPrompts=0`, and `ConnectTimeout=5` from Mac mini. That confirms non-interactive SSH key auth works for these hosts from the current Mac mini setup.

### Raspberry Pi DNS node

| Item | Value |
|---|---|
| SSH target | `pi` |
| Runtime hostname | `pi` |
| User | `pi` |
| Home | `/home/pi` |
| Kernel | Linux `6.12.75+rpt-rpi-v8` aarch64 |
| `.ssh` mode | `drwx------` |
| `authorized_keys` mode | `rw-------` |

Remote public key present on Pi:

| Fingerprint | Comment |
|---|---|
| `SHA256:w21zRgqkJ5Tc4FZ62SjEC7v77zRVspiCzrRKrsYFUhs` | `pi-github` |

Authorized client keys on Pi:

| Fingerprint | Comment |
|---|---|
| `SHA256:U1atPM5FFTUrHPYE9dg4w1Yr0hye9XovIC2VJhy3M5w` | `ShellFish@RaspberryPie` |
| `SHA256:J0jYnqsGMKBAGIViLuTGvjthNWdvSNAhGwMUOMC+skc` | `pi-claude-nopass` |
| `SHA256:UbErkFhmVHGXGAdvn4Znzm09AMBKsqLeexWlYLIcLQc` | `neoserver@macmini` |

### MacBook Pro admin client

| Item | Value |
|---|---|
| SSH target | `mbp` |
| Runtime hostname | `mbp` |
| User | `hd` |
| Home | `/Users/hd` |
| OS | macOS Darwin 24.6.0 x86_64 |
| `.ssh` mode | `drwx------` |
| `authorized_keys` mode | `rw-------` |

Remote public keys present on MacBook:

| Fingerprint | Comment |
|---|---|
| `SHA256:IxV/v8tpNBG542/yNj1g3nz1AbwGnpQfbJwQJZx+9A0` | no comment |
| `SHA256:Tc/gNhhJ+/Cwkui/1T36YVwHSs1quLjGK7J0MbItpaU` | no comment |
| `SHA256:U1atPM5FFTUrHPYE9dg4w1Yr0hye9XovIC2VJhy3M5w` | no comment |
| `SHA256:zorJul5YiPwIV2PkmKghWE/yn7Nl7M9u7mh0MPYZ5Lw` | `udr7` |

Authorized client keys on MacBook:

| Fingerprint | Comment |
|---|---|
| `SHA256:Tc/gNhhJ+/Cwkui/1T36YVwHSs1quLjGK7J0MbItpaU` | `ShellFish@MacBookPro` |

### UDR-7 router

| Item | Value |
|---|---|
| SSH target | `udr` |
| Runtime hostname | `udrhomelan` |
| User | `root` |
| Home | `/root` |
| Kernel | Linux `5.4.213-ui-ipq5322-wireless` aarch64 |
| `.ssh` mode | `drwx------` |
| `authorized_keys` mode | `rw-------` |

Authorized client keys on UDR-7:

| Fingerprint | Comment |
|---|---|
| `SHA256:zorJul5YiPwIV2PkmKghWE/yn7Nl7M9u7mh0MPYZ5Lw` | `udr7` |
| `SHA256:UbErkFhmVHGXGAdvn4Znzm09AMBKsqLeexWlYLIcLQc` | `neoserver@macmini` |

Note: UDR SSH emitted an OpenSSH warning that the connection is not using a post-quantum key exchange algorithm. This is expected for many embedded/network appliances and is not an immediate LAN issue, but it should be tracked as a vendor/OpenSSH capability note.

## Policy baseline

### Allowed flows

| Flow | Status | Notes |
|---|---:|---|
| Mac mini -> Pi | allowed | Key-only auth verified |
| Mac mini -> MacBook | allowed | Key-only auth verified |
| Mac mini -> UDR-7 | allowed | Key-only auth verified; root user expected for UDR |
| Mac mini -> GitHub | allowed | Uses SSH remote; local `gh` CLI not installed during check |
| Agents -> infra hosts | conditional | Must follow repo guardrails and Phase 0/1/2 approval model |

### Blocked / discouraged flows

| Flow | Policy |
|---|---|
| Raw secrets in Git | forbidden |
| Private SSH keys in Git | forbidden |
| Raw `AdGuardHome.yaml` in Git | forbidden |
| Password prompts in automation | discouraged; use `BatchMode=yes` |
| Agent forwarding by default | discouraged; default should be `ForwardAgent no` |
| Device-code auth always enabled | discouraged; only enable when a headless/browserless Codex login requires it |

## Notes / follow-ups

1. Consider switching GitHub from `id_ed25519_mbp` to the dedicated `id_ed25519_github` key on Mac mini, if that key is registered with GitHub.
2. Consider setting client-side `PasswordAuthentication no` for infra hosts where key-only operation is expected.
3. Keep `ForwardAgent no` by default. Only allow forwarding for a narrow, documented admin flow if required.
4. Review whether `id_ed25519_pi_claude` should remain nopass. If retained, document its exact scope and constraints.
5. Old UDR retire/metadata files exist under `~/.ssh` on Mac mini. They should not be copied into the repo. Optional local cleanup can be done later after confirming they are no longer needed.
6. Install or use `gh` CLI only if GitHub-side key inventory needs to be verified locally; otherwise repo access via SSH is enough for day-to-day work.

## Safe audit commands

Use these patterns for future auth audits:

```bash
ssh -o BatchMode=yes -o NumberOfPasswordPrompts=0 -o ConnectTimeout=5 pi 'hostname; whoami'
ssh -G pi | awk '/^(hostname|user|port|identityfile|identitiesonly|forwardagent|passwordauthentication|pubkeyauthentication) / { print }'
ssh-add -l
```

Do not print private key contents. Do not paste private keys into chats, issues, docs, or tickets.
