#!/usr/bin/env bash
# =============================================================================
#  debug-https-rr.sh — TYPE65/HTTPS auth truth + minimal Unbound workaround
#
#  Tests known authoritative nameservers directly (+norecurse) to determine
#  why HTTPS/TYPE65 queries fail for nih.gov and subdomains.
#
#  Read-only by default.
#  --apply : write recommended drop-in and restart Unbound.
# =============================================================================
set -euo pipefail

# ── Static config ─────────────────────────────────────────────────────────────
AUTH_IPS=( 128.231.128.251  128.231.64.1  165.112.4.230 )
DOMAINS=(  nih.gov  nlm.nih.gov  ncbi.nlm.nih.gov  pubmed.ncbi.nlm.nih.gov )
DROPIN="/etc/unbound/unbound.conf.d/31-nih-workaround.conf"
TIMEOUT=3
TRIES=1
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

# ── Colors ────────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
    cOK='\033[32m' cWA='\033[33m' cFA='\033[31m'
    cDI='\033[2m'  cBO='\033[1m'  cNC='\033[0m'
else
    cOK='' cWA='' cFA='' cDI='' cBO='' cNC=''
fi

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

LOG="$WORKDIR/run.log"
exec > >(tee -a "$LOG") 2>&1

# ── Helpers ───────────────────────────────────────────────────────────────────
sfmt() {
    local s="$1" w="${2:-11}"
    local p; p=$(printf "%-${w}s" "$s")
    case "$s" in
        NOERROR|NODATA)                  printf "${cOK}%s${cNC}" "$p" ;;
        SERVFAIL|NOTIMP|REFUSED|FORMERR) printf "${cFA}%s${cNC}" "$p" ;;
        TIMEOUT)                         printf "${cWA}%s${cNC}" "$p" ;;
        *)                               printf "${cDI}%s${cNC}" "$p" ;;
    esac
}

is_ok()  { [ "$1" = "NOERROR" ] || [ "$1" = "NODATA" ]; }
is_bad() { ! is_ok "$1"; }
hdr()    { printf "${cBO}%s${cNC}\n" "$*"; }
sep()    { printf '─%.0s' $(seq 1 76); printf '\n'; }
pass()   { printf "${cOK}[PASS]${cNC} %s\n" "$*"; }
fail()   { printf "${cFA}[FAIL]${cNC} %s\n" "$*"; }
warn()   { printf "${cWA}[WARN]${cNC} %s\n" "$*"; }
note()   { printf "  %s\n" "$*"; }

