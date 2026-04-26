# Media policy

## Baseline

Stremio Server is the baseline media-related service. Run it only if the low-RAM host has enough headroom.

## Deferred

Jellyfin is skipped initially. Add Jellyfin only later if a real local media library is built.

Quick Sync passthrough is skipped initially. Revisit it only when Jellyfin/local media requires hardware transcoding.

## Storage

The Opti NVMe is for:

- Proxmox
- VM disks
- Docker appdata
- Home Assistant
- configs
- small databases

The Opti NVMe is not for:

- large media
- large downloads
- backups
- long-lived snapshots
