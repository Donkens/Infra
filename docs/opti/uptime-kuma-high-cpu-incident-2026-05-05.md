# Incidentnotis — Uptime Kuma hög CPU (Opti/Docker VM 102) 2026-05-05
## Summary
Opti fick förhöjd fläktnivå och temperatur. Lasten drevs av `uptime-kuma` i Docker VM `102`, där CPU låg runt `190-200%`.
Orsaken var inte `node server/server.js`, utan en hängd extern processkedja kopplad till `kuma-cleanup.js`.
## Symptoms
- Opti host-load cirka `~3`.
- `x86_pkg_temp` cirka `~70 C`.
- `fan1_input` cirka `~2300-2700 RPM`.
- `uptime-kuma` cirka `~190-200% CPU`.
## Evidence
- Suspicious host-side processkedja:
  - `docker exec ... uptime-kuma ... kuma-cleanup.js`
  - `sh -c ... base64 -d > /tmp/kuma-cleanup.js`
  - `base64 -d`
- Suspicious container-side processer:
  - orphan `cat`-processer med `>50%` CPU (två processer nära `~100%` vardera).
- Ingen relevant logstorm i `docker logs`.
- Kuma datafiler var små och normala (`kuma.db`, `kuma.db-wal`, `kuma.db-shm`).
## Root cause
En hängd extern script-injektion via `docker exec`/`base64` lämnade kvar processkedja och orphan `cat` i containern.
Det skapade artificiell CPU-belastning i `uptime-kuma` trots att app-processen (`node server/server.js`) i sig inte var CPU-toppen.
## Fix performed
Minimal blast radius:
- Verifierade exakta target-PID och args.
- Skickade `TERM` först.
- Skickade selektiv `KILL` endast på kvarvarande verifierade suspicious targets.
- Ingen restart/stop av Docker VM, `uptime-kuma`, HAOS eller Proxmox host.
## Verification
- Suspicious host-side processer: borta.
- Container-side `cat` med hög CPU: borta.
- `uptime-kuma` CPU: `~200%` → `0.44%`.
- Opti `x86_pkg_temp`: `~70 C` → `50 C`.
- Opti `fan1_input`: `~2300-2700 RPM` → `1813 RPM`.
- Host/VM load började falla tydligt.
## Prevention / guardrails
- Undvik `docker exec -i ... cat > file` utan kontrollerad EOF/timeout.
- Undvik `echo/base64 | docker exec ... > file` för temporära scriptflöden.
- Föredra att skriva script till repo/volume och köra scriptet explicit.
- Använd `timeout` runt temporära `docker exec`-kommandon.
- Efter agentkörningar: verifiera att inga rester finns av `docker exec`, `base64 -d`, `cat`, `kuma-cleanup.js`.
## Scope note
Denna notis dokumenterar endast repo-händelse och åtgärdsmönster. Ingen live-konfiguration lagras här.
