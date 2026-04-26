# VLANs

| VLAN | Name | Role |
| ---: | --- | --- |
| Native / untagged | Default LAN | Proxmox host management and existing trusted LAN. |
| `30` | Server VLAN | HAOS and Docker VM workloads. |
| IoT VLAN | IoT | Limited access to HAOS only as required. |

Opti switch port plan:

- Native / untagged: Default LAN
- Tagged: VLAN `30`

Proxmox `vmbr0` should be VLAN-aware. VM `101` and VM `102` use tag `30`.
