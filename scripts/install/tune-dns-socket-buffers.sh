#!/usr/bin/env bash
# =============================================================================
#  tune-dns-socket-buffers.sh
#  Adds so-rcvbuf/so-sndbuf drop-in for Unbound and produces a timestamped
#  audit log with before/after measurements.
#
#  IDEMPOTENT — safe to run multiple times.
# =============================================================================
set -euo pipefail

# =============================================================================
# PHASE 0 — SETUP LOGGING
# =============================================================================
mkdir -p "$HOME/logs"
TS=$(date -u +%Y%m%d_%H%M%S)
LOG="$HOME/logs/dns_tuning_${TS}.txt"
LATEST="$HOME/logs/dns_tuning_latest.txt"
DROPIN="/etc/unbound/unbound.conf.d/20-socket-buffers.conf"

exec > >(tee -a "$LOG") 2>&1

echo "LOG: $LOG"
echo "============================================================="
echo "  DNS Socket Buffer Tuning"
echo "  UTC: $(date -u)"
echo "  Host: $(hostname)"
echo "  Kernel: $(uname -r)"
echo "  Uptime: $(uptime)"
echo "============================================================="
echo ""

# =============================================================================
# HELPERS
# =============================================================================
run() {
    echo "  \$ $*"
    "$@" 2>&1 || true
    echo ""
}

pass() { echo "[PASS] $*"; }
warn() { echo "[WARN] $*"; }
fail() { echo "[FAIL] $*"; }

# Measure latency: 10 runs, return space-separated ms values
measure_latency() {
    local host="$1" qtype="$2"
    local times=()
    for _ in $(seq 1 10); do
        local t
        t=$(dig @127.0.0.1 -p 5335 "$host" "$qtype" +tries=1 +time=2 2>/dev/null \
            | awk '/Query time:/ {print $4}')
        times+=("${t:-999}")
    done
    echo "${times[*]}"
}

