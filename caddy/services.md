# Caddy service map

Internal `home.lan` routes only. No WAN exposure.

| DNS name | Target IP | Upstream | Notes |
| --- | --- | --- | --- |
| `dockge.home.lan` | `192.168.30.10` | `dockge:5001` | Dockge UI via Caddy. |
| `uptime.home.lan` | `192.168.30.10` | `uptime-kuma:3001` | Uptime Kuma via Caddy. |
| `dozzle.home.lan` | `192.168.30.10` | `dozzle:8080` | Dozzle via Caddy. |
| `stremio.home.lan` | `192.168.30.10` | `stremio:11470` | Stremio Server via Caddy. |
| `ha.home.lan` | `192.168.30.20` | `:8123` direct | Not via Caddy initially. |

`127.0.0.1` inside the Caddy container points to Caddy itself. Use Docker service names on a shared Docker network. If proxying to the Docker host instead, use `192.168.30.10` intentionally and document why.

Each service should have a matching Uptime Kuma check plan before it is considered part of the baseline.
