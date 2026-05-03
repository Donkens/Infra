# HAOS SSH token fix for zsh command mode

Date: 2026-05-03

## Problem

Direct non-interactive HAOS SSH commands from both Mac clients authenticated but the
Home Assistant CLI failed:

```bash
ssh ha 'ha core info'
ssh ha 'ha backups'
ssh ha 'ha resolution info'
ssh haos 'ha core info'
```

Failure mode:

```text
unauthorized: missing or invalid API token
```

The `bash -l -c` workaround did work:

```bash
ssh ha 'bash -l -c "ha core info"'
```

## Root cause

The HAOS SSH add-on user is `hassio` with:

- `SHELL=/bin/zsh`
- `HOME=/home/hassio`
- `/etc/profile.d/homeassistant.sh` present and exporting `SUPERVISOR_TOKEN`
- `/home/hassio/.zshenv` missing before the fix
- `/home/hassio/.zprofile` containing `exec sudo -i`, so login-shell behavior differs

Direct SSH command mode used zsh without loading the Home Assistant Supervisor
environment. The `ha` CLI therefore started without `SUPERVISOR_TOKEN`.

## Fix

Created `/home/hassio/.zshenv`:

```zsh
# Load Home Assistant Supervisor environment for non-interactive zsh SSH commands.
if [ -r /etc/profile.d/homeassistant.sh ]; then
    emulate -L sh
    . /etc/profile.d/homeassistant.sh
fi
```

No prior `/home/hassio/.zshenv` existed, so no backup file was created. No HAOS,
Supervisor, Core, SSH add-on, Proxmox, Pi, UDR, DNS, firewall, VLAN, UniFi,
AdGuard, or Unbound restart/change was required.

## Validation

MacBook `/Users/hd/repos/Infra`:

```text
SUPERVISOR_TOKEN_PRESENT=yes
HA_CORE_DIRECT=PASS
HA_BACKUPS_DIRECT=PASS
HA_RESOLUTION_DIRECT=PASS
HAOS_SUPERVISOR_TOKEN_PRESENT=yes
HAOS_CORE_DIRECT=PASS
INTERACTIVE_SHELL_OK
```

Mac mini `/Users/yasse/repos/Infra`:

```text
MINI_SUPERVISOR_TOKEN_PRESENT=yes
MINI_HA_CORE_DIRECT=PASS
MINI_HA_BACKUPS_DIRECT=PASS
MINI_HA_RESOLUTION_DIRECT=PASS
MINI_HAOS_SUPERVISOR_TOKEN_PRESENT=yes
MINI_HAOS_CORE_DIRECT=PASS
```

SSH key separation remains:

- MacBook: `id_ed25519_mbp`
- Mac mini: `id_ed25519_macmini`

## Rollback

```bash
ssh ha 'rm -f /home/hassio/.zshenv'
```

Rollback removes the user-level zsh environment hook. It does not touch HAOS Core,
Supervisor, the SSH add-on configuration, Proxmox, Pi, UDR, DNS, firewall, VLAN,
UniFi, AdGuard, or Unbound.
