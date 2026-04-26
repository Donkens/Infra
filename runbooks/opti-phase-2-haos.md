# Opti Phase 2 - HAOS VM plan

## Scope

Create VM `101` for Home Assistant OS.

## Spec

| Profile | CPU | RAM | Disk |
| --- | ---: | ---: | ---: |
| Target `32 GB` host | `2 vCPU` | `6 GB` | `64 GB` |
| Low-RAM bootstrap | `2 vCPU` | `4 GB` | `64 GB` |

## Plan

1. Confirm VLAN 30 is working.
2. Create VM `101`.
3. Assign VLAN tag `30`.
4. Set or reserve IP `192.168.30.20`.
5. Confirm direct access at `ha.home.lan:8123`.
6. Create first HAOS backup after bootstrap.

## Rules

- HAOS is not via Caddy initially.
- Take a HAOS backup before HAOS changes.
- Avoid many add-ons until `32 GB` host RAM is installed.