# dig_query ADDR PORT DOMAIN TYPE PROTO(udp|tcp) RECURSE(yes|no)
# stdout: STATUS<TAB>QTIMEms
dig_query() {
    local addr="$1" port="$2" domain="$3" type="$4"
    local proto="${5:-udp}" recurse="${6:-yes}"

    local args=( "@${addr}" -p "${port}" "${domain}" "${type}"
                 +tries="${TRIES}" +time="${TIMEOUT}" )
    [ "$proto"   = "tcp" ] && args+=( +tcp )
    [ "$recurse" = "no"  ] && args+=( +norecurse )

    local out=""
    out=$(dig "${args[@]}" 2>/dev/null) || true

    local status=""
    status=$(printf '%s\n' "$out" | awk '
        /;; ->>HEADER<<-/ {
            for (i=1; i<=NF; i++) if ($i == "status:") {
                v=$(i+1); gsub(",","",v); print v; exit
            }
        }')

    local ancount=0
    ancount=$(printf '%s\n' "$out" | awk '
        /;; flags:/ {
            for (i=1; i<=NF; i++) if ($i == "ANSWER:") {
                v=$(i+1); gsub(",","",v); print v+0; exit
            }
        }')

    local qtime="-"
    qtime=$(printf '%s\n' "$out" | awk '/Query time:/ { print $4"ms" }')

    if   [ -z "$status" ]; then
        status="TIMEOUT"; qtime="-"
    elif [ "$status" = "NOERROR" ] && [ "${ancount:-0}" -eq 0 ]; then
        status="NODATA"
    fi

    printf '%s\t%s' "$status" "${qtime:--}"
}

f1() { printf '%s' "$1" | cut -f1; }
f2() { printf '%s' "$1" | cut -f2; }

# ══════════════════════════════════════════════════════════════════════════════
# Header
# ══════════════════════════════════════════════════════════════════════════════
echo ""
hdr "════════════════════════════════════════════════════════════════════════════"
hdr "  TYPE65/HTTPS Auth Truth Test — nih.gov family"
printf "  UTC : %s\n" "$(date -u)"
printf "  Host: %s   Unbound: 127.0.0.1:5335\n" "$(hostname)"
hdr "════════════════════════════════════════════════════════════════════════════"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 1 — Authoritative truth test
# ══════════════════════════════════════════════════════════════════════════════
hdr "PHASE 1 — Authoritative truth test (+norecurse)"
note "Auth NS: ${AUTH_IPS[*]}"
echo ""

# Column header
COL_W=9   # status cell width
TIME_W=7  # time cell width

printf "%-32s %-6s" "Domain / type" "  "
for ip in "${AUTH_IPS[@]}"; do
    printf "%-$((COL_W + TIME_W + 2))s" "$ip"
done
printf '\n'

printf "%-32s %-6s" "" ""
for _ in "${AUTH_IPS[@]}"; do
    printf "%-${COL_W}s %-${TIME_W}s  " "status" "time"
done
printf '\n'; sep

# Counters per type
declare -A https_nodata   # domain → count of NODATA from auth
declare -A https_bad      # domain → count of SERVFAIL/TIMEOUT from auth
declare -A https_noerror  # domain → count of NOERROR+answer from auth

for domain in "${DOMAINS[@]}"; do
    https_nodata[$domain]=0
    https_bad[$domain]=0
    https_noerror[$domain]=0

    for type in A HTTPS; do
        printf "%-32s %-6s" "$domain / $type" ""
        for i in "${!AUTH_IPS[@]}"; do
            ip="${AUTH_IPS[$i]}"
            r=$(dig_query "$ip" 53 "$domain" "$type" udp no)
            s=$(f1 "$r"); t=$(f2 "$r")

            sfmt "$s" $COL_W
            printf " ${cDI}%-${TIME_W}s${cNC}  " "$t"

            # Store for classification
            printf '%s' "$s" > "${WORKDIR}/r_${domain}_${i}_${type}"

            # Accumulate HTTPS counters
            if [ "$type" = "HTTPS" ]; then
                case "$s" in
                    NODATA)              https_nodata[$domain]=$((${https_nodata[$domain]}+1))  ;;
                    NOERROR)             https_noerror[$domain]=$((${https_noerror[$domain]}+1)) ;;
                    *)                   https_bad[$domain]=$((${https_bad[$domain]}+1))         ;;
                esac
            fi
        done
        printf '\n'
    done
    sep
done
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 2 — Classification
# ══════════════════════════════════════════════════════════════════════════════
hdr "PHASE 2 — Classification"
echo ""

# Aggregate across all domains
total_nodata=0; total_bad=0; total_noerror=0; total_ns=${#AUTH_IPS[@]}

for domain in "${DOMAINS[@]}"; do
    total_nodata=$((total_nodata   + ${https_nodata[$domain]}))
    total_bad=$((total_bad         + ${https_bad[$domain]}))
    total_noerror=$((total_noerror + ${https_noerror[$domain]}))
done

total_tests=$(( ${#DOMAINS[@]} * total_ns ))

printf "  HTTPS result totals across %d tests (%d domains × %d auth NS):\n" \
    "$total_tests" "${#DOMAINS[@]}" "$total_ns"
note "  NODATA   : $total_nodata"
note "  SERVFAIL/TIMEOUT: $total_bad"
note "  NOERROR+answer  : $total_noerror"
echo ""

# Classification
CASE="UNKNOWN"

if   [ "$total_noerror" -gt 0 ]; then
    CASE="C"   # Auth serves valid HTTPS RRs
elif [ "$total_nodata"  -gt 0 ] && [ "$total_bad" -eq 0 ]; then
    CASE="A"   # All auth → NODATA, zone has no HTTPS records
elif [ "$total_bad"     -gt 0 ] && [ "$total_nodata" -eq 0 ]; then
    CASE="B"   # Auth broken for TYPE65
elif [ "$total_bad"     -gt 0 ] && [ "$total_nodata" -gt 0 ]; then
    CASE="D"   # Mixed behavior across NS
fi

case "$CASE" in
    A) printf "  ${cOK}CASE A${cNC} — Auth returns NODATA for HTTPS.\n"
       note "Zone simply does not publish TYPE65 records."
       note "Auth NS correctly denies HTTPS — no records exist."
       ;;
    B) printf "  ${cFA}CASE B${cNC} — Auth TIMEOUT/SERVFAIL for HTTPS.\n"
       note "Auth NS is broken for TYPE65 handling."
       note "This is a server-side defect at nih.gov's NS infrastructure."
       ;;
    C) printf "  ${cWA}CASE C${cNC} — Auth serves valid HTTPS records.\n"
       note "Records exist — problem is in the resolver path (Unbound/EDNS/DNSSEC)."
       ;;
    D) printf "  ${cWA}CASE D${cNC} — INCONSISTENT AUTH — mixed NODATA + SERVFAIL across NS.\n"
       note "Different nameservers disagree. Likely partial/broken delegation."
       ;;
    *) warn "Could not classify — all results empty (network issue?)"
       ;;
