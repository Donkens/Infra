# VM 101 - HAOS

| Field | Value |
| --- | --- |
| VM ID | `101` |
| Role | Home Assistant OS |
| VLAN tag | `30` |
| IP | `192.168.30.20` |
| DNS | `ha.home.lan`, `haos.home.lan` |
| Initial URL | `ha.home.lan:8123` |
| Caddy | Not initially |

## Profiles

| Profile | CPU | RAM | Disk | Policy |
| --- | ---: | ---: | ---: | --- |
| Target `32 GB` host | `2 vCPU` | `6 GB` | `64 GB` | Normal baseline. |
| Low-RAM bootstrap | `2 vCPU` | `4 GB` | `64 GB` | Temporary minimum; upgrade before many add-ons. |

Take a HAOS backup before HAOS changes.
