# Security boundaries

> What may and may not be stored in this Git repository.

## Allowed in Git

- Sanitized summaries (counts, masked values, structural overviews)
- Masked MACs (e.g. `xx:xx:xx:xx:ab:cd`)
- Internal IPs and hostnames
- Resource IDs where they are needed for operational docs
- Docs, runbooks, scripts, and config templates clearly marked as examples

## Never in Git

| Category | Examples |
|---|---|
| Credentials | passwords, passphrases, tokens, cookies, session data |
| Private keys | TLS private keys, cert private keys, WireGuard keys, SSH private keys |
| WiFi secrets | PSK, WiFi passwords |
| Full MAC inventory | complete hardware MAC address lists |
| WAN IP | public WAN IP address |
| Raw configs | `AdGuardHome.yaml`, raw Unbound config with live internals |
| Raw query logs | DNS query logs, access logs |
| Raw backup contents | `state/backups/` contents, backup archives |
| Environment files | `.env`, any file containing live secrets |

## Local-only paths (never tracked)

These paths exist on Pi and are gitignored:

- `state/` — runtime state files
- `logs/` — service log files
- `state/backups/` — DNS backup archives

Only `.gitkeep` placeholders are tracked under these directories.

## Agent rules

- Never paste raw config output in a chat session or commit message.
- Summarize service state as counts and status flags, not raw content.
- Use sanitized artifacts (e.g. `AdGuardHome.summary.sanitized.yml`) for tracked exports.
- If a secret is accidentally printed or committed, rotate the affected credential immediately.

## Related

- [AGENTS.md](../AGENTS.md)
- [docs/raspberry-pi-baseline.md](raspberry-pi-baseline.md)
- [docs/automation.md](automation.md)
