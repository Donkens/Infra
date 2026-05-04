# Security Docs

This directory collects security-related documentation for the home infrastructure.

## Current documents

| Document | Purpose |
|---|---|
| [`auth-baseline.md`](auth-baseline.md) | Main SSH/authentication baseline for Mac mini, MacBook, Pi, UDR-7, HAOS, Opti, Docker VM, and GitHub flows. |
| [`ssh-hardening.md`](ssh-hardening.md) | SSH hardening baseline for key-only auth, `ForwardAgent no`, known-host handling, host roles, key rotation, and recovery paths. |
| [`secrets-policy.md`](secrets-policy.md) | Repository-wide policy for private keys, tokens, `.env`, raw configs, HA secrets, backups, and secret incident response. |
| [`dns-security.md`](dns-security.md) | DNS security baseline for AdGuard Home, Unbound, UDR DNS bypass prevention, DoT/DNSecure, and DNS change management. |
| [`github-key-cleanup-2026-05-04.md`](github-key-cleanup-2026-05-04.md) | Records the Mac mini GitHub key cleanup from MacBook-oriented key to dedicated GitHub key. |
| [`pi-auth-side-verification-2026-05-04.md`](pi-auth-side-verification-2026-05-04.md) | Pi-side auth verification: GitHub access passes; lateral SSH from Pi remains intentionally limited. |
| [`udr-auth-side-verification-2026-05-04.md`](udr-auth-side-verification-2026-05-04.md) | UDR-side SSH posture: router is an SSH target, not a jump host; active authorized keys documented. |
| [`opti-auth-side-verification-2026-05-04.md`](opti-auth-side-verification-2026-05-04.md) | Opti/Proxmox SSH posture, authorized keys, Proxmox-style local key note, and follow-ups. |
| [`haos-auth-side-verification-2026-05-04.md`](haos-auth-side-verification-2026-05-04.md) | HAOS SSH add-on posture: admin target only, no observed private keys in shell context. |
| [`docker-auth-side-verification-2026-05-04.md`](docker-auth-side-verification-2026-05-04.md) | Docker VM SSH bootstrap status: host key observed, key-only admin login not yet provisioned. |

## Related runbooks

| Runbook | Purpose |
|---|---|
| [`../../runbooks/docker-vm-ssh-bootstrap.md`](../../runbooks/docker-vm-ssh-bootstrap.md) | Planned path for provisioning key-only admin SSH access to the Docker VM through Proxmox console/cloud-init. |

## Policy themes

Security docs in this directory should stay high-signal and sanitized.

- Document fingerprints, roles, allowed flows, and verification commands.
- Do not store private keys, raw tokens, secrets, passwords, or raw service configs.
- Keep operational source-of-truth files outside Git unless they are explicitly sanitized.
- Use key-only SSH checks for automation: `BatchMode=yes`, `NumberOfPasswordPrompts=0`, and short connect timeouts.
- Keep `ForwardAgent no` as the default unless a narrow admin flow is explicitly documented.
- Device-code authorization should be temporary and task-specific, not always-on by default.
- Keep routers, HAOS, and service nodes as SSH targets only unless an outbound SSH flow is explicitly needed and documented.
- Commit `.env.example` placeholders, not real `.env` values.
- Keep raw DNS runtime configs and query logs out of Git unless explicitly sanitized.

## Future candidates

| Candidate | Scope |
|---|---|
| `firewall-baseline.md` | High-level firewall intent and trusted admin paths. |

## Safe review commands

```bash
find docs/security -maxdepth 1 -type f -print | sort
grep -R "PRIVATE KEY\|BEGIN OPENSSH\|password\|token" docs/security || true
```

Do not paste private key material into issues, docs, chats, or tickets.
