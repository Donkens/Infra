#!/usr/bin/env bash
# Purpose: Dry-run-first retention for Pi DNS backup directories.
# Author:  codex-agent | Date: 2026-04-26
set -euo pipefail

readonly DEFAULT_BACKUP_DIR="/home/pi/repos/infra/state/backups"
readonly DEFAULT_DAYS=45
readonly DEFAULT_MIN_KEEP=10

log() { echo "[$(basename "$0")] $*" >&2; }
die() { log "ERROR: $*"; exit 1; }

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--backup-dir PATH] [--days N] [--min-keep N] [--dry-run|--apply]

Prune Pi DNS backup directories under state/backups.

Defaults:
  --backup-dir $DEFAULT_BACKUP_DIR
  --days       $DEFAULT_DAYS
  --min-keep   $DEFAULT_MIN_KEEP
  --dry-run

Safety:
  - Only direct child directories named dns-backup-* are considered.
  - The latest symlink and its target are preserved.
  - At least the newest --min-keep backup directories are preserved.
  - Deletion only happens with explicit --apply.
USAGE
}

backup_dir="$DEFAULT_BACKUP_DIR"
days="$DEFAULT_DAYS"
min_keep="$DEFAULT_MIN_KEEP"
mode="dry-run"

is_uint() {
  case "${1:-}" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --backup-dir)
      [ "$#" -ge 2 ] || die "--backup-dir requires PATH"
      backup_dir="$2"
      shift 2
      ;;
    --days)
      [ "$#" -ge 2 ] || die "--days requires N"
      days="$2"
      shift 2
      ;;
    --min-keep)
      [ "$#" -ge 2 ] || die "--min-keep requires N"
      min_keep="$2"
      shift 2
      ;;
    --dry-run)
      mode="dry-run"
      shift
      ;;
    --apply)
      mode="apply"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

is_uint "$days" || die "--days must be a non-negative integer"
is_uint "$min_keep" || die "--min-keep must be a non-negative integer"

case "$backup_dir" in
  */state/backups|state/backups) ;;
  *) die "--backup-dir must be named state/backups" ;;
esac

[ -d "$backup_dir" ] || die "backup dir is not a directory: $backup_dir"

backup_abs="$(cd "$backup_dir" && pwd -P)"
case "$backup_abs" in
  */state/backups) ;;
  *) die "resolved backup dir must end with state/backups: $backup_abs" ;;
esac

timestamp_to_epoch() {
  local base="$1" ts date_part time_part stamp
  ts="${base#dns-backup-}"
  case "$ts" in
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9]) ;;
    *) return 1 ;;
  esac

  date_part="${ts%_*}"
  time_part="${ts#*_}"
  stamp="${date_part}${time_part}"

  if date -u -d "${date_part:0:4}-${date_part:4:2}-${date_part:6:2} ${time_part:0:2}:${time_part:2:2}:${time_part:4:2}" +%s >/dev/null 2>&1; then
    date -u -d "${date_part:0:4}-${date_part:4:2}-${date_part:6:2} ${time_part:0:2}:${time_part:2:2}:${time_part:4:2}" +%s
  else
    date -u -j -f "%Y%m%d%H%M%S" "$stamp" +%s 2>/dev/null
  fi
}

is_direct_backup_child() {
  local path="$1" parent base
  [ -d "$path" ] || return 1
  parent="$(cd "$(dirname "$path")" && pwd -P)"
  [ "$parent" = "$backup_abs" ] || return 1
  base="$(basename "$path")"
  case "$base" in
    dns-backup-*) return 0 ;;
    *) return 1 ;;
  esac
}

latest_target=""
if [ -L "$backup_abs/latest" ]; then
  latest_raw="$(readlink "$backup_abs/latest" || true)"
  if [ -n "$latest_raw" ]; then
    case "$latest_raw" in
      /*) latest_path="$latest_raw" ;;
      *) latest_path="$backup_abs/$latest_raw" ;;
    esac
    if [ -d "$latest_path" ]; then
      latest_target="$(cd "$latest_path" && pwd -P)"
      is_direct_backup_child "$latest_target" || latest_target=""
    fi
  fi
fi

now_epoch="$(date -u +%s)"
declare -a backups=()
while IFS= read -r dir; do
  backups+=("$dir")
done < <(find "$backup_abs" -maxdepth 1 -type d -name "dns-backup-*" -print | sort -r)

declare -a preserved=()
declare -a candidates=()

idx=0
for dir in "${backups[@]}"; do
  idx=$((idx + 1))
  if [ "$idx" -le "$min_keep" ]; then
    preserved+=("$dir")
  fi
done

for dir in "${backups[@]}"; do
  base="$(basename "$dir")"
  preserve=0

  [ -n "$latest_target" ] && [ "$(cd "$dir" && pwd -P)" = "$latest_target" ] && preserve=1
  for keep in "${preserved[@]}"; do
    [ "$dir" = "$keep" ] && preserve=1 && break
  done
  [ "$preserve" -eq 1 ] && continue

  if epoch="$(timestamp_to_epoch "$base")"; then
    age_days="$(( (now_epoch - epoch) / 86400 ))"
    [ "$age_days" -gt "$days" ] && candidates+=("$dir")
  else
    log "Skipping unparseable backup timestamp: $dir"
  fi
done

echo "backup_dir=$backup_abs"
echo "mode=$mode"
echo "retention_days=$days"
echo "min_keep=$min_keep"
echo "total_backups=${#backups[@]}"
echo "candidates=${#candidates[@]}"
echo "preserved_latest_target=${latest_target:-none}"

if [ "${#candidates[@]}" -eq 0 ]; then
  echo "No backup directories would be removed."
  exit 0
fi

for dir in "${candidates[@]}"; do
  is_direct_backup_child "$dir" || die "candidate failed safety validation: $dir"
  case "$mode" in
    dry-run)
      echo "DRY-RUN would remove: $dir"
      ;;
    apply)
      rm -rf -- "$dir"
      echo "REMOVED: $dir"
      ;;
    *)
      die "invalid mode: $mode"
      ;;
  esac
done
