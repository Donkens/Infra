# Secrets Policy

Status: baseline
Scope: Infra repo, home infrastructure hosts, DNS stack, Proxmox/VMs, Docker services, HAOS, and agent workflows.

## Summary

This repository may document infrastructure, fingerprints, sanitized exports, runbooks, and verification outputs. It must not store private keys, raw tokens, passwords, raw service configs with secrets, or application secrets.

The goal is simple: Git is for safe documentation and sanitized state. Runtime secrets live on the systems that need them, with backups handled through documented backup paths.

## Never commit

| Item | Policy |
|---|---|
| Private SSH keys | Never commit or paste. Includes `id_*` private keys and host private keys. |
| API tokens / access tokens | Never commit. Includes GitHub, Home Assistant, Cloudflare, Tailscale, UniFi, Proxmox, and app tokens. |
| Passwords | Never commit, even temporary/bootstrap passwords. |
| `.env` files with values | Never commit if they contain secrets. Commit only `.env.example` with placeholders. |
| Raw `AdGuardHome.yaml` | Never commit raw runtime config. Use sanitized exports only. |
| Home Assistant `secrets.yaml` | Never commit. Document keys/shape only if needed, without values. |
| Proxmox secrets / cluster keys | Never commit or paste. |
| Docker compose secrets | Never commit secret values. Prefer `.env`, Docker secrets, or service-specific secret storage outside Git. |
| Raw backups | Never commit raw backup archives or runtime backup directories containing secrets. |
| Browser/session/device-code tokens | Never commit or paste. Device-code auth should be temporary and task-specific. |

## Allowed in Git

| Item | Allowed when |
|---|---|
| SSH public key fingerprints | Allowed. Fingerprints and comments are safe for auth documentation. |
| Public keys | Allowed only when intentionally documenting or provisioning public auth material. Prefer fingerprints in docs. |
| Sanitized config exports | Allowed when secrets are replaced with placeholders such as `<SECRET_PRESENT>` / `<MISSING>`. |
| Runbooks | Allowed. Commands must avoid printing raw secrets. |
| `.env.example` | Allowed with placeholder values only. |
| Service inventories | Allowed when they include roles, ports, hostnames, and non-secret metadata. |
| Verification logs | Allowed if sanitized and free of private keys/tokens/passwords. |

## Host/source-of-truth model

| Area | Source of truth | Git posture |
|---|---|---|
| Pi DNS runtime | Pi live config and services | Git stores sanitized exports, docs, scripts, and runbooks. |
| AdGuard Home | `/home/pi/AdGuardHome` runtime | Raw config stays off Git; sanitized snapshots may be tracked. |
| Unbound | `/etc/unbound` runtime | Safe local-zone/PTR docs may be tracked; avoid dumping sensitive runtime state blindly. |
| UDR-7 | UniFi/UDR runtime | Git stores docs and sanitized verification, not raw secrets. |
| Proxmox/Opti | Opti runtime | Git stores baseline/runbooks; raw host keys and cluster secrets stay off Git. |
| Docker VM | VM runtime | Git stores compose/runbooks/examples; `.env` and appdata secrets stay off Git. |
| HAOS | HAOS/Supervisor runtime | Git stores docs; tokens, `secrets.yaml`, and add-on secret values stay off Git. |
| Mac mini / MacBook | Local admin clients | Git stores docs/runbooks; private SSH keys and local keychains stay local. |

## Docker and app secrets

Docker service secrets must follow these rules:

1. Commit `compose.yaml` only when it contains no secret values.
2. Commit `.env.example`, not `.env`.
3. Store real `.env` files on the Docker VM with mode `0600` where practical.
4. Avoid `latest` tags for production-like services unless explicitly documented.
5. Back up compose files and `.env` files through a documented backup flow before major changes.
6. Do not deploy Vaultwarden or other secret-critical services until backup and restore tests are documented.

Recommended local pattern on the Docker VM:

```bash
chmod 600 .env
```

Do not paste `.env` values into chat, issues, commit messages, or runbooks.

## Home Assistant secrets

Home Assistant secret material includes:

- `secrets.yaml`
- long-lived access tokens
- add-on options containing tokens/passwords
- integration credentials
- MQTT/API passwords

Policy:

- Do not commit these values.
- Do not print them during audits.
- Document only the existence of required secret keys, not their values.
- Prefer Home Assistant UI/Supervisor-safe workflows for auth review.

## SSH keys and auth material

| Material | Policy |
|---|---|
| Private client keys | Stay on the client host only. Never commit or paste. |
| Private host keys | Stay on the host only. Never commit or paste. |
| Public keys | May be installed on hosts; docs should prefer fingerprints. |
| `authorized_keys` | May be summarized by fingerprints; avoid raw dumps unless intentionally sanitized. |
| `known_hosts` | May be summarized by host/fingerprint; avoid noisy raw dumps. |
| Agent forwarding | Default `ForwardAgent no`. Enable only for narrow documented admin flows. |

## Backups

Backup policy:

- Raw backups stay outside Git.
- Off-host backups must have documented source, destination, schedule, and restore test where possible.
- Restore drills should record sanitized output only.
- Backup manifests/checksums may be documented when they do not leak secrets.

Known good pattern:

- Pi DNS raw backups: Pi runtime/state and off-Pi backup location.
- Git: sanitized docs, scripts, inventories, and restore runbooks.

## Device-code auth

Device-code authorization may be used for headless/browserless logins such as SSH sessions or CLI setup.

Policy:

- Use only when needed.
- Do not keep it enabled broadly if not required.
- Never paste device codes into issues/docs/chats.
- Treat unexpected device-code prompts as suspicious.

## Safe review commands

Use these from the repo root as a quick local scan. They are not a full secret scanner, but they catch obvious accidents.

```bash
grep -R "BEGIN OPENSSH PRIVATE KEY\|BEGIN RSA PRIVATE KEY\|BEGIN PRIVATE KEY" . --exclude-dir=.git || true
grep -R "github_pat_\|ghp_\|gho_\|ghu_\|ghs_\|ghr_" . --exclude-dir=.git || true
grep -R "LONG_LIVED_ACCESS_TOKEN\|SUPERVISOR_TOKEN\|CF_API_TOKEN\|TAILSCALE_AUTHKEY" . --exclude-dir=.git || true
find . -name '.env' -o -name '*secrets*.yaml' -o -name 'AdGuardHome.yaml'
```

Expected result: no private keys or raw secret files tracked in Git.

## Commit checklist

Before committing security/runtime docs:

- [ ] No private keys.
- [ ] No tokens.
- [ ] No passwords.
- [ ] No raw `.env`.
- [ ] No raw `AdGuardHome.yaml`.
- [ ] No Home Assistant `secrets.yaml`.
- [ ] No raw backup archives.
- [ ] Public auth material is documented by fingerprint where possible.
- [ ] Commands avoid printing secrets.

## Incident response if a secret is committed

1. Stop using the exposed secret immediately.
2. Rotate/revoke the secret at the source system.
3. Remove the secret from the repo history if needed.
4. Document the incident with sanitized details only.
5. Verify all affected hosts/services use the rotated value.

Do not rely on deleting a file in a later commit as sufficient cleanup for leaked secrets.
