# Caddy service map

Internal `home.lan` routes only. No WAN exposure.

As of Phase 1C-C3b (2026-05-05), Caddy serves both HTTP and HTTPS for the live
Docker VM service routes. HTTPS uses Caddy `tls internal`; HTTP routes are kept
for Uptime Kuma monitor stability during transition.

| DNS name | Target IP | Upstream | Notes |
| --- | --- | --- | --- |
| `dockge.home.lan` | `192.168.30.10` | `dockge:5001` | Dockge UI via Caddy. |
| `kuma.home.lan` | `192.168.30.10` | `uptime-kuma:3001` | Uptime Kuma via Caddy. |
| `dozzle.home.lan` | `192.168.30.10` | `dozzle:8080` | Dozzle via Caddy. |
| `stremio.home.lan` | `192.168.30.10` | `stremio:11470` | Stremio Server via Caddy. |
| `ha.home.lan` | `192.168.30.20` | `:8123` direct | Not via Caddy initially. |

`127.0.0.1` inside the Caddy container points to Caddy itself. Use Docker service names on a shared Docker network. If proxying to the Docker host instead, use `192.168.30.10` intentionally and document why.

Each service should have a matching Uptime Kuma check plan before it is considered part of the baseline.

Current TLS notes:

- Live Caddyfile uses `auto_https disable_redirects`, not `auto_https off`.
- `tls internal` is enabled on `https://proxy.home.lan`, `https://kuma.home.lan`,
  `https://dozzle.home.lan`, and `https://dockge.home.lan`.
- Caddy local root CA fingerprint:
  `21:15:4C:3B:5E:AD:15:A5:14:EA:E4:BF:24:FB:CF:50:D3:F1:08:80:2B:DF:93:84:39:4F:63:4A:20:59:5D:34`.
- Mac mini trusts the CA via login Keychain. MBP has the CA file but still needs
  interactive trust authorization for system trust; `curl --cacert` validation passes.
