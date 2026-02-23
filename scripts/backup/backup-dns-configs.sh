#!/usr/bin/env bash
set -euo pipefail
# backup-dns-configs.sh
# Backup AdGuardHome + Unbound configs (Pi3-safe, low overhead)
#
# Default:
#   - Config-only backup -> state/backups/dns-backup-YYYYmmdd_HHMMSS/
#
# Options:
#   --with-data     Include AdGuardHome work/data dir tar.gz (can be bigger)
#   --export-repo   Export sanitized config snapshots into repo config/
#   --help          Show help
WITH_DATA=0
EXPORT_REPO=0
for arg in "$@"; do
  case "$arg" in
    --with-data)   WITH_DATA=1 ;;
    --export-repo) EXPORT_REPO=1 ;;
    --help|-h)
      cat <<'USAGE'
Usage: backup-dns-configs.sh [--with-data] [--export-repo]
  --with-data     Include AdGuardHome work/data dir in backup tar.gz
  --export-repo   Export sanitized snapshots to repo config/
USAGE
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 2
      ;;
  esac
done
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TS="$(date '+%Y%m%d_%H%M%S')"
HOST="$(hostname)"
BACKUP_ROOT="$REPO_ROOT/state/backups"
DEST="$BACKUP_ROOT/dns-backup-$TS"
mkdir -p "$DEST"/{adguard,unbound,meta}
mkdir -p "$BACKUP_ROOT"
log() { echo "[$(date '+%H:%M:%S')] $*"; }
warn() { echo "[$(date '+%H:%M:%S')] WARN: $*" >&2; }
# Detect AdGuardHome config + work dir
AG_CONFIG=""
for p in \
  /home/pi/AdGuardHome/AdGuardHome.yaml \
  /opt/AdGuardHome/AdGuardHome.yaml \
  /etc/AdGuardHome.yaml \
  /usr/local/etc/AdGuardHome.yaml
do
  if [ -f "$p" ]; then AG_CONFIG="$p"; break; fi
done
AG_WORK_DIR=""
for p in \
  /home/pi/AdGuardHome/work \
  /opt/AdGuardHome/work \
  /var/lib/AdGuardHome \
  /usr/local/var/AdGuardHome
do
  if [ -d "$p" ]; then AG_WORK_DIR="$p"; break; fi
done
# Unbound paths (Debian/RPi OS typical)
UNBOUND_ETC="/etc/unbound"
UNBOUND_MAIN="/etc/unbound/unbound.conf"
UNBOUND_D_DIR="/etc/unbound/unbound.conf.d"
log "Creating backup at: $DEST"
# Metadata
{
  echo "timestamp=$TS"
  echo "hostname=$HOST"
  echo "repo_root=$REPO_ROOT"
  echo "with_data=$WITH_DATA"
  echo "export_repo=$EXPORT_REPO"
  echo "adguard_config=${AG_CONFIG:-not_found}"
  echo "adguard_work_dir=${AG_WORK_DIR:-not_found}"
  echo "unbound_main=$UNBOUND_MAIN"
  echo "unbound_conf_d=$UNBOUND_D_DIR"
  echo
  echo "[service_status]"
  systemctl is-active AdGuardHome 2>/dev/null || true
  systemctl is-active unbound 2>/dev/null || true
  echo
  echo "[service_enabled]"
  systemctl is-enabled AdGuardHome 2>/dev/null || true
  systemctl is-enabled unbound 2>/dev/null || true
} > "$DEST/meta/manifest.txt"
# AdGuard config
if [ -n "$AG_CONFIG" ] && [ -f "$AG_CONFIG" ]; then
  cp -a "$AG_CONFIG" "$DEST/adguard/AdGuardHome.yaml"
  log "Backed up AdGuard config: $AG_CONFIG"
else
  warn "AdGuard config not found"
fi
# Optional AdGuard data/work dir (can be larger)
if [ "$WITH_DATA" -eq 1 ]; then
  if [ -n "$AG_WORK_DIR" ] && [ -d "$AG_WORK_DIR" ]; then
    tar -czf "$DEST/adguard/adguard_work.tar.gz" -C "$AG_WORK_DIR" .
    log "Backed up AdGuard work dir (tar.gz): $AG_WORK_DIR"
  else
    warn "AdGuard work dir not found; skipping --with-data"
  fi
