# Docker VM conventions

Docker services belong on VM `102`, not on the Proxmox host.

| Path | Use |
| --- | --- |
| `/srv/compose` | Compose project files and examples. |
| `/srv/appdata` | Persistent app data, configs, and small databases. |

Rules:

- Use `env.example` only in repo.
- Do not commit real `.env` files.
- Add `restart:` policy to every service.
- Add Docker `logging` limits to every service.
- Avoid `latest` tags unless the exception is documented.
- Avoid host networking unless documented.
- Avoid privileged mode unless explicitly required.
- Avoid `0.0.0.0` binds without approval.
- Back up compose/env material before Docker stack changes.
