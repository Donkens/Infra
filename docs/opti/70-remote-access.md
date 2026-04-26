# Remote access plan

## Primary access

WireGuard on UDR-7 is the primary remote-access path.

Do not add Tailscale initially. Tailscale may be documented later as an optional fallback or secondary access method.

## Planned WireGuard reachability

WireGuard clients should eventually access:

- `192.168.1.0/24`
- `192.168.30.0/24`

## Planned access paths

| Target | Address | Purpose |
| --- | --- | --- |
| Proxmox | `192.168.1.60:8006` | Web UI |
| Proxmox | `192.168.1.60:22` | SSH if needed |
| Docker VM | `192.168.30.10:22` | SSH |
| Docker VM | `192.168.30.10:80/443` | Caddy services |
| HAOS | `192.168.30.20:8123` | Home Assistant |
| Pi DNS | `192.168.1.55:53` | DNS |

No WAN port forwards are part of the initial plan.
