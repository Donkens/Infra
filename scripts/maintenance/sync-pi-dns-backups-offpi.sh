#!/usr/bin/env bash
# Purpose: Recurring off-Pi sync of Pi DNS backups to Mac encrypted sparsebundle.
# Author:  codex-agent | Date: 2026-04-29
set -euo pipefail

PI_HOST="${PI_HOST:-pi}"
PI_SOURCE="/home/pi/repos/infra/state/backups"
SPARSEBUNDLE="/Users/yasse/InfraBackups/pi-dns-backups.sparsebundle"
MOUNTPOINT="/Volumes/pi-dns-backups"
DEST="/Volumes/pi-dns-backups/pi/state-backups"
LOG_DIR="/Users/yasse/Library/Logs/pi-dns-backups"
LAST_STATUS="$LOG_DIR/offpi-sync.last"
NOTIFY_TOPIC_FILE="/Users/yasse/.config/pi-dns-backups/notify-topic"

VERIFY_ONLY=0
NO_ATTACH=0

usage() {
  cat <<'USAGE'
Usage: sync-pi-dns-backups-offpi.sh [--verify-only] [--no-attach]
  --verify-only  Do not copy from Pi; only validate destination latest/checksum.
  --no-attach    Do not attempt to attach sparsebundle if mount is missing.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --verify-only) VERIFY_ONLY=1 ;;
    --no-attach) NO_ATTACH=1 ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "$LOG_DIR"
chmod 700 "$LOG_DIR" || true
LOG_FILE="$LOG_DIR/offpi-sync.log"
ERR_FILE="$LOG_DIR/offpi-sync.err.log"
touch "$LOG_FILE" "$ERR_FILE"

exec 1>>"$LOG_FILE"
exec 2>>"$ERR_FILE"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(timestamp)] $*"; }

_notify_fail() {
  local reason="$1"
  local ts="$2"
  local host
  host="$(hostname -s 2>/dev/null || echo unknown)"
  local msg="off-pi backup FAIL — reason: ${reason} | host: ${host} | job: offpi-sync | ts: ${ts}"
  # Tier 1: macOS Notification Center. No secrets, no network.
  osascript << APPLESCRIPT >/dev/null 2>&1 || true
display notification "${msg}" with title "Pi Backup" subtitle "offpi-sync" sound name "Basso"
APPLESCRIPT
  # Tier 2: optional ntfy.sh topic. Topic file is local-only and never stored in repo.
  if [ -f "$NOTIFY_TOPIC_FILE" ] && [ -r "$NOTIFY_TOPIC_FILE" ]; then
    local topic
    topic="$(tr -d '[:space:]' < "$NOTIFY_TOPIC_FILE")"
    if [ -n "$topic" ]; then
      curl -s -o /dev/null --max-time 5 \
        -H "Title: Pi Backup FAIL" \
        -H "Priority: high" \
        -d "$msg" \
        "https://ntfy.sh/${topic}" 2>/dev/null || true
    fi
  fi
}

fail() {
  local reason="$1"
  local ts
  ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  log "FAIL: $reason"
  printf 'timestamp=%s\nresult=FAIL\nreason=%s\n' "$ts" "$reason" >"$LAST_STATUS"
  _notify_fail "$reason" "$ts"
  exit 1
}

ok_status() {
  local latest_name="$1"
  local copied_count="$2"
  printf 'timestamp=%s\nresult=PASS\nlatest=%s\ncopied_count=%s\nmode=%s\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    "$latest_name" \
    "$copied_count" \
    "$([ "$VERIFY_ONLY" -eq 1 ] && echo verify-only || echo sync)" >"$LAST_STATUS"
}

is_mounted() {
  mount | grep -F " on $MOUNTPOINT " >/dev/null 2>&1
}

if [ "$(id -u)" -eq 0 ]; then
  fail "must_not_run_as_root"
fi

if [ "$PI_SOURCE" != "/home/pi/repos/infra/state/backups" ]; then
  fail "source_allowlist_mismatch"
fi

if [ ! -d "$SPARSEBUNDLE" ]; then
  fail "sparsebundle_missing"
fi

if ! is_mounted; then
  if [ "$NO_ATTACH" -eq 1 ]; then
    fail "mount_unavailable_no_attach"
  fi
  log "INFO: mount missing; attempting attach"
  if ! hdiutil attach "$SPARSEBUNDLE" -mountpoint "$MOUNTPOINT" -nobrowse >/dev/null; then
    fail "mount_unavailable_attach_failed"
  fi
fi

if ! is_mounted; then
  fail "mount_unavailable"
fi

case "$DEST" in
  "$MOUNTPOINT"/*) ;;
  *) fail "destination_outside_mountpoint" ;;
esac

mkdir -p "$DEST"

if [ "$VERIFY_ONLY" -ne 1 ]; then
  log "INFO: validating Pi source and sudo mode"
  if ! ssh "$PI_HOST" "test -d '$PI_SOURCE'"; then
    fail "pi_source_missing"
  fi
  if ! ssh "$PI_HOST" "sudo -n /usr/local/sbin/export-pi-dns-backups --check"; then
    fail "pi_backup_export_wrapper_unavailable"
  fi

  log "INFO: starting tar stream copy from Pi to off-Pi destination"
  if ! ssh "$PI_HOST" "sudo -n /usr/local/sbin/export-pi-dns-backups" | (cd "$DEST" && tar -xpf -); then
    fail "copy_failed"
  fi
fi

latest_link="$DEST/latest"
latest_name=""

if [ -L "$latest_link" ]; then
  latest_ref="$(readlink "$latest_link" || true)"
  latest_name="$(basename "${latest_ref}")"
fi

if [ -z "$latest_name" ]; then
  latest_name="$(find "$DEST" -mindepth 1 -maxdepth 1 -type d -name 'dns-backup-*' -print | xargs -n1 basename 2>/dev/null | sort | tail -1)"
fi

[ -n "$latest_name" ] || fail "latest_backup_not_found"

backup_dir="$DEST/$latest_name"
[ -d "$backup_dir" ] || fail "latest_backup_dir_missing"

checksum_file="$backup_dir/meta/SHA256SUMS.txt"
if [ -f "$checksum_file" ]; then
  log "INFO: checksum verification start for $latest_name"
  if (cd "$backup_dir" && shasum -a 256 -c meta/SHA256SUMS.txt >/dev/null); then
    log "INFO: checksum PASS for $latest_name"
  else
    fail "checksum_failed"
  fi
else
  log "WARN: checksum file missing for $latest_name"
fi

copied_count="$(find "$DEST" -mindepth 1 -maxdepth 1 -type d -name 'dns-backup-*' | wc -l | tr -d ' ')"
ok_status "$latest_name" "$copied_count"
log "PASS: mode=$([ "$VERIFY_ONLY" -eq 1 ] && echo verify-only || echo sync) latest=$latest_name copied_count=$copied_count"