# Compute avg and p95 from space-separated integers (portable: no asort)
stats_from() {
    local _tf
    _tf=$(mktemp)
    echo "$1" | tr ' ' '\n' > "$_tf"
    local _avg
    _avg=$(awk '{s+=$1} END{ if(NR) printf "%.1f", s/NR; else print "0" }' "$_tf")
    local _p95
    _p95=$(sort -n "$_tf" | awk '
        {a[NR]=$1}
        END{
            if(!NR){print "0"; exit}
            i=int((NR*95+99)/100)
            if(i<1) i=1
            if(i>NR) i=NR
            print a[i]
        }')
    rm -f "$_tf"
    printf "avg=%s p95=%d" "$_avg" "$_p95"
}

# Snapshot UDP error counters — prints "InErrors RcvbufErrors" pair
udp_counters() {
    if command -v netstat &>/dev/null; then
        netstat -su 2>/dev/null | awk '
            /packet receive errors/ { rcv=$1 }
            /receive buffer errors/  { buf=$1 }
            END { printf "%s %s", (rcv?rcv:"0"), (buf?buf:"0") }
        '
    else
        # /proc/net/snmp: Udp: InErrors is field 4 (0-indexed after header)
        paste <(awk '/^Udp:/{p++; if(p==2){print $4}}' /proc/net/snmp) \
              <(awk '/^UdpLite:/{p++; if(p==2){print $5}}' /proc/net/snmp 2>/dev/null || echo 0) \
        2>/dev/null || echo "0 0"
    fi
}

# =============================================================================
# PHASE 1 — BASELINE (READ ONLY)
# =============================================================================
echo "============================================================="
echo "PHASE 1 — BASELINE"
echo "============================================================="
echo ""

echo "--- A) Services + ports ---"
for svc in unbound AdGuardHome; do
    state=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
    if [ "$state" = "active" ]; then
        pass "$svc is $state"
    else
        warn "$svc is $state"
    fi
done
echo ""
run ss -tulpn

echo "--- B) Existing buffer settings ---"
EXISTING=$(grep -R -nE '^\s*(so-rcvbuf|so-sndbuf)\s*:' \
    /etc/unbound/unbound.conf \
    /etc/unbound/unbound.conf.d 2>/dev/null || true)
if [ -n "$EXISTING" ]; then
    warn "Buffer settings already present:"
    echo "$EXISTING"
    DECISION="NO_CHANGE"
else
    pass "No existing so-rcvbuf/so-sndbuf found"
    DECISION="WILL_APPLY"
fi
echo ""

echo "--- C) Latency baseline (10 runs each) ---"
declare -A BEFORE_TIMES
TARGETS=("google.com:A" "cloudflare.com:A" "pubmed.ncbi.nlm.nih.gov:HTTPS")
for t in "${TARGETS[@]}"; do
    host="${t%%:*}"; qtype="${t##*:}"
    echo "  Measuring $host $qtype..."
    BEFORE_TIMES["$t"]=$(measure_latency "$host" "$qtype")
    stats=$(stats_from "${BEFORE_TIMES[$t]}")
    echo "  BEFORE $host $qtype: $stats  (raw: ${BEFORE_TIMES[$t]})"
done
echo ""

echo "--- D) UDP/kernel counters baseline ---"
BEFORE_UDP=$(udp_counters)
echo "  UDP error counters (InErrors RcvbufErrors): $BEFORE_UDP"
echo ""
run ip -s link show

echo "--- E) Log baseline (last 120 min) ---"
echo "  -- unbound errors --"
journalctl -u unbound --since "120 min ago" --no-pager 2>/dev/null \
    | grep -iE "timeout|servfail|error|reset|Capsforid" | tail -20 || true
echo ""
echo "  -- AdGuardHome 5335 errors --"
journalctl -u AdGuardHome --since "120 min ago" --no-pager 2>/dev/null \
    | grep -iE "5335|timeout|i/o timeout" | tail -20 || true
echo ""

# =============================================================================
# PHASE 2 — PLAN
# =============================================================================
echo "============================================================="
echo "PHASE 2 — PLAN: $DECISION"
echo "============================================================="
echo ""

if [ "$DECISION" = "NO_CHANGE" ]; then
    warn "Buffer settings already configured — skipping apply, measuring current state only."
fi

# =============================================================================
# PHASE 3 — EXECUTE (ONLY IF WILL_APPLY)
# =============================================================================
if [ "$DECISION" = "WILL_APPLY" ]; then
    echo "============================================================="
    echo "PHASE 3 — EXECUTE"
    echo "============================================================="
    echo ""

    echo "--- 1) Creating drop-in atomically ---"
    tmp=$(mktemp)
    cat > "$tmp" <<'EOF'
server:
    so-rcvbuf: 4m
    so-sndbuf: 4m
EOF
    sudo install -m 0644 "$tmp" "$DROPIN"
    rm -f "$tmp"
    pass "Drop-in written: $DROPIN"
    cat "$DROPIN"
    echo ""

    echo "--- 2) Validating config ---"
    if sudo unbound-checkconf 2>&1; then
        pass "unbound-checkconf OK"
    else
        fail "unbound-checkconf failed — reverting"
        sudo rm -f "$DROPIN"
        fail "Drop-in removed. Unbound NOT restarted."
        echo "LOG SAVED: $LOG"
        exit 1
    fi
    echo ""

    echo "--- 3) Restarting Unbound ---"
    run sudo systemctl restart unbound
    sleep 2

    echo "--- 4) Health checks ---"
    state=$(systemctl is-active unbound 2>/dev/null || echo "unknown")
    if [ "$state" = "active" ]; then
        pass "unbound is active"
    else
        fail "unbound is $state after restart"
        sudo rm -f "$DROPIN"
        fail "Drop-in removed as precaution."
        echo "LOG SAVED: $LOG"
        exit 1
    fi

    dig_out=$(dig @127.0.0.1 -p 5335 google.com A +tries=1 +time=2 2>&1 || true)
    if echo "$dig_out" | grep -q "NOERROR"; then
        pass "dig google.com A → NOERROR"
    else
        warn "dig google.com A did not return NOERROR"
        echo "$dig_out"
    fi
    echo ""

    echo "  -- Recent unbound log --"
    journalctl -u unbound -n 40 --no-pager 2>/dev/null || true
    echo ""
fi

# =============================================================================
# PHASE 4 — AFTER (MEASURE AGAIN)
# =============================================================================
echo "============================================================="
echo "PHASE 4 — AFTER"
echo "============================================================="
echo ""

echo "--- Services + ports ---"
for svc in unbound AdGuardHome; do
    state=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
    if [ "$state" = "active" ]; then pass "$svc is $state"; else warn "$svc is $state"; fi
done
echo ""

echo "--- Latency after (10 runs each) ---"
declare -A AFTER_TIMES
for t in "${TARGETS[@]}"; do
    host="${t%%:*}"; qtype="${t##*:}"
    echo "  Measuring $host $qtype..."
    AFTER_TIMES["$t"]=$(measure_latency "$host" "$qtype")
    stats=$(stats_from "${AFTER_TIMES[$t]}")
    echo "  AFTER $host $qtype: $stats  (raw: ${AFTER_TIMES[$t]})"
done
echo ""

echo "--- UDP/kernel counters after ---"
AFTER_UDP=$(udp_counters)
echo "  UDP error counters (InErrors RcvbufErrors): $AFTER_UDP"
echo ""

echo "--- Logs last 30 min ---"
echo "  -- unbound --"
journalctl -u unbound --since "30 min ago" --no-pager 2>/dev/null \
    | grep -iE "timeout|servfail|error|reset|Capsforid" | tail -20 || true
echo ""
echo "  -- AdGuardHome --"
journalctl -u AdGuardHome --since "30 min ago" --no-pager 2>/dev/null \
    | grep -iE "5335|timeout|i/o timeout" | tail -20 || true
echo ""

# =============================================================================
# PHASE 5 — REPORT + SUMMARY
# =============================================================================
echo "============================================================="
echo "PHASE 5 — REPORT"
echo "============================================================="
echo ""

# Build comparison table and compute verdict
VERDICT_SCORE=0
TOTAL_TARGETS=0

printf "%-38s %12s %12s %12s %12s\n" "Target" "BEF avg" "BEF p95" "AFT avg" "AFT p95"
printf "%-38s %12s %12s %12s %12s\n" \
    "--------------------------------------" "--------" "--------" "--------" "--------"

for t in "${TARGETS[@]}"; do
    host="${t%%:*}"; qtype="${t##*:}"
    b_stats=$(stats_from "${BEFORE_TIMES[$t]}")
    a_stats=$(stats_from "${AFTER_TIMES[$t]}")
    b_avg=$(echo "$b_stats" | grep -oP 'avg=\K[0-9.]+')
    b_p95=$(echo "$b_stats" | grep -oP 'p95=\K[0-9]+')
    a_avg=$(echo "$a_stats" | grep -oP 'avg=\K[0-9.]+')
    a_p95=$(echo "$a_stats" | grep -oP 'p95=\K[0-9]+')
    printf "%-38s %11s %11s %11s %11s\n" \
        "$host $qtype" "${b_avg}ms" "${b_p95}ms" "${a_avg}ms" "${a_p95}ms"
    # Score: -1 if worse (>10% higher avg), +1 if better, 0 if same
    cmp=$(awk -v b="$b_avg" -v a="$a_avg" 'BEGIN {
        if (b==0) { print "same" }
        else if (a > b*1.10) { print "worse" }
        else if (a < b*0.90) { print "better" }
        else { print "same" }
    }')
    if [ "$cmp" = "better" ]; then VERDICT_SCORE=$((VERDICT_SCORE+1)); fi
    if [ "$cmp" = "worse"  ]; then VERDICT_SCORE=$((VERDICT_SCORE-1)); fi
    TOTAL_TARGETS=$((TOTAL_TARGETS+1))
done
echo ""

echo "--- UDP counter delta ---"
b_in=$(echo "$BEFORE_UDP" | awk '{print $1}')
b_buf=$(echo "$BEFORE_UDP" | awk '{print $2}')
a_in=$(echo "$AFTER_UDP"  | awk '{print $1}')
a_buf=$(echo "$AFTER_UDP" | awk '{print $2}')
delta_in=$((${a_in:-0} - ${b_in:-0}))
delta_buf=$((${a_buf:-0} - ${b_buf:-0}))
printf "  %-24s before=%-8s after=%-8s delta=%s\n" "UDP InErrors"       "$b_in"  "$a_in"  "$delta_in"
printf "  %-24s before=%-8s after=%-8s delta=%s\n" "UDP RcvbufErrors"   "$b_buf" "$a_buf" "$delta_buf"
echo ""

echo "--- Change applied ---"
if [ "$DECISION" = "WILL_APPLY" ]; then
    pass "Drop-in created: $DROPIN"
    cat "$DROPIN"
else
    warn "No change applied (already configured)"
fi
echo ""

echo "--- Verdict ---"
if [ "$VERDICT_SCORE" -gt 0 ]; then
    VERDICT="IMPROVED"
    pass "VERDICT: $VERDICT (latency better on $VERDICT_SCORE/$TOTAL_TARGETS targets)"
elif [ "$VERDICT_SCORE" -lt 0 ]; then
    VERDICT="WORSE"
    fail "VERDICT: $VERDICT (latency worse on some targets — investigate)"
else
    VERDICT="NO CHANGE"
    pass "VERDICT: $VERDICT (latency within ±10% on all targets)"
fi
echo ""

# Short summary file
cat > "$LATEST" <<SUMMARY
DNS Socket Buffer Tuning — $(date -u)
Host: $(hostname)
Change applied: $DECISION

BEFORE vs AFTER latency:
$(printf "%-38s %12s %12s %12s %12s\n" "Target" "BEF avg" "BEF p95" "AFT avg" "AFT p95")
$(for t in "${TARGETS[@]}"; do
    host="${t%%:*}"; qtype="${t##*:}"
    b_stats=$(stats_from "${BEFORE_TIMES[$t]}")
    a_stats=$(stats_from "${AFTER_TIMES[$t]}")
    b_avg=$(echo "$b_stats" | grep -oP 'avg=\K[0-9.]+')
    b_p95=$(echo "$b_stats" | grep -oP 'p95=\K[0-9]+')
    a_avg=$(echo "$a_stats" | grep -oP 'avg=\K[0-9.]+')
    a_p95=$(echo "$a_stats" | grep -oP 'p95=\K[0-9]+')
    printf "%-38s %11s %11s %11s %11s\n" "$host $qtype" "${b_avg}ms" "${b_p95}ms" "${a_avg}ms" "${a_p95}ms"
done)

UDP RcvbufErrors delta: $delta_buf
Verdict: $VERDICT
Full log: $LOG
SUMMARY

echo "LOG SAVED: $LOG"
echo "SUMMARY:   $LATEST"
echo ""
echo "============================================================="
echo "  Done — $(date -u)"
echo "============================================================="
