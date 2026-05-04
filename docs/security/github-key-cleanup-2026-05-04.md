# Mac mini GitHub Key Cleanup — 2026-05-04

Mode: Phase 0 read-only, then Phase 2 apply
Source host: Mac mini (`mini`) / user `yasse`

## Summary

Status: PASS.

Mac mini GitHub SSH auth was moved from the MacBook-oriented key to the dedicated GitHub key.

## Before

`ssh -G github.com` showed:

| Field | Value |
|---|---|
| User | `git` |
| Hostname | `github.com` |
| IdentityFile | `~/.ssh/id_ed25519_mbp` |
| IdentitiesOnly | yes |
| ForwardAgent | no |

## Dedicated GitHub key verified

| Key | Fingerprint | Comment |
|---|---|---|
| `~/.ssh/id_ed25519_github.pub` | `SHA256:KGHIqwLNXxv2S3eNL0pme25KXfowcq3qdlUZONP9WRA` | `github` |

Phase 0 verification confirmed:

- default GitHub SSH auth succeeded
- dedicated `id_ed25519_github` auth succeeded
- `git ls-remote origin HEAD` succeeded with the dedicated GitHub key

## Change applied

A timestamped backup of `~/.ssh/config` was created on Mac mini:

```text
~/.ssh/config.bak-github-key-cleanup-20260504-151724
```

Only the `Host github.com` `IdentityFile` entry was changed:

```diff
- IdentityFile ~/.ssh/id_ed25519_mbp
+ IdentityFile ~/.ssh/id_ed25519_github
```

## After

`ssh -G github.com` showed:

| Field | Value |
|---|---|
| User | `git` |
| Hostname | `github.com` |
| IdentityFile | `~/.ssh/id_ed25519_github` |
| IdentitiesOnly | yes |
| ForwardAgent | no |

## Verification

Result: PASS.

- `ssh -T git@github.com` returned successful authentication for `Donkens`
- `git fetch --dry-run` succeeded
- `git ls-remote origin HEAD` returned `8a3d64cb8c4ab44ee168fe2dabb3d61cb9419f1b`

## Policy note

This is the preferred posture: GitHub access from Mac mini uses a dedicated GitHub key rather than the MacBook key. Keep `ForwardAgent no` for GitHub.
