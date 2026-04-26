# Opti decision log

| Decision | Status | Reason |
| --- | --- | --- |
| Run HAOS as a VM instead of Home Assistant Container | Accepted | Keeps Supervisor/add-on model intact. |
| Use a Debian Docker VM for everything else | Accepted | Separates app services from hypervisor and HAOS. |
| Use WireGuard instead of Tailscale initially | Accepted | UDR-7 is already remote-access authority. |
| Use Stremio before Jellyfin | Accepted | Avoids local media library and Quick Sync work at bootstrap. |
| Delay Vaultwarden | Accepted | Requires backup destination, process, and restore-test first. |
| Treat `32 GB` RAM as target profile | Accepted | Allows bootstrap on lower RAM while deferring heavy workloads. |
