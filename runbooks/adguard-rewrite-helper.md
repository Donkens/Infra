# AdGuard DNS rewrite helper

## Purpose

Safely add, check, summarize, and delete allowlisted AdGuard Home DNS rewrites on the Raspberry Pi DNS node without reading or editing raw `AdGuardHome.yaml`.

Target installed command:

```bash
sudo /usr/local/sbin/adguard-rewrite add termix.home.lan 192.168.30.10
```

## Safety model

- API-only: uses `POST /control/login`, `GET /control/rewrite/list`, `POST /control/rewrite/add`, and `POST /control/rewrite/delete`.
- No raw `AdGuardHome.yaml` read/write.
- No service restart.
- No direct YAML patch.
- No broad `sudo`.
- No credentials in Git, prompts, shell history, or logs.
- Helper logs action, normalized domain, requested answer, result, and `SUDO_USER` via syslog/journald.
- Helper never logs credentials, cookies, raw API bodies, or full raw rewrite lists.

## Input restrictions

The helper intentionally supports only the narrow current home-lab use case:

- exact FQDN only
- must end with `.home.lan`
- lowercase normalization
- no wildcard records
- DNS-label regex validation
- IPv4 only
- RFC1918 private IPv4 only
- `delete` requires exact `domain + answer`
- `add` is idempotent when exact entry already exists
- `add` fails if the same domain already exists with a different answer

## Repo files

- Source helper: `scripts/dns/adguard-rewrite`
- Sudoers template: `config/sudoers/adguard-rewrite`
- Tests: `tests/test_adguard_rewrite_validation.py`
- Policy: `docs/adguard-home-change-policy.md`

## Manual credential setup

Credential setup is operator-only and must happen on the Pi after the helper is installed. Do not create this file from an agent prompt.

Expected path:

```bash
/root/.config/infra/adguard-rewrite.env
```

Expected ownership/mode:

```bash
root:root 0600
```

Expected keys:

```bash
ADGUARD_URL=https://127.0.0.1
ADGUARD_USERNAME=<operator-provided username>
ADGUARD_PASSWORD=<operator-provided password>
```

If credentials are ever echoed into chat, terminal logs, Git, or shell history, rotate the AdGuard password.

## Install flow

Phase 1 should review exact files and commands. Phase 2 applies only after explicit `GO`.

```bash
ssh pi 'cd /home/pi/repos/infra && git status --short --branch'
ssh pi 'sudo install -o root -g root -m 0755 /home/pi/repos/infra/scripts/dns/adguard-rewrite /usr/local/sbin/adguard-rewrite'
ssh pi 'sudo install -o root -g root -m 0440 /home/pi/repos/infra/config/sudoers/adguard-rewrite /etc/sudoers.d/adguard-rewrite && sudo visudo -c -f /etc/sudoers.d/adguard-rewrite'
```

Credential creation is separate from the repo install and remains operator-only.

## Command interface

```bash
sudo /usr/local/sbin/adguard-rewrite add <name.home.lan> <rfc1918-ipv4>
sudo /usr/local/sbin/adguard-rewrite delete <name.home.lan> <rfc1918-ipv4>
sudo /usr/local/sbin/adguard-rewrite check <name.home.lan> [rfc1918-ipv4]
sudo /usr/local/sbin/adguard-rewrite list --summary
```

Exit codes:

| Code | Meaning |
|---:|---|
| `0` | success |
| `2` | usage or validation error |
| `3` | credential/config error |
| `4` | AdGuard API error |
| `5` | conflict |
| `6` | exact rewrite not found |

## Validation flow

After install and credential setup:

```bash
ssh pi 'sudo -n /usr/local/sbin/adguard-rewrite list --summary'
ssh pi 'sudo -n /usr/local/sbin/adguard-rewrite check termix.home.lan 192.168.30.10'
```

After adding a specific rewrite:

```bash
ssh pi 'sudo -n /usr/local/sbin/adguard-rewrite add termix.home.lan 192.168.30.10'
ssh pi 'dig @127.0.0.1 termix.home.lan A +short'
ssh pi 'dig @192.168.1.55 termix.home.lan A +short'
ssh pi 'systemctl is-active AdGuardHome.service unbound.service'
```

Expected result for `termix.home.lan`:

```text
192.168.30.10
```

## Rollback for one rewrite

Delete only the exact rewrite that was added:

```bash
ssh pi 'sudo -n /usr/local/sbin/adguard-rewrite delete termix.home.lan 192.168.30.10'
ssh pi 'dig @127.0.0.1 termix.home.lan A +short'
```

If the name should no longer resolve, `dig` should return no A answer.

## Helper rollback

Removing the helper does not modify AdGuard rewrites. It only removes the installed wrapper and sudoers rule:

```bash
ssh pi 'sudo rm /usr/local/sbin/adguard-rewrite /etc/sudoers.d/adguard-rewrite'
```

Use this only in an approved Phase 2 rollback.
