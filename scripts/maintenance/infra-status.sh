#!/usr/bin/env bash
set -u
REPO="/home/pi/repos/infra"
LOG_DIR="$REPO/logs"
STATE_DIR="$REPO/state"
DNS_LAST="$STATE_DIR/dns-health.last"
BKP_LAST="$STATE_DIR/backup-health.last"
DNS_FAIL_LOG="$LOG_DIR/dns-health-fail.log"
BKP_FAIL_LOG="$LOG_DIR/backup-health-fail.log"
extract_kv() {
  # extract_kv "line" "key"
  local line="$1"
  local key="$2"
  echo "$line" | sed -n "s/.*[[:space:]]${key}=\([^[:space:]]*\).*/\1/p"
}
extract_ts() {
  # Timestamp in format [YYYY-MM-DD HH:MM:SS]
  local line="$1"
  echo "$line" | sed -n 's/^\[\([^]]*\)\].*/\1/p'
}
show_block() {
  local name="$1"
  local file="$2"
  if [ ! -f "$file" ]; then
    echo "$name: MISSING (ingen statusfil än)"
    return 1
  fi
  local line
  line="$(tail -n 1 "$file" 2>/dev/null || true)"
  if [ -z "$line" ]; then
    echo "$name: EMPTY"
    return 1
  fi
  local ts status host reason
  ts="$(extract_ts "$line")"
  status="$(extract_kv "$line" "status")"
  host="$(extract_kv "$line" "host")"
  reason="$(echo "$line" | sed -n 's/.* reason=\(.*\)$/\1/p')"
  echo "$name: ${status:-UNKNOWN}  host=${host:-?}  ts=${ts:-?}"
  if [ "$name" = "DNS" ]; then
    local adguard unbound q53 q5335
    adguard="$(extract_kv "$line" "adguard")"
    unbound="$(extract_kv "$line" "unbound")"
    q53="$(extract_kv "$line" "q53")"
    q5335="$(extract_kv "$line" "q5335")"
    echo "  adguard=${adguard:-?} unbound=${unbound:-?} q53=${q53:-?} q5335=${q5335:-?}"
  fi
  if [ "$name" = "BACKUP" ]; then
    local backups age_h max_age_h size manifest sha256
    backups="$(extract_kv "$line" "backups")"
    age_h="$(extract_kv "$line" "age_h")"
    max_age_h="$(extract_kv "$line" "max_age_h")"
    size="$(extract_kv "$line" "size")"
    manifest="$(extract_kv "$line" "manifest")"
    sha256="$(extract_kv "$line" "sha256")"
    echo "  backups=${backups:-?} age_h=${age_h:-?}/${max_age_h:-?} size=${size:-?} manifest=${manifest:-?} sha256=${sha256:-?}"
  fi
  if [ -n "${reason:-}" ]; then
    echo "  reason=$reason"
  fi
  return 0
}
echo "=== PI INFRA STATUS ==="
echo "Host: $(hostname -s)    Time: $(date '+%F %T')"
echo
# Timer status (best effort)
for t in dns-health.timer backup-health.timer; do
  if systemctl list-unit-files "$t" >/dev/null 2>&1; then
    active="$(systemctl is-active "$t" 2>/dev/null || true)"
    enabled="$(systemctl is-enabled "$t" 2>/dev/null || true)"
    echo "timer $t: active=${active:-unknown} enabled=${enabled:-unknown}"
  else
    echo "timer $t: not installed"
  fi
done
echo
show_block "DNS" "$DNS_LAST" || true
echo
show_block "BACKUP" "$BKP_LAST" || true
echo
echo "--- senaste FAIL (DNS) ---"
if [ -f "$DNS_FAIL_LOG" ]; then
  tail -n 3 "$DNS_FAIL_LOG" 2>/dev/null || true
else
  echo "ingen fail-logg"
fi
echo
echo "--- senaste FAIL (BACKUP) ---"
if [ -f "$BKP_FAIL_LOG" ]; then
  tail -n 3 "$BKP_FAIL_LOG" 2>/dev/null || true
else
  echo "ingen fail-logg"
fi