esac
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 3 — Minimal workaround decision
# ══════════════════════════════════════════════════════════════════════════════
hdr "PHASE 3 — Minimal workaround"
echo ""

WA_TYPE="none"
WA_CONTENT=""
WA_REASON=""
WA_SAFE=""
WA_BLAST=""

case "$CASE" in
    A)
        WA_TYPE="typetransparent"
        WA_CONTENT='server:
    # nih.gov does not publish HTTPS (TYPE65) records.
    # typetransparent: Unbound answers from local-data when present;
    # all other record types recurse normally. No DNSSEC changes.
    local-zone: "nih.gov." typetransparent'
        WA_REASON="Auth returns clean NODATA. Unbound may SERVFAIL if DNSSEC NODATA
             proof (NSEC3) validation fails. typetransparent short-circuits
             the local zone so Unbound passes NODATA through without
             re-validating — fail-fast, no masking."
        WA_SAFE="DNSSEC fully preserved for all other zones and record types.
         Only TYPE65 handling for nih.gov. changes (NODATA passthrough)."
        WA_BLAST="nih.gov. zone only. Zero impact on other zones or query types."
        ;;
    B)
        WA_TYPE="domain-insecure"
        WA_CONTENT='server:
    # nih.gov auth NS is broken for TYPE65 — returns SERVFAIL/TIMEOUT.
    # domain-insecure disables DNSSEC validation for this zone only,
    # allowing Unbound to accept whatever the broken auth returns.
    # Use only if typetransparent is insufficient.
    domain-insecure: "nih.gov."'
        WA_REASON="Auth is broken for HTTPS — DNSSEC validation fails on a bad
             SERVFAIL/TIMEOUT response. domain-insecure prevents Unbound
             from treating auth errors as BOGUS. Strictly scoped to nih.gov."
        WA_SAFE="Weakens DNSSEC for nih.gov. zone only. All other zones
         retain full DNSSEC. Use with caution."
        WA_BLAST="nih.gov. zone only — DNSSEC disabled for all record types."
        ;;
    C)
        WA_TYPE="none"
        printf "  ${cWA}Resolver path issue — DO NOT change Unbound config.${cNC}\n"
        note "Auth serves valid HTTPS records. Investigate:"
        note "  • EDNS buffer size (try: edns-buffer-size: 1232)"
        note "  • TCP fallback    (try: tcp-upstream: yes)"
        note "  • DNSSEC path     (check: unbound-control dump_cache | grep nih.gov)"
        echo ""
        ;;
    D)
        WA_TYPE="typetransparent"
        WA_CONTENT='server:
    # nih.gov auth NS is inconsistent for TYPE65 (mixed NODATA/SERVFAIL).
    # typetransparent provides fail-fast behavior without DNSSEC weakening.
    local-zone: "nih.gov." typetransparent'
        WA_REASON="Inconsistent auth — some NS return NODATA, others SERVFAIL.
             typetransparent is the safest option: fails fast, preserves
             DNSSEC, does not mask errors for other record types."
        WA_SAFE="DNSSEC fully preserved. Fail-fast approach — no masking."
        WA_BLAST="nih.gov. zone only."
        ;;
esac

if [ "$WA_TYPE" != "none" ]; then
    printf "  Recommended fix: ${cBO}%s${cNC}\n\n" "$WA_TYPE"
    printf "  ${cBO}File:${cNC} %s\n" "$DROPIN"
    printf "  ┌──────────────────────────────────────────────────────────────┐\n"
    while IFS= read -r line; do
        printf "  │ %-62s│\n" "$line"
    done <<< "$WA_CONTENT"
    printf "  └──────────────────────────────────────────────────────────────┘\n"
    echo ""
    [ "$APPLY" -eq 0 ] && note "Run with --apply to write this drop-in."
