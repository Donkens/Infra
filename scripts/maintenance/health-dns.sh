#!/usr/bin/env bash
set -u
REPO="/home/pi/repos/infra"
LOG_DIR="$REPO/logs"
STATE_DIR="$REPO/state"
LOG_FILE="$LOG_DIR/dns-health.log"
FAIL_FILE="$LOG_DIR/dns-health-fail.log"
STATUS_FILE="$STATE_DIR/dns-health.last"
mkdir -p "$LOG_DIR" "$STATE_DIR"
ts="$(date '+%F %T')"
host="$(hostname -s)"
# Lock to avoid overlaps if timer runs while previous check hangs
LOCKFILE="/tmp/dns-health.lock"
exec 9>"$LOCKFILE"
if ! flock -n 9; then
  echo "[$ts] host=$host status=SKIP reason=lock_busy" >> "$LOG_FILE"
  exit 0
fi
# Helper
ok=1
reason=""
check_cmd() {
  command -v "$1" >/dev/null 2>&1
}
check_service() {
  local svc="$1"
  systemctl is-active --quiet "$svc"
}
dns_query() {
  local port="$1"
  local name="$2"
  timeout 6 dig @"127.0.0.1" -p "$port" "$name" A +short +time=2 +tries=1 2>/dev/null | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
}
adg_state="unknown"
unbound_state="unknown"
adg_q="NA"
unbound_q="NA"
if check_service AdGuardHome; then
  adg_state="active"
else
  adg_state="inactive"
  ok=0
  reason="${reason} AdGuardHome_inactive"
fi
if check_service unbound; then
  unbound_state="active"
else
  unbound_state="inactive"
  ok=0
  reason="${reason} unbound_inactive"
fi
if ! check_cmd dig; then
  ok=0
  reason="${reason} dig_missing"
else
  if dns_query 53 "openai.com"; then
    adg_q="OK"
  else
    adg_q="FAIL"
    ok=0
    reason="${reason} adguard_dns_timeout"
  fi
  if dns_query 5335 "google.com"; then
    unbound_q="OK"
  else
    unbound_q="FAIL"
    ok=0
    reason="${reason} unbound_dns_timeout"
  fi
fi
if [ "$ok" -eq 1 ]; then
  line="[$ts] host=$host status=OK adguard=$adg_state unbound=$unbound_state q53=$adg_q q5335=$unbound_q"
  echo "$line" | tee -a "$LOG_FILE" > "$STATUS_FILE"
  exit 0
else
  line="[$ts] host=$host status=FAIL adguard=$adg_state unbound=$unbound_state q53=$adg_q q5335=$unbound_q reason=${reason# }"
  echo "$line" | tee -a "$LOG_FILE" "$FAIL_FILE" > "$STATUS_FILE"
  exit 1
fi
