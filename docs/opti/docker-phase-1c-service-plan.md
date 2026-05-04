# Docker Phase 1C — service plan

## Status

**PLAN ONLY** — no live changes made in this document.

This plan follows the Docker VM 102 baseline completed on 2026-05-04:

- VMID `102`
- Hostname `docker`
- IP `192.168.30.10/24`
- Server VLAN `30`
- DNS `192.168.1.55`
- Docker Engine `29.4.2`
- Docker Compose plugin `v5.1.3`
- Base paths: `/srv/compose`, `/srv/appdata`, `/srv/backups`

No Caddy, Dockge, Uptime Kuma, Dozzle, node_exporter, Vaultwarden, Jellyfin, or
other long-running services are installed at the time this plan is written.

## Goal

Introduce the first lightweight Docker services on VM 102 in small, auditable
steps while keeping the network private and reversible.

Phase 1C should establish the operational baseline for Docker services, not the
full homelab stack.

## Hard rules

- No WAN exposure.
- No public port forwards.
- No secrets committed to Git.
- No `latest` tags for production services.
- No broad firewall openings.
- No `0.0.0.0` binds unless explicitly approved.
- No Vaultwarden until backup and restore-test are complete.
- No Jellyfin/media/download-heavy workloads in Phase 1C.
- Keep each service in its own Compose directory under `/srv/compose/<service>`.
- Keep persistent data under `/srv/appdata/<service>`.
- Add log limits to every Compose service.
- Add explicit restart policies.
- Validate each service before starting the next.

## Proposed service order

| Step | Service | Purpose | Initial exposure | Status |
| --- | --- | --- | --- | --- |
| 1 | Caddy | Internal reverse proxy | LAN only | Planned |
| 2 | Dockge | Compose stack management | LAN only, proxied later | Planned |
| 3 | Uptime Kuma | Internal uptime checks | LAN only, proxied later | Planned |
| 4 | Dozzle | Container log viewer | LAN only, proxied later | Planned |
| 5 | node_exporter | Host metrics | LAN/VLAN scoped only | Optional / later |

Caddy should come first only if the plan explicitly covers local DNS names,
ports, and rollback. If keeping the first phase even smaller, Dockge may be
installed first on a direct LAN-only port and moved behind Caddy later.

## DNS plan

Existing DNS:

| Name | Target | Status |
| --- | --- | --- |
| `docker.home.lan` | `192.168.30.10` | Live for host access |
| `proxy.home.lan` | `192.168.30.10` | Reserved for Caddy/proxy |

Suggested service names:

| Name | Target | Purpose |
| --- | --- | --- |
| `proxy.home.lan` | `192.168.30.10` | Caddy reverse proxy |
| `dockge.home.lan` | `192.168.30.10` | Dockge UI |
| `kuma.home.lan` | `192.168.30.10` | Uptime Kuma UI |
| `dozzle.home.lan` | `192.168.30.10` | Dozzle UI |

Add DNS rewrites only when the related service is installed and validated.

## Port plan

Initial direct ports should remain LAN/internal only. Final service access should
prefer Caddy hostnames.

| Service | Container/default port | Suggested host exposure | Notes |
| --- | ---: | --- | --- |
| Caddy | `80`, `443` | `192.168.30.10:80`, `192.168.30.10:443` only if firewall-approved | Internal reverse proxy only |
| Dockge | `5001` | Direct during bootstrap or behind Caddy | Protect before wider access |
| Uptime Kuma | `3001` | Direct during bootstrap or behind Caddy | Internal monitoring only |
| Dozzle | `8080` | Direct during bootstrap or behind Caddy | Logs may expose sensitive info |
| node_exporter | `9100` | Optional, restricted | Metrics only |

Firewall rules should be added one service at a time and documented in
`inventory/unifi-firewall.md` if created.

## Filesystem layout

Recommended layout:

