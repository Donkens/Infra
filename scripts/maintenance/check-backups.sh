#!/usr/bin/env bash
set -u
REPO="/home/pi/repos/infra"
LOG_DIR="$REPO/logs"
STATE_DIR="$REPO/state"
BACKUP_ROOT="$STATE_DIR/backups"
LATEST_LINK="$BACKUP_ROOT/latest"
LOG_FILE="$LOG_DIR/backup-health.log"
FAIL_FILE="$LOG_DIR/backup-health-fail.log"
STATUS_FILE="$STATE_DIR/backup-health.last"
MAX_AGE_HOURS="${MAX_AGE_HOURS:-48}"
mkdir -p "$LOG_DIR" "$STATE_DIR"
ts="$(date '+%F %T')"
host="$(hostname -s)"
# Prevent overlap
LOCKFILE="/tmp/backup-health.lock"
exec 9>"$LOCKFILE"
if ! flock -n 9; then
  echo "[$ts] host=$host status=SKIP reason=lock_busy" >> "$LOG_FILE"
  exit 0
fi
ok=1
reason=""
if [ ! -L "$LATEST_LINK" ] && [ ! -d "$LATEST_LINK" ]; then
  ok=0
  reason="${reason} latest_missing"
  latest_path=""
else
  latest_path="$(readlink -f "$LATEST_LINK" 2>/dev/null || true)"
  if [ -z "${latest_path:-}" ] || [ ! -d "$latest_path" ]; then
    ok=0
    reason="${reason} latest_invalid"
  fi
fi
backup_count=0
[ -d "$BACKUP_ROOT" ] && backup_count="$(find "$BACKUP_ROOT" -maxdepth 1 -type d -name 'dns-backup-*' | wc -l)"
age_hours="NA"
size_h="NA"
manifest="missing"
sha256="missing"
if [ -n "${latest_path:-}" ] && [ -d "$latest_path" ]; then
  # Age based on directory mtime
  now_epoch="$(date +%s)"
  mtime_epoch="$(stat -c %Y "$latest_path" 2>/dev/null || echo 0)"
  if [ "$mtime_epoch" -gt 0 ]; then
    age_sec=$((now_epoch - mtime_epoch))
    age_hours=$((age_sec / 3600))
    if [ "$age_hours" -gt "$MAX_AGE_HOURS" ]; then
      ok=0
      reason="${reason} backup_too_old(${age_hours}h>${MAX_AGE_HOURS}h)"
    fi
  else
    ok=0
    reason="${reason} mtime_unreadable"
  fi
  size_h="$(du -sh "$latest_path" 2>/dev/null | awk '{print $1}' || echo NA)"
  [ -f "$latest_path/meta/manifest.txt" ] && manifest="ok" || {
    ok=0
    reason="${reason} manifest_missing"
  }
  [ -f "$latest_path/meta/SHA256SUMS.txt" ] && sha256="ok" || {
    ok=0
    reason="${reason} sha256_missing"
  }
fi
line="[$ts] host=$host status=$( [ "$ok" -eq 1 ] && echo OK || echo FAIL ) backups=$backup_count age_h=$age_hours max_age_h=$MAX_AGE_HOURS size=$size_h manifest=$manifest sha256=$sha256 latest=${latest_path:-NA} reason=${reason# }"
if [ "$ok" -eq 1 ]; then
  echo "$line" | tee -a "$LOG_FILE" > "$STATUS_FILE"
  exit 0
else
  echo "$line" | tee -a "$LOG_FILE" "$FAIL_FILE" > "$STATUS_FILE"
  exit 1
fi
