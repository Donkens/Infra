# HAOS QEMU Guest Agent audit

Date: 2026-05-03

## Summary

Status: WARN.

HAOS VM `101` on Proxmox host `opti` has the Proxmox QEMU Guest Agent VM
option enabled, but the guest does not respond to QEMU Guest Agent commands.
No changes were made.

## Environment

```text
Proxmox host: opti
Proxmox version: pve-manager/9.1.9
Kernel: 7.0.0-3-pve
VMID: 101
VM name: haos
```

## Evidence

Selected `qm config 101` fields:

```text
agent: enabled=1
bios: ovmf
boot: order=scsi0
machine: q35
name: haos
net0: virtio=BC:24:11:AC:C1:DA,bridge=vmbr0,tag=30
ostype: l26
scsihw: virtio-scsi-single
```

QEMU Guest Agent check:

```text
qm agent 101 ping
QEMU guest agent is not running
QGA_PING=FAIL rc=255
```

Because `qm agent 101 ping` failed, Proxmox could not collect:

```text
qm agent 101 network-get-interfaces
qm agent 101 get-host-name
qm agent 101 get-osinfo
```

## Interpretation

The Proxmox VM option is enabled with `agent: enabled=1`, so no `qm set`
change is needed for the VM option. The warning is guest-side: HAOS does not
currently run or expose a responding QEMU Guest Agent in this build/config.

## Recommendation

Keep this as a known WARN baseline unless future HAOS support changes.

Do not run:

```bash
qm set 101 --agent enabled=1
```

That setting is already present. Do not install packages inside HAOS for this;
HAOS is an appliance OS and should not be modified like a general Linux guest.

## HAOS health validation

HAOS itself remained healthy through the SSH add-on and `ha` CLI:

```text
HA_CLI_OK
issues: []
suggestions: []
unhealthy: []
unsupported: []
```

## Scope exclusions

No changes were made to:

- Proxmox VM options
- HAOS
- Home Assistant Core config
- Pi
- UDR
- DNS
- AdGuard
- Unbound
- firewall
- VLANs
- UniFi

## Rollback

None. This was a read-only audit and documentation update only.