```text
/srv/compose/
  caddy/
    compose.yml
    Caddyfile
    .env            # chmod 600 if used, never committed
  dockge/
    compose.yml
    .env            # chmod 600 if used, never committed
  uptime-kuma/
    compose.yml
  dozzle/
    compose.yml

/srv/appdata/
  caddy/
  dockge/
  uptime-kuma/
  dozzle/

/srv/backups/
  docker-compose-export/
```

Ownership baseline:

```text
/srv/compose  yasse:docker  775
/srv/appdata  yasse:docker  775
/srv/backups  yasse:docker  775
```

Secrets policy:

- `.env` files stay on VM 102 only.
- `.env` files must be `chmod 600` or stricter.
- Commit only `.env.example` with placeholder values.
- Never commit tokens, passwords, API keys, cookies, or private cert material.

## Compose baseline policy

Every Compose service should include:

```yaml
restart: unless-stopped
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

Avoid:

```yaml
image: some/service:latest
network_mode: host
privileged: true
ports:
  - "0.0.0.0:..."
```

Use pinned or explicit tags when possible.

## Validation checklist per service

Before install:

```bash
ssh docker 'hostname; docker --version; docker compose version; systemctl is-active docker'
ssh docker 'df -h / /srv 2>/dev/null || df -h /'
ssh docker 'systemctl --failed --no-pager'
```

After install:

```bash
ssh docker 'docker ps'
ssh docker 'docker compose -f /srv/compose/<service>/compose.yml ps'
ssh docker 'docker logs --tail=80 <container-name>'
ssh docker 'systemctl --failed --no-pager'
```

Network validation from Mac mini:

```bash
curl -I http://192.168.30.10:<port>/ || true
curl -kI https://proxy.home.lan/ || true
```

DNS validation, when applicable:

```bash
dig @192.168.1.55 <service>.home.lan A +short
```

## Rollback pattern

Per service rollback:

```bash
ssh docker 'cd /srv/compose/<service> && docker compose down'
ssh docker 'docker ps'
```

Full removal, only after confirmation:

```bash
ssh docker 'cd /srv/compose/<service> && docker compose down -v'
ssh docker 'rm -rf /srv/compose/<service> /srv/appdata/<service>'
```

Do not remove appdata with `-v` or `rm -rf` unless data loss is explicitly
accepted.

## Backup gap before heavier services

Before installing services with valuable persistent data, update the Proxmox
backup plan to include VM 102.

Current known status:

| VM | Role | Backup status |
| ---: | --- | --- |
| `101` | HAOS | Manual backup and restore-test baseline exists |
| `102` | Docker | Backup job not yet updated after Docker baseline |

Recommended next backup task:

- Add VM 102 to the Proxmox backup job or create a dedicated VM 102 backup job.
- Run one manual backup after first service stack is installed.
- Copy backup off-host.
- Restore-test before adding sensitive/high-value services.

## Suggested Phase 1C split

### Phase 1C-0 — preflight only

- Verify Docker baseline.
- Verify `/srv` layout.
- Verify Git is clean.
- Verify no unexpected containers are running.
- Produce exact install plan.

### Phase 1C-1 — Caddy or Dockge first

Choose one:

- **Caddy first** if hostnames/reverse proxy are the priority.
- **Dockge first** if Compose management is the priority and direct LAN-only
  access is acceptable temporarily.

### Phase 1C-2 — Uptime Kuma

Install after at least one known-good service exists. Add checks for:

- `docker.home.lan`
- `ha.home.lan`
- `opti.home.lan:8006`
- Pi DNS (`192.168.1.55:53`)
- Caddy/Dockge if installed

### Phase 1C-3 — Dozzle

Install only after log visibility policy is accepted. Treat it as admin-only,
because logs can reveal paths, hostnames, internal URLs, and occasional secrets.

## Not in Phase 1C

- Vaultwarden
- Jellyfin
- Transmission
- Stremio Server
- Prometheus/Grafana
- code-server/OpenVSCode
- MCP/dev workloads
- WAN exposure
- Tailscale subnet changes

## Next action

Run a read-only Phase 1C preflight from Mac mini, then choose whether Caddy or
Dockge should be the first service. Keep the first apply limited to one service
plus docs.
