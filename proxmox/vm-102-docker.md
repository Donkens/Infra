# VM 102 - Debian Docker

| Field | Value |
| --- | --- |
| VM ID | `102` |
| Role | Debian Docker services |
| VLAN tag | `30` |
| IP | `192.168.30.10` |
| DNS | `docker.home.lan`, `proxy.home.lan` |

## Profiles

| Profile | CPU | RAM | Disk | Policy |
| --- | ---: | ---: | ---: | --- |
| Target `32 GB` host | `6 vCPU` | `18 GB` | `200 GB` | Normal baseline. |
| Low-RAM bootstrap | `2-4 vCPU` | `4-8 GB` | `80-120 GB` | Use light services only. |

Baseline services: Docker Engine + Compose, Caddy, Dockge, Uptime Kuma, Dozzle, `node_exporter`, and Stremio Server only if resources allow.

Defer MCP/dev services, code-server/OpenVSCode, Vaultwarden, Prometheus/Grafana, and heavy media until `32 GB`.
