# AdGuard Home change policy

## Purpose

Define how AI agents and operators may safely inspect and change AdGuard Home on the Raspberry Pi DNS node.

## Current installation

Document only sanitized facts:

- Host role: Raspberry Pi primary DNS node.
- Service: `AdGuardHome.service`
- Working directory: `/home/pi/AdGuardHome`
- Config path: `/home/pi/AdGuardHome/AdGuardHome.yaml`
- Schema version: `34`
- UI: `0.0.0.0:3000`
- DNS: `0.0.0.0:53`
- HTTPS: `443`
- DNS-over-TLS: `853`
- TLS server name: `adguard.home.lan`
- TLS certificate path: `/home/pi/AdGuardHome/certs/fullchain.pem`
- TLS private key path: `/home/pi/AdGuardHome/certs/privkey.pem`
- Upstream DNS: local Unbound at `127.0.0.1:5335`
- Bootstrap DNS count: `2`
- Protection enabled: `true`
- Filtering enabled: `true`
- Blocking mode: `nxdomain`
- Cache size: `33554432`
- Cache TTL min/max: `300` / `86400`
- Optimistic cache: `true`
- DNSSEC: `false`
- DDR: `false`
- Rewrites: `25` count only
- Filters: `4`
- Whitelist filters: `0`
- User rules: `6` count only
- Query log: enabled, memory-only, `file_enabled=false`, interval `24h`, memory size `1000`
- Statistics: enabled, interval `168h`
- Persistent clients: `11` count only
- Runtime client sources: `5` count only

## Safe inventory

AI agents may inventory AdGuard only through sanitized summaries.

Allowed:

- service status
- ports
- version
- paths
- permissions metadata
- sanitized config fields
- counts
- TLS paths only
- upstream host/protocol after removing auth/query tokens

Forbidden:

- raw `AdGuardHome.yaml`
- credentials
- password hashes
- sessions
- private key contents
- raw client lists
- raw rewrites
- raw user rules
- raw query logs
- raw backups

## Preferred change paths

Order of preference:

1. Web UI
2. Authenticated API, only with a non-logged secret-input method
3. Minimal YAML patch as fallback only

Do not paste credentials into prompts, shell commands, repo files, logs, or documentation.

## API/UI first

Use UI/API for supported settings when possible.

Do not hardcode credentials. Do not echo credentials. Do not store session cookies in repo.

## YAML fallback only

Use direct YAML edits only when the setting is not safely available through UI/API or when a controlled offline edit is explicitly requested.

`AdGuardHome.yaml` is root-only and must never be printed raw.

## Required YAML edit workflow

For YAML changes:

1. Phase 0 read-only:
   - identify exact setting
   - show sanitized current value
   - confirm service state and ports
   - prepare rollback

2. Phase 1 plan:
   - show exact intended semantic change
   - show backup command
   - show patch method
   - show validation
   - show restart/start sequence
   - show rollback

3. Phase 2 apply only after explicit GO:
   - create timestamped backup
   - stop AdGuard Home
   - apply minimal patch
   - validate config
   - show redacted diff
   - start AdGuard Home
   - verify DNS and ports

## Required backup

Use timestamped backup before any YAML change:

```bash
TS=$(date +%Y%m%d-%H%M%S)
sudo cp -a /home/pi/AdGuardHome/AdGuardHome.yaml \
  /home/pi/AdGuardHome/AdGuardHome.yaml.bak.$TS
```

## Required validation

Validate config before starting service:

```bash
sudo /home/pi/AdGuardHome/AdGuardHome --check-config \
  --config /home/pi/AdGuardHome/AdGuardHome.yaml
```

If this command syntax differs on installed version, inspect `AdGuardHome --help` and report before applying changes.

## Required stop/edit/validate/start

Preferred service sequence for YAML edits:

```bash
sudo systemctl stop AdGuardHome.service
# apply minimal YAML patch
sudo /home/pi/AdGuardHome/AdGuardHome --check-config \
  --config /home/pi/AdGuardHome/AdGuardHome.yaml
sudo systemctl start AdGuardHome.service
```

Do not use live YAML edits as the default workflow.

## Required redacted diff

Any diff shown to the user must redact:

- users
- password hashes
- sessions
- private keys
- client secrets
- raw query logs
- raw backups
- tokens

Show only the specific changed keys and sanitized context.

## Required DNS verification

After any change:

```bash
systemctl is-active AdGuardHome.service
ss -tulpn | grep -E ':(53|853|3000|443)\b'
dig @127.0.0.1 cloudflare.com A +short
dig @127.0.0.1 google.com A +short
dig @192.168.1.55 cloudflare.com A +short
dig @127.0.0.1 -p 5335 cloudflare.com A +short
```

## Rollback

```bash
sudo systemctl stop AdGuardHome.service
sudo cp -a /home/pi/AdGuardHome/AdGuardHome.yaml.bak.TIMESTAMP \
  /home/pi/AdGuardHome/AdGuardHome.yaml
sudo systemctl start AdGuardHome.service
```

Then verify DNS using the standard verification commands.

## Never document / never print

Never document, print, paste, commit, or broadly copy:

- raw `AdGuardHome.yaml`
- admin credentials
- password hashes
- sessions
- API tokens
- TLS private key contents
- raw client lists
- raw rewrites
- raw user rules
- raw query logs
- raw backup files
- broad copies of `/home/pi/AdGuardHome`

## Related docs

- [Raspberry Pi baseline](raspberry-pi-baseline.md)
- [DNS/TLS cleanup baseline](dns-tls-baseline-2026-04-26.md)
- [Pi DNS Runbook](runbook.md)
- [Restore Guide](restore.md)
