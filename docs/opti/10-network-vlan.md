# Opti network and VLAN plan

## Trunk model

The UniFi switch port to the Opti should use:

| Network | Port mode | Purpose |
| --- | --- | --- |
| Default LAN | Native / untagged | Proxmox host management |
| Server VLAN 30 | Tagged | HAOS and Docker VMs |

## Proxmox bridge

`vmbr0` should be VLAN-aware. The Proxmox host uses untagged Default LAN for management. VMs attach to `vmbr0` with VLAN tag `30`.

This file is a plan only. Do not change UniFi, Proxmox, or firewall state from this documentation task.

## Management IPs

| Name | IP | VLAN | Role |
| --- | --- | --- | --- |
| `opti.home.lan` | `192.168.1.60` | Default LAN | Proxmox host |
| `proxmox.home.lan` | `192.168.1.60` | Default LAN | Proxmox UI/API |
| `docker.home.lan` | `192.168.30.10` | Server VLAN 30 | Docker VM |
| `proxy.home.lan` | `192.168.30.10` | Server VLAN 30 | Caddy reverse proxy |
| `ha.home.lan` | `192.168.30.20` | Server VLAN 30 | HAOS |
| `haos.home.lan` | `192.168.30.20` | Server VLAN 30 | HAOS alias |

## VM tags

| VM | VLAN tag | Access |
| --- | ---: | --- |
| `101` HAOS | `30` | `ha.home.lan:8123` direct |
| `102` Debian Docker | `30` | SSH plus Caddy-managed services |
