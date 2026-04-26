# Opti Phase 3 - Docker services plan

## Scope

Create VM `102` for Debian Docker and add light baseline services.

## Spec

| Profile | CPU | RAM | Disk |
| --- | ---: | ---: | ---: |
| Target `32 GB` host | `6 vCPU` | `18 GB` | `200 GB` |
| Low-RAM bootstrap | `2-4 vCPU` | `4-8 GB` | `80-120 GB` |

## Baseline services

- Docker Engine + Compose
- Caddy
- Dockge
- Uptime Kuma
- Dozzle
- `node_exporter`
- Stremio Server only if resources allow

## Defer if RAM is below `32 GB`

- MCP/dev services
- code-server/OpenVSCode
- Vaultwarden
- Prometheus/Grafana
- Jellyfin
- heavy downloads/media

## Rules

- Use `/srv/compose` for compose projects.
- Use `/srv/appdata` for persistent app data.
- Back up compose and env material before stack changes.
- Use `env.example` only in repo.
- Add restart policy and log limits to every service.
