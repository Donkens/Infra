# Termix

> Status: container, Caddy route, and DNS rewrite live as of 2026-05-06.

## Runtime

| Item | Value |
|---|---|
| Host | Docker VM 102, `docker.home.lan` / `192.168.30.10` |
| Compose path | `/srv/compose/termix` |
| Appdata path | `/srv/appdata/termix` |
| Image | `ghcr.io/lukegus/termix:release-2.1.0` |
| Container | `termix` |
| Docker network | external `proxy` |
| Internal port | `8080` |
| Public route | `http://termix.home.lan`, `https://termix.home.lan` via Caddy |
| DNS | `termix.home.lan -> 192.168.30.10` live via AdGuard rewrite |

## Compose

Termix runs without published host ports. Caddy reaches it by Docker service name
on the shared `proxy` network.

```yaml
networks:
  proxy:
    external: true

services:
  termix:
    image: ghcr.io/lukegus/termix:release-2.1.0
    container_name: termix
    restart: unless-stopped
    networks:
      - proxy
    volumes:
      - /srv/appdata/termix:/app/data
    environment:
      PORT: "8080"
      NODE_ENV: production
      DATA_DIR: /app/data
      LOG_LEVEL: info
      SSL_ENABLED: "false"
      ENABLE_GUACAMOLE: "false"
      DB_FILE_ENCRYPTION: "true"
      PUID: "1000"
      PGID: "1000"
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

## Caddy

```caddyfile
http://termix.home.lan {
  reverse_proxy termix:8080
}

https://termix.home.lan {
  tls internal
  reverse_proxy termix:8080
}
```

Caddyfile backup before route add:
`/srv/compose/caddy/Caddyfile.pre-termix-20260506-195021.bak`.

`caddy validate --config /etc/caddy/Caddyfile` passed. `caddy reload` cannot be
used while the live Caddyfile has `admin off`; Caddy was restarted after
validation.

## Security guardrails

- Do not use `latest`; keep a pinned Termix release tag.
- Do not mount `/var/run/docker.sock`.
- Do not expose Termix directly on a host port.
- Keep access LAN/Tailscale-only; no WAN port forwards.
- Use app authentication immediately and enable 2FA/TOTP if available.
- Do not upload Mac mini or MBP private SSH keys.
- Do not generate or deploy SSH keys until a separate key rollout phase.
- Use a dedicated future SSH identity: `id_ed25519_termix`.
- Do not add UDR root access in the first rollout.
- Do not add HAOS in the first rollout.
- No SSH targets are onboarded yet.
- Pi target access depends on the minimal UniFi rule `allow-termix-to-pi-ssh`
  (`69fbb2601bc6e72d27779357`): Docker VM `192.168.30.10` to Pi
  `192.168.1.55` TCP `22` only.

## Backup and restore

Back up both:

```text
/srv/compose/termix/compose.yaml
/srv/appdata/termix/
```

Treat `/srv/appdata/termix` as sensitive. Termix stores generated secrets and
database material under the data directory, including `.env` values generated on
first start. Never commit this runtime data or print it in logs.

Restore validation should confirm:

- Termix container starts healthy.
- App login works.
- Existing host inventory and credentials are present.
- No unauthorized SSH targets were added.

## Validation

2026-05-06:

- `docker compose config` passed for `/srv/compose/termix/compose.yaml`.
- `termix` container started healthy with image `ghcr.io/lukegus/termix:release-2.1.0`.
- In-container HTTP check to `127.0.0.1:8080` returned `200 OK`.
- Caddy route returned `200 OK` for HTTP and HTTPS using explicit resolve to `192.168.30.10`.
- Safe helper check confirmed exact rewrite `termix.home.lan -> 192.168.30.10`.
- `dig @127.0.0.1 termix.home.lan A +short` returned `192.168.30.10`.
- `dig @192.168.1.55 termix.home.lan A +short` returned `192.168.30.10`.
- Uptime Kuma monitor `Termix HTTPS` added as ID `17`; `GET`
  `https://termix.home.lan`, `200-299`, `auth_method=mtls`,
  `tls_ca=<CA_PRESENT>`, `ignore_tls=0`, latest status `200 - OK`.
- UniFi rule `allow-termix-to-pi-ssh` added for the Pi target path:
  `192.168.30.10` → `192.168.1.55` TCP `22`, `ip_version: IPV4`,
  `create_allow_respond: true`. Validation from Docker VM returned
  `ssh22_exit=0`; Pi DNS TCP/UDP `53` still worked; Pi TCP `80`, Opti TCP `22`,
  and Opti TCP `8006` still timed out.

## Next steps

1. Open Termix UI and create/admin-harden the app account.
2. Plan a separate `id_ed25519_termix` SSH key rollout.
