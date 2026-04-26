# HAOS VM 101

## Role

VM `101` runs Home Assistant OS, Supervisor, add-ons, and HA backups.

Initial access is direct: `http://ha.home.lan:8123`.

HAOS is not routed through Caddy initially.

## VM spec

| Profile | CPU | RAM | Disk | Notes |
| --- | ---: | ---: | ---: | --- |
| Target `32 GB` host | `2 vCPU` | `6 GB` | `64 GB` | Normal baseline. |
| Low-RAM bootstrap | `2 vCPU` | `4 GB` | `64 GB` | Temporary minimum for basic bootstrap. |

## Network

| Field | Value |
| --- | --- |
| VLAN tag | `30` |
| IP | `192.168.30.20` |
| DNS | `ha.home.lan`, `haos.home.lan` |
| URL | `ha.home.lan:8123` |

## Backup rule

Create a HAOS backup before HAOS changes, add-ons, major integrations, or restore experiments. Export or copy important backups to the planned external backup destination once available.