fi
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 4 — Apply (only if --apply)
# ══════════════════════════════════════════════════════════════════════════════
if [ "$APPLY" -eq 1 ] && [ "$WA_TYPE" != "none" ]; then
    hdr "PHASE 4 — Apply"
    echo ""

    # Backup existing drop-in if present
    if [ -f "$DROPIN" ]; then
        BAK="${DROPIN}.bak.$(date -u +%Y%m%d_%H%M%S)"
        sudo cp "$DROPIN" "$BAK"
        pass "Backed up existing drop-in → $BAK"
    fi

    # Atomic write
    tmp=$(mktemp)
    printf '%s\n' "$WA_CONTENT" > "$tmp"
    sudo install -m 0644 "$tmp" "$DROPIN"
    rm -f "$tmp"
    pass "Written: $DROPIN"
    echo ""
    cat "$DROPIN"
    echo ""

    # Validate
    if sudo unbound-checkconf 2>&1; then
        pass "unbound-checkconf OK"
    else
        fail "unbound-checkconf failed — reverting"
        sudo rm -f "$DROPIN"
        exit 1
    fi

    # Restart
    sudo systemctl restart unbound && sleep 2
    state=$(systemctl is-active unbound 2>/dev/null || echo unknown)
    if [ "$state" = "active" ]; then
        pass "unbound restarted — active"
    else
        fail "unbound not active after restart — reverting"
        sudo rm -f "$DROPIN"
        sudo systemctl restart unbound
        exit 1
    fi

    # Post-apply re-test
    echo ""
    hdr "── Post-apply verification (Unbound 127.0.0.1:5335) ─────────────────────"
    sep
    printf "%-40s %-12s %-10s\n" "Query" "Status" "Time"
    sep
    for domain in "${DOMAINS[@]}"; do
        for type in A HTTPS; do
            r=$(dig_query 127.0.0.1 5335 "$domain" "$type" udp yes)
            s=$(f1 "$r"); t=$(f2 "$r")
            printf "%-40s " "$domain $type"
            sfmt "$s" 12
            printf " %s\n" "$t"
        done
    done
    sep
    echo ""

elif [ "$APPLY" -eq 1 ] && [ "$WA_TYPE" = "none" ]; then
    hdr "PHASE 4 — Apply"
    echo ""
    warn "Nothing to apply for CASE $CASE — see PHASE 3 for guidance."
    echo ""
fi

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 5 — Safety report
# ══════════════════════════════════════════════════════════════════════════════
hdr "PHASE 5 — Safety report"
sep
printf "  %-18s %s\n" "Root cause:"  "CASE $CASE — $(case $CASE in A) echo 'nih.gov publishes no HTTPS records (auth returns NODATA)';;
    B) echo 'Auth NS broken for TYPE65 (SERVFAIL/TIMEOUT)' ;;
    C) echo 'Records exist — resolver path problem' ;;
    D) echo 'Inconsistent auth behavior across nameservers' ;;
    *) echo 'Unknown' ;; esac)"
printf "  %-18s %s\n" "Chosen fix:"  "${WA_TYPE:-none (see PHASE 3)}"
if [ -n "$WA_REASON" ]; then
    printf "  %-18s %s\n" "Why safe:"    "$WA_SAFE"
    printf "  %-18s %s\n" "Blast radius:" "$WA_BLAST"
fi
printf "  %-18s %s\n" "DNSSEC intact:" \
    "$([ "$WA_TYPE" = "domain-insecure" ] && echo "NO — nih.gov. zone only" || echo "YES — unchanged globally")"
printf "  %-18s %s\n" "Applied:" \
    "$([ "$APPLY" -eq 1 ] && [ "$WA_TYPE" != "none" ] && echo "YES — $DROPIN" || echo "NO — read-only mode")"
sep
echo ""
hdr "════════════════════════════════════════════════════════════════════════════"
printf "  Done — %s\n" "$(date -u)"
[ "$APPLY" -eq 0 ] && [ "$WA_TYPE" != "none" ] \
    && printf "  Re-run with --apply to write the recommended drop-in.\n"
hdr "════════════════════════════════════════════════════════════════════════════"
echo ""
