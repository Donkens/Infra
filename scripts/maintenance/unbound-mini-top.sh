#!/usr/bin/env bash

INTERVAL="${1:-2}"          # sek mellan uppdateringar (default 2s)
CONF="/etc/unbound/unbound.conf"

get_stat() {
  echo "$STATS" | awk -F= -v key="$1" '$1==key {print $2; exit}'
}

while true; do
  STATS="$(unbound-control -c "$CONF" stats_noreset 2>/dev/null)"
  TS="$(date '+%H:%M:%S')"

  TOTAL_Q=$(get_stat "total.num.queries")
  CACHE_H=$(get_stat "total.num.cachehits")
  CACHE_M=$(get_stat "total.num.cachemiss")
  QPS=$(get_stat "total.qps")
  RECURSION_TIME=$(get_stat "total.recursion.time.avg")

  Q_IPV4=$(get_stat "total.num.query.ipv4")
  Q_IPV6=$(get_stat "total.num.query.ipv6")

  Q_UDP=$(get_stat "total.num.query.udp")
  Q_TCP=$(get_stat "total.num.query.tcp")

  ANS_SECURE=$(get_stat "total.num.answer.secure")
  ANS_BOGUS=$(get_stat "total.num.answer.bogus")

  UNW_Q=$(get_stat "total.unwanted.queries")
  UNW_R=$(get_stat "total.unwanted.replies")

  RRSET_BOGUS=$(get_stat "total.num.rrset.bogus")

  PREFETCH=$(get_stat "total.num.prefetch")
  ZERO_TTL=$(get_stat "total.num.zero_ttl")
  EXPIRED=$(get_stat "total.num.expired")

  # Cache hitrate
  if [[ -n "$CACHE_H" && -n "$CACHE_M" ]]; then
    HITRATE=$(awk -v h="$CACHE_H" -v m="$CACHE_M" 'BEGIN {
      if (h + m == 0) { print "0.0" }
      else { printf "%.1f", (h / (h + m)) * 100 }
    }')
  else
    HITRATE="0.0"
  fi

  # DNSSEC success rate
  if [[ -n "$ANS_SECURE" && -n "$ANS_BOGUS" ]]; then
    DNSSEC_RATE=$(awk -v s="$ANS_SECURE" -v b="$ANS_BOGUS" 'BEGIN {
      if (s + b == 0) { print "0.0" }
      else { printf "%.1f", (s / (s + b)) * 100 }
    }')
  else
    DNSSEC_RATE="0.0"
  fi

  clear
  echo "Unbound mini-dashboard v2 @ $TS"
  echo "======================================"
  echo "📊 Allmänt"
  echo "  Total queries:        ${TOTAL_Q:-0}"
  echo "  QPS (approx):         ${QPS:-0}"
  echo "  Avg recursion time:   ${RECURSION_TIME:-n/a} s"
  echo
  echo "🧠 Cache"
  echo "  Cache hits:           ${CACHE_H:-0}"
  echo "  Cache misses:         ${CACHE_M:-0}"
  echo "  Cache hit rate:       ${HITRATE}%"
  echo "  Prefetch:             ${PREFETCH:-0}"
  echo "  Zero TTL:             ${ZERO_TTL:-0}"
  echo "  Expired reused:       ${EXPIRED:-0}"
  echo
  echo "🌍 Protokoll / transport"
  echo "  IPv4 queries:         ${Q_IPV4:-0}"
  echo "  IPv6 queries:         ${Q_IPV6:-0}"
  echo "  UDP queries:          ${Q_UDP:-0}"
  echo "  TCP queries:          ${Q_TCP:-0}"
  echo
  echo "🔐 DNSSEC"
  echo "  Secure answers:       ${ANS_SECURE:-0}"
  echo "  Bogus answers:        ${ANS_BOGUS:-0}"
  echo "  Secure ratio:         ${DNSSEC_RATE}%"
  echo "  Bogus rrsets:         ${RRSET_BOGUS:-0}"
  echo
  echo "⚠️  Misstänkta saker"
  echo "  Unwanted queries:     ${UNW_Q:-0}"
  echo "  Unwanted replies:     ${UNW_R:-0}"
  echo
  echo "Kör på: $(hostname)  |  interval: ${INTERVAL}s"
  echo "Avsluta med Ctrl+C."
  sleep "$INTERVAL"
done
