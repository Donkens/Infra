#!/usr/bin/env bash
# =============================================================================
#  debug-https-rr.sh — TYPE65/HTTPS RR diagnostic — nih.gov family
#
#  Distinguishes between:
#    • Auth NS dropping/ignoring TYPE65
#    • UDP fragmentation (TCP works, UDP fails)
#    • Unbound DNSSEC policy (Unbound fails, public resolvers work)
#
#  Read-only by default.
#  --apply : write recommended drop-in to /etc/unbound/unbound.conf.d/
# =============================================================================
set -euo pipefail

DOMAINS=( nih.gov nlm.nih.gov ncbi.nlm.nih.gov pubmed.ncbi.nlm.nih.gov )
AUTH_ZONE="nih.gov"

R_LABEL=( UNBOUND   "1.1.1.1"  "9.9.9.9"  "8.8.8.8" )
R_ADDR=(  127.0.0.1  1.1.1.1    9.9.9.9    8.8.8.8  )
R_PORT=(  5335        53          53          53      )

TIMEOUT=4
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

# ── Helpers ───────────────────────────────────────────────────────────────────
sfmt() {
    # Pad first, then colorize — preserves column alignment with ANSI codes
    local s="$1" w="${2:-12}"
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
sep()    { printf '─%.0s' $(seq 1 72); printf '\n'; }
pass()   { printf "${cOK}[PASS]${cNC} %s\n" "$*"; }
fail()   { printf "${cFA}[FAIL]${cNC} %s\n" "$*"; }
warn()   { printf "${cWA}[WARN]${cNC} %s\n" "$*"; }

# ── dig_query ─────────────────────────────────────────────────────────────────
# Usage : dig_query ADDR PORT DOMAIN TYPE PROTO(udp|tcp) RECURSE(yes|no)
# Output: STATUS<TAB>QTIMEms<TAB>EDE-string
dig_query() {
    local addr="$1" port="$2" domain="$3" type="$4"
    local proto="${5:-udp}" recurse="${6:-yes}"

    local args=( "@${addr}" -p "${port}" "${domain}" "${type}"
                 +tries="${TRIES}" +time="${TIMEOUT}" )
    [ "$proto"   = "tcp" ] && args+=( +tcp )
    [ "$recurse" = "no"  ] && args+=( +norecurse )

    local out=""
    out=$(dig "${args[@]}" 2>/dev/null) || true

    # Status from HEADER line: ";; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: N"
    local status=""
    status=$(printf '%s\n' "$out" | awk '
        /;; ->>HEADER<<-/ {
            for (i=1; i<=NF; i++) if ($i == "status:") {
                v = $(i+1); gsub(",","",v); print v; exit
            }
        }')

    # Answer count from flags line: ";; flags: qr rd ra; QUERY: 1, ANSWER: 0, ..."
    local ancount=0
    ancount=$(printf '%s\n' "$out" | awk '
        /;; flags:/ {
            for (i=1; i<=NF; i++) if ($i == "ANSWER:") {
                v = $(i+1); gsub(",","",v); print v+0; exit
            }
        }')

    local qtime="-"
    qtime=$(printf '%s\n' "$out" | awk '/Query time:/ { print $4"ms" }')

    # EDE (RFC 8914) — e.g. "EDE: 22 (No Reachable Authority)"
    local ede=""
    ede=$(printf '%s\n' "$out" | grep -oE 'EDE: [0-9]+[^;)]*' | head -1 || true)

    if   [ -z "$status" ]; then
        status="TIMEOUT"; qtime="-"
    elif [ "$status" = "NOERROR" ] && [ "${ancount:-0}" -eq 0 ]; then
        status="NODATA"
    fi

    printf '%s\t%s\t%s' "$status" "${qtime:--}" "${ede:-}"
}

f1() { printf '%s' "$1" | cut -f1; }   # status
f2() { printf '%s' "$1" | cut -f2; }   # qtime
f3() { printf '%s' "$1" | cut -f3; }   # ede

# ── Verdict counters ──────────────────────────────────────────────────────────
unb_ok=0;  unb_fail=0
pub_ok=0;  pub_fail=0
tcp_ok=0;  tcp_fail=0
auth_ok=0; auth_fail=0
tcp_saves=0      # domains where TCP worked but UDP failed
ede_notes=""     # collected EDE strings

# ═════════════════════════════════════════════════════════════════════════════
# Header
# ═════════════════════════════════════════════════════════════════════════════
echo ""
hdr "══════════════════════════════════════════════════════════════════════════"
hdr "  TYPE65/HTTPS RR Diagnostic — nih.gov family"
printf "  UTC : %s\n" "$(date -u)"
printf "  Host: %s   Kernel: %s\n" "$(hostname)" "$(uname -r)"
hdr "══════════════════════════════════════════════════════════════════════════"
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 1 — HTTPS (TYPE65) • UDP
# ═════════════════════════════════════════════════════════════════════════════
hdr "SECTION 1 — HTTPS (TYPE65) • UDP"
sep
printf "%-32s" "Domain"
for lbl in "${R_LABEL[@]}"; do printf "%-14s" "$lbl"; done
printf '\n'; sep

for domain in "${DOMAINS[@]}"; do
    printf "%-32s" "$domain"
    for i in "${!R_ADDR[@]}"; do
        r=$(dig_query "${R_ADDR[$i]}" "${R_PORT[$i]}" "$domain" HTTPS udp yes)
        s=$(f1 "$r")
        sfmt "$s" 14
        printf '%s' "$s" > "${WORKDIR}/udp_${domain}_${i}"
        if is_ok "$s"; then
            [ "$i" -eq 0 ] && unb_ok=$((unb_ok+1))   || pub_ok=$((pub_ok+1))
        else
            [ "$i" -eq 0 ] && unb_fail=$((unb_fail+1)) || pub_fail=$((pub_fail+1))
        fi
    done
    printf '\n'
done
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 2 — HTTPS (TYPE65) • TCP  [fragmentation check]
# ═════════════════════════════════════════════════════════════════════════════
hdr "SECTION 2 — HTTPS (TYPE65) • TCP   [UDP fragmentation check]"
sep
printf "%-32s" "Domain"
for lbl in "${R_LABEL[@]}"; do printf "%-14s" "$lbl"; done
printf '\n'; sep

for domain in "${DOMAINS[@]}"; do
    printf "%-32s" "$domain"
    tcp_row_saves=0
    for i in "${!R_ADDR[@]}"; do
        r=$(dig_query "${R_ADDR[$i]}" "${R_PORT[$i]}" "$domain" HTTPS tcp yes)
        s=$(f1 "$r"); e=$(f3 "$r")
        sfmt "$s" 14
        printf '%s' "$s" > "${WORKDIR}/tcp_${domain}_${i}"
        is_ok "$s" && tcp_ok=$((tcp_ok+1)) || tcp_fail=$((tcp_fail+1))
        # Collect EDE codes for verdict section
        if [ -n "$e" ]; then
            ede_notes="${ede_notes}  ${domain}@${R_LABEL[$i]} (TCP): ${e}\n"
        fi
        # Check if TCP saved a domain that UDP failed
        udp_s=""
        [ -f "${WORKDIR}/udp_${domain}_${i}" ] \
            && udp_s=$(cat "${WORKDIR}/udp_${domain}_${i}")
        if is_bad "${udp_s:-TIMEOUT}" && is_ok "$s"; then
            tcp_row_saves=$((tcp_row_saves+1))
        fi
    done
    [ "$tcp_row_saves" -gt 0 ] && tcp_saves=$((tcp_saves+1))
    printf '\n'
done
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 3 — A record • UDP baseline
# ═════════════════════════════════════════════════════════════════════════════
hdr "SECTION 3 — A record • UDP baseline"
sep
printf "%-32s" "Domain"
for lbl in "${R_LABEL[@]}"; do printf "%-14s" "$lbl"; done
printf "%-10s\n" "Unb time"; sep

for domain in "${DOMAINS[@]}"; do
    printf "%-32s" "$domain"
    for i in "${!R_ADDR[@]}"; do
        r=$(dig_query "${R_ADDR[$i]}" "${R_PORT[$i]}" "$domain" A udp yes)
        s=$(f1 "$r"); t=$(f2 "$r")
        sfmt "$s" 14
        [ "$i" -eq 0 ] && printf "%-10s" "$t"
    done
    printf '\n'
done
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 4 — Direct auth NS  [+norecurse]
# ═════════════════════════════════════════════════════════════════════════════
hdr "SECTION 4 — Direct auth NS • +norecurse  [zone: ${AUTH_ZONE}]"
sep

NS_LIST=$(dig "${AUTH_ZONE}" NS +short 2>/dev/null | grep -v '^$' | head -4 || true)

if [ -z "$NS_LIST" ]; then
    warn "Could not resolve NS for ${AUTH_ZONE}"
else
    printf "%-26s %-17s %-14s %-14s %-14s\n" \
           "NS" "IP" "HTTPS/UDP" "HTTPS/TCP" "A/UDP"
    sep
    while IFS= read -r ns; do
        ns_ip=$(dig "${ns}" A +short 2>/dev/null \
                | grep -E '^[0-9]' | head -1 || true)
        if [ -z "$ns_ip" ]; then
            printf "%-26s %-17s —\n" "${ns%%.}" "(unresolvable)"; continue
        fi
        r_hu=$(dig_query "$ns_ip" 53 "$AUTH_ZONE" HTTPS udp no)
        r_ht=$(dig_query "$ns_ip" 53 "$AUTH_ZONE" HTTPS tcp no)
        r_au=$(dig_query "$ns_ip" 53 "$AUTH_ZONE" A     udp no)
        s_hu=$(f1 "$r_hu"); s_ht=$(f1 "$r_ht"); s_au=$(f1 "$r_au")
        e_hu=$(f3 "$r_hu"); e_ht=$(f3 "$r_ht")

        printf "%-26s %-17s " "${ns%%.}" "$ns_ip"
        sfmt "$s_hu" 14; sfmt "$s_ht" 14; sfmt "$s_au" 14
        printf '\n'

        # Collect EDE from auth NS
        [ -n "$e_hu" ] && ede_notes="${ede_notes}  ${ns%%.} (HTTPS/UDP): ${e_hu}\n"
        [ -n "$e_ht" ] && ede_notes="${ede_notes}  ${ns%%.} (HTTPS/TCP): ${e_ht}\n"

        is_ok "$s_hu" && auth_ok=$((auth_ok+1)) || auth_fail=$((auth_fail+1))
    done <<< "$NS_LIST"
fi
echo ""

# ─── EDE notes ───────────────────────────────────────────────────────────────
if [ -n "$ede_notes" ]; then
    hdr "EDE (Extended DNS Error) codes observed:"
    printf '%b' "$ede_notes"
    echo ""
fi

# ═════════════════════════════════════════════════════════════════════════════
# VERDICT
# ═════════════════════════════════════════════════════════════════════════════
hdr "══════════════════════════════════════════════════════════════════════════"
hdr "  VERDICT"
hdr "══════════════════════════════════════════════════════════════════════════"
echo ""

# ── Pattern analysis ──────────────────────────────────────────────────────────
auth_drops=0; frag_issue=0; unbound_issue=0; all_fail=0

[ "$auth_fail"  -gt 0 ] && [ "$auth_ok"   -eq 0 ] && auth_drops=1
[ "$tcp_saves"  -gt 0 ]                            && frag_issue=1
[ "$unb_fail"   -gt 0 ] && [ "$pub_ok"    -gt 0 ] && unbound_issue=1
[ "$unb_fail"   -gt 0 ] && [ "$pub_fail"  -gt 0 ] \
    && [ "$tcp_fail"  -gt 0 ] && [ "$auth_fail" -gt 0 ] && all_fail=1

mark() {
    local active="$1" msg="$2"
    [ "$active" -eq 1 ] \
        && printf "  ${cFA}[✗ DETECTED]${cNC}  %s\n" "$msg" \
        || printf "  ${cOK}[✓ clear  ]${cNC}  %s\n" "$msg"
}

mark $auth_drops    "Auth NS drops/ignores TYPE65 — HTTPS not served by ${AUTH_ZONE} nameservers"
mark $frag_issue    "UDP fragmentation — TCP works where UDP fails"
mark $unbound_issue "Unbound DNSSEC/policy rejection — Unbound fails, public resolvers work"
mark $all_fail      "Blanket failure — all resolvers + auth fail (nih.gov has no HTTPS records)"

echo ""
printf "  Counters: unb_ok=%-2s unb_fail=%-2s pub_ok=%-2s pub_fail=%-2s auth_ok=%-2s auth_fail=%-2s tcp_saves=%s\n" \
    "$unb_ok" "$unb_fail" "$pub_ok" "$pub_fail" "$auth_ok" "$auth_fail" "$tcp_saves"
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# WORKAROUND
# ═════════════════════════════════════════════════════════════════════════════
DROPIN="/etc/unbound/unbound.conf.d/31-nih-workaround.conf"
WA_TYPE="none"

hdr "── Recommended workaround ───────────────────────────────────────────────"
echo ""

if [ $unbound_issue -eq 1 ]; then
    WA_TYPE="dnssec"
    cat <<ADVICE
  Root cause : Unbound rejects HTTPS RRs for nih.gov (DNSSEC bogus or policy).
  Fix        : Disable DNSSEC validation for nih.gov only.
  Impact     : Zero effect on any other zone.

  ${cBO}File: $DROPIN${cNC}
  ┌──────────────────────────────────────────────────────┐
  │ server:                                              │
  │     domain-insecure: "nih.gov."                      │
  └──────────────────────────────────────────────────────┘
ADVICE

elif [ $frag_issue -eq 1 ]; then
    WA_TYPE="edns"
    cat <<ADVICE
  Root cause : Large HTTPS RRsets exceed MTU → UDP fragments dropped.
  Fix        : Reduce EDNS buffer to avoid fragmentation.
  Impact     : Slightly more TCP fallbacks globally (minor).

  ${cBO}File: $DROPIN${cNC}
  ┌──────────────────────────────────────────────────────┐
  │ server:                                              │
  │     edns-buffer-size: 1232                           │
  └──────────────────────────────────────────────────────┘
ADVICE

elif [ $auth_drops -eq 1 ] || [ $all_fail -eq 1 ]; then
    WA_TYPE="forward"
    cat <<ADVICE
  Root cause : nih.gov auth NS does not serve TYPE65 (EDE 22 = No Reachable
               Authority). Public resolvers confirm: server-side issue.

  Option A — fast-fail forward (least invasive, recommended):
  ┌──────────────────────────────────────────────────────┐
  │ forward-zone:                                        │
  │     name: "nih.gov."                                 │
  │     forward-addr: 8.8.8.8                            │
  │     forward-addr: 9.9.9.9                            │
  │     forward-first: no                                │
  └──────────────────────────────────────────────────────┘
  Effect : SERVFAIL in ~200ms instead of ${TIMEOUT}s timeout.
           forward-first: no prevents slow recursive fallback.
           All other zones completely unaffected.

  Option B — synthesize NODATA for HTTPS only (more surgical):
  ┌──────────────────────────────────────────────────────┐
  │ server:                                              │
  │     local-zone: "nih.gov." typetransparent           │
  │     local-data: "nih.gov. 300 IN HTTPS 1 ."          │
  │     local-data: "nlm.nih.gov. 300 IN HTTPS 1 ."      │
  │     local-data: "ncbi.nlm.nih.gov. 300 IN HTTPS 1 ." │
  │     local-data: "pubmed.ncbi.nlm.nih.gov. 300 IN HTTPS 1 ." │
  └──────────────────────────────────────────────────────┘
  Effect : HTTPS queries → NOERROR (SvcPriority=1 → use A/AAAA of owner).
           A/AAAA/MX/TXT → normal recursion (typetransparent passthrough).
  Note   : Option B changes client HTTPS behaviour; Option A is safer.

  --apply applies Option A.
ADVICE
else
    printf "  All resolvers healthy — no workaround needed.\n"
fi
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# --apply
# ═════════════════════════════════════════════════════════════════════════════
if [ "$APPLY" -eq 1 ] && [ "$WA_TYPE" != "none" ]; then
    hdr "── Applying workaround (--apply) ────────────────────────────────────────"
    echo ""

    case "$WA_TYPE" in
        forward) CONTENT='forward-zone:
    name: "nih.gov."
    forward-addr: 8.8.8.8
    forward-addr: 9.9.9.9
    forward-first: no' ;;
        dnssec) CONTENT='server:
    domain-insecure: "nih.gov."' ;;
        edns) CONTENT='server:
    edns-buffer-size: 1232' ;;
    esac

    tmp=$(mktemp)
    printf '%s\n' "$CONTENT" > "$tmp"

    if [ -f "$DROPIN" ]; then
        BAK="${DROPIN}.bak.$(date -u +%Y%m%d_%H%M%S)"
        sudo cp "$DROPIN" "$BAK"
        pass "Backed up existing drop-in → $BAK"
    fi

    sudo install -m 0644 "$tmp" "$DROPIN"
    rm -f "$tmp"
    pass "Written: $DROPIN"
    cat "$DROPIN"
    echo ""

    if sudo unbound-checkconf 2>&1; then
        pass "unbound-checkconf OK"
        sudo systemctl restart unbound && sleep 2
        state=$(systemctl is-active unbound 2>/dev/null || echo unknown)
        if [ "$state" = "active" ]; then
            pass "unbound restarted OK"
        else
            fail "unbound not active after restart — reverting"
            sudo rm -f "$DROPIN"; sudo systemctl restart unbound; exit 1
        fi
    else
        fail "unbound-checkconf failed — reverting"
        sudo rm -f "$DROPIN"; exit 1
    fi

    echo ""
    hdr "── Post-apply verification ──────────────────────────────────────────────"
    for domain in "${DOMAINS[@]}"; do
        r=$(dig_query 127.0.0.1 5335 "$domain" HTTPS udp yes)
        s=$(f1 "$r"); t=$(f2 "$r")
        printf "  %-40s " "$domain HTTPS"
        sfmt "$s" 12
        printf " %s\n" "$t"
    done
    echo ""

elif [ "$APPLY" -eq 1 ] && [ "$WA_TYPE" = "none" ]; then
    printf "  Nothing to apply.\n\n"
fi

# ═════════════════════════════════════════════════════════════════════════════
# Footer
# ═════════════════════════════════════════════════════════════════════════════
hdr "══════════════════════════════════════════════════════════════════════════"
printf "  Done — %s\n" "$(date -u)"
[ "$APPLY" -eq 0 ] && [ "$WA_TYPE" != "none" ] \
    && printf "  Re-run with --apply to write the recommended drop-in.\n"
hdr "══════════════════════════════════════════════════════════════════════════"
echo ""
