# Debian Docker VM 102

## Role

VM `102` runs Debian with Docker Engine and Compose. It owns Docker services, Caddy, Dockge, Uptime Kuma, Dozzle, `node_exporter`, Stremio Server when resources allow, and later MCP/dev services after the `32 GB` RAM upgrade.

## VM spec

| Profile | CPU | RAM | Disk | Notes |
| --- | ---: | ---: | ---: | --- |
| Target `32 GB` host | `6 vCPU` | `18 GB` | `200 GB` | Initial target baseline. |
| Low-RAM bootstrap | `2-4 vCPU` | `4-8 GB` | `80-120 GB` | Use only light baseline services. |

## Network

| Field | Value |
| --- | --- |
| VLAN tag | `30` |
| IP | `192.168.30.10` |
| DNS | `docker.home.lan`, `proxy.home.lan` |

## Baseline services

Safe before `32 GB` when memory pressure is acceptable:

- Docker Engine + Compose
- Caddy
- Dockge
- Uptime Kuma
- Dozzle
- `node_exporter`
- Stremio Server only if resources allow
- Incident note: [Uptime Kuma high CPU incident (2026-05-05)](uptime-kuma-high-cpu-incident-2026-05-05.md)

Defer until `32 GB`:

- MCP/dev services
- code-server/OpenVSCode
- Prometheus/Grafana
- Vaultwarden
- heavy media/download workloads
- local media library

## Filesystem policy

| Path | Purpose |
| --- | --- |
| `/srv/compose` | Compose projects and `env.example` references. |
| `/srv/appdata` | App data, configs, small databases. |

Back up `/srv/compose` and important `/srv/appdata` before stack changes.

## Docker defaults

- Add restart policies.
- Add Docker logging limits.
- Avoid `latest` tags in production examples unless documented.
- Avoid host networking unless documented.
- Avoid privileged mode unless explicitly required.
- Do not bind admin services to public/WAN paths.
