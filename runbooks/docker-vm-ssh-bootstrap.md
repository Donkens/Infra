# Docker VM SSH Bootstrap Runbook

Status: planned
Target: Docker VM on Server VLAN
Purpose: provision key-only admin SSH access after initial VM install

## Current state

Docker VM presents a stable SSH host key, but key-only login from the MacBook admin client is not yet provisioned for the tested admin users.

## Goal

Provision one intended admin public key through a trusted local path, then verify key-only SSH access with batch mode.

## Guardrails

- Do not paste or store private keys.
- Do not enable password SSH for ongoing administration.
- Do not add broad lateral SSH access from the Docker VM unless a concrete automation needs it.
- Prefer `ForwardAgent no`.
- Keep Docker secrets, `.env` files, and compose secrets out of Git.

## Recommended bootstrap path

Use the Proxmox console or cloud-init for the Docker VM. Add the selected admin public key to the intended user account inside the VM.

Recommended target user options:

| User | When to use |
|---|---|
| `root` | acceptable for early bootstrap only, especially before a normal admin user exists |
| `yasse` | preferred long-term admin user if created with sudo access |

## Client-side SSH config after verification

Add an explicit stanza on admin clients only after the correct user is confirmed:

```sshconfig
Host docker
  HostName 192.168.30.10
  User yasse
  IdentityFile ~/.ssh/id_ed25519_mbp
  IdentitiesOnly yes
  ForwardAgent no
```

Adjust `User` and `IdentityFile` per host. On Mac mini, use its intended key. On MacBook, use the MBP key.

## Validation commands

Run from the admin client after provisioning:

```bash
ssh -o BatchMode=yes -o NumberOfPasswordPrompts=0 -o ConnectTimeout=5 yasse@192.168.30.10 'hostname; whoami; uname -a'
ssh -o BatchMode=yes -o NumberOfPasswordPrompts=0 -o ConnectTimeout=5 root@192.168.30.10 'hostname; whoami; uname -a'
```

Expected result: exactly one intended admin account succeeds with key-only auth.

## Follow-up docs

After SSH works, rerun the Docker VM auth-side inventory and update:

- `docs/security/docker-auth-side-verification-2026-05-04.md`
- Docker VM baseline docs under `docs/opti/` if needed