fi
# Unbound configs
if [ -d "$UNBOUND_ETC" ]; then
  mkdir -p "$DEST/unbound/etc-unbound"
  if [ -f "$UNBOUND_MAIN" ]; then
    cp -a "$UNBOUND_MAIN" "$DEST/unbound/etc-unbound/"
    log "Backed up Unbound main config"
  else
    warn "Unbound main config not found at $UNBOUND_MAIN"
  fi
  if [ -d "$UNBOUND_D_DIR" ]; then
    mkdir -p "$DEST/unbound/etc-unbound/unbound.conf.d"
    cp -a "$UNBOUND_D_DIR"/. "$DEST/unbound/etc-unbound/unbound.conf.d/" 2>/dev/null || true
    log "Backed up Unbound conf.d"
  fi
  # Useful extra files if present
  for f in root.key; do
    [ -f "$UNBOUND_ETC/$f" ] && cp -a "$UNBOUND_ETC/$f" "$DEST/unbound/etc-unbound/" || true
  done
else
  warn "Unbound etc dir not found at $UNBOUND_ETC"
fi
# Checksums (helps verify restore later)
if command -v sha256sum >/dev/null 2>&1; then
  (
    cd "$DEST"
    find . -type f ! -name 'SHA256SUMS.txt' -print0 | sort -z | xargs -0 sha256sum
  ) > "$DEST/meta/SHA256SUMS.txt" || true
elif command -v shasum >/dev/null 2>&1; then
  (
    cd "$DEST"
    find . -type f ! -name 'SHA256SUMS.txt' -print0 | sort -z | xargs -0 shasum -a 256
  ) > "$DEST/meta/SHA256SUMS.txt" || true
fi
# Optional sanitized export into repo config/ (safe to git)
if [ "$EXPORT_REPO" -eq 1 ]; then
  mkdir -p "$REPO_ROOT/config/adguardhome" "$REPO_ROOT/config/unbound/unbound.conf.d"
  if [ -n "$AG_CONFIG" ] && [ -f "$AG_CONFIG" ]; then
    # Basic redaction (keeps structure useful for repo)
    sed -E \
      -e 's/^([[:space:]]*password:).*/\1 REDACTED/' \
      -e 's/^([[:space:]]*password_hash:).*/\1 REDACTED/' \
      -e 's/^([[:space:]]*private_key:).*/\1 REDACTED/' \
      -e 's/^([[:space:]]*certificate_chain:).*/\1 REDACTED/' \
      "$AG_CONFIG" > "$REPO_ROOT/config/adguardhome/AdGuardHome.yaml.sanitized"
    {
      echo "# Exported from $AG_CONFIG"
      echo "# Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"
      echo "# NOTE: sanitized for git safety"
    } > "$REPO_ROOT/config/adguardhome/README.md"
    log "Exported sanitized AdGuard config to repo config/adguardhome/"
  fi
  if [ -f "$UNBOUND_MAIN" ]; then
    cp -a "$UNBOUND_MAIN" "$REPO_ROOT/config/unbound/unbound.conf"
  fi
  if [ -d "$UNBOUND_D_DIR" ]; then
    find "$UNBOUND_D_DIR" -maxdepth 1 -type f -name '*.conf' -exec cp -a {} "$REPO_ROOT/config/unbound/unbound.conf.d/" \;
  fi
  log "Exported Unbound config snapshots to repo config/unbound/"
fi
# Final summary
SIZE_HUMAN="$(du -sh "$DEST" | awk '{print $1}')"
echo
echo "Backup complete ✅"
echo "Location: $DEST"
echo "Size:     $SIZE_HUMAN"
echo "Modes:    with_data=$WITH_DATA export_repo=$EXPORT_REPO"
# Optional latest symlink for convenience
ln -sfn "$DEST" "$BACKUP_ROOT/latest"
log "Updated symlink: $BACKUP_ROOT/latest"
