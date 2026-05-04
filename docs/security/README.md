# Security Docs

This directory collects security-related documentation for the home infrastructure.

## Current documents

| Document | Purpose |
|---|---|
| [`auth-baseline.md`](auth-baseline.md) | SSH/authentication baseline for Mac mini, MacBook, Pi, UDR-7, HAOS, Opti, and GitHub flows. |

## Policy themes

Security docs in this directory should stay high-signal and sanitized.

- Document fingerprints, roles, allowed flows, and verification commands.
- Do not store private keys, raw tokens, secrets, passwords, or raw service configs.
- Keep operational source-of-truth files outside Git unless they are explicitly sanitized.
- Use key-only SSH checks for automation: `BatchMode=yes`, `NumberOfPasswordPrompts=0`, and short connect timeouts.
- Keep `ForwardAgent no` as the default unless a narrow admin flow is explicitly documented.
- Device-code authorization should be temporary and task-specific, not always-on by default.

## Future candidates

| Candidate | Scope |
|---|---|
| `secrets-policy.md` | Where secrets may live, backup expectations, and what must never be committed. |
| `ssh-hardening.md` | Client/server SSH options, key rotation, and per-host auth rules. |
| `firewall-baseline.md` | High-level firewall intent and trusted admin paths. |
| `dns-security.md` | AdGuard/Unbound security posture, DNS bypass prevention, DoT/DoH notes. |

## Safe review commands

```bash
find docs/security -maxdepth 1 -type f -print | sort
grep -R "PRIVATE KEY\|BEGIN OPENSSH\|password\|token" docs/security || true
```

Do not paste private key material into issues, docs, chats, or tickets.
