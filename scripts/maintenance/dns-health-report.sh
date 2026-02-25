#!/usr/bin/env bash
set -u
# Pi DNS health check (AdGuard Home + Unbound) - low overhead / Pi3-safe
TS="$(date '+%Y-%m-%d %H:%M:%S %Z')"
HOST="$(hostname)"
LOG_WINDOW="${LOG_WINDOW:-120}"   # minuter bakåt för timeout-sökning
DIG_TIMEOUT="${DIG_TIMEOUT:-2}"
DIG_TRIES="${DIG_TRIES:-1}"
line() { printf '%*s\n' "${COLUMNS:-60}" '' | tr ' ' '-'; }
section() { echo; line; echo "## $1"; line; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }
echo "DNS HEALTH CHECK"
echo "Time: $TS"
echo "Host: $HOST"
section "System"
if have_cmd uptime; then
  echo "Uptime:"
  uptime
fi
echo
echo "Loadavg:"
cat /proc/loadavg 2>/dev/null || true
echo
echo "Memory:"
if have_cmd free; then
  free -h
else
  grep -E 'Mem(Total|Free|Available)' /proc/meminfo 2>/dev/null || true
fi
echo
echo "CPU temp:"
if have_cmd vcgencmd; then
  vcgencmd measure_temp || true
elif [ -r /sys/class/thermal/thermal_zone0/temp ]; then
  awk '{printf "temp=%.1f'\''C\n", $1/1000}' /sys/class/thermal/thermal_zone0/temp
else
  echo "N/A"
fi
section "Services"
for svc in AdGuardHome unbound; do
  state="$(systemctl is-active "$svc" 2>/dev/null || true)"
  enabled="$(systemctl is-enabled "$svc" 2>/dev/null || true)"
  printf "%-12s active=%s enabled=%s\n" "$svc" "${state:-unknown}" "${enabled:-unknown}"
done
section "Ports (53 / 80 / 3000 / 5335)"
if have_cmd ss; then
  ss -tulpn 2>/dev/null | egrep '(:53|:80|:3000|:5335)\b' || echo "No matching listeners found"
else
  echo "ss not installed"
fi
section "DNS Resolution Tests"
if have_cmd dig; then
  test_domain() {
    local server="$1" port="$2" domain="$3" label="$4"
    echo "[$label] $domain via $server:$port"
    local out rc
    out="$(dig @"$server" -p "$port" "$domain" +short +time="$DIG_TIMEOUT" +tries="$DIG_TRIES" 2>/dev/null)"
    rc=$?
    if [ $rc -ne 0 ] || [ -z "$out" ]; then
      echo "  FAIL/TIMEOUT"
      return 1
    else
      echo "$out" | sed 's/^/  /'
      return 0
    fi
  }
  fail_count=0
  test_domain 127.0.0.1 53   google.com       "AdGuard"  || fail_count=$((fail_count+1))
  test_domain 127.0.0.1 53   openai.com       "AdGuard"  || fail_count=$((fail_count+1))
  test_domain 127.0.0.1 5335 google.com       "Unbound"  || fail_count=$((fail_count+1))
  test_domain 127.0.0.1 5335 api.anthropic.com "Unbound" || fail_count=$((fail_count+1))
else
  echo "dig missing -> install with: sudo apt install -y dnsutils"
  fail_count=0
fi
section "Timeout Scan (last ${LOG_WINDOW}m)"
SINCE_STR="${LOG_WINDOW} min ago"
echo "[AdGuardHome] timeouts / i/o timeout / 5335"
journalctl -u AdGuardHome --since "$SINCE_STR" --no-pager 2>/dev/null \
  | egrep -i 'i/o timeout|timeout|127\.0\.0\.1:5335' \
  | tail -n 20 || true
echo
echo "[unbound] timeout / error / SERVFAIL"
journalctl -u unbound --since "$SINCE_STR" --no-pager 2>/dev/null \
  | egrep -i 'timeout|error|servfail|fail' \
  | tail -n 20 || true
section "Recent Logs (tail)"
echo "[AdGuardHome]"
journalctl -u AdGuardHome -n 15 --no-pager 2>/dev/null || true
echo
echo "[unbound]"
journalctl -u unbound -n 15 --no-pager 2>/dev/null || true
section "Summary"
ag_state="$(systemctl is-active AdGuardHome 2>/dev/null || echo unknown)"
ub_state="$(systemctl is-active unbound 2>/dev/null || echo unknown)"
echo "AdGuardHome: $ag_state"
echo "Unbound:     $ub_state"
if [ "${fail_count:-0}" -eq 0 ]; then
  echo "DNS tests:   OK"
else
  echo "DNS tests:   ${fail_count} failed"
fi
if [ "$ag_state" = "active" ] && [ "$ub_state" = "active" ] && [ "${fail_count:-0}" -eq 0 ]; then
  echo "Result:      HEALTHY ✅"
  exit 0
else
  echo "Result:      CHECK NEEDED ⚠️"
  exit 1
fi
