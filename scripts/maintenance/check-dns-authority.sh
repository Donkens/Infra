#!/usr/bin/env bash
# Purpose: Verify DNS authority split: AdGuard forward records, Unbound recursion/PTR.
# Author:  codex-agent | Date: 2026-04-29
#
# Intended to run on Pi. The Unbound default target is 127.0.0.1:5335,
# so running from another host requires UNBOUND_SERVER/UNBOUND_PORT override.
set -euo pipefail

readonly ADGUARD_SERVER="${ADGUARD_SERVER:-192.168.1.55}"
readonly UNBOUND_SERVER="${UNBOUND_SERVER:-127.0.0.1}"
readonly UNBOUND_PORT="${UNBOUND_PORT:-5335}"

fail_count=0

log() { echo "[$(basename "$0")] $*" >&2; }

pass() {
  echo "PASS $*"
}

fail() {
  echo "FAIL $*"
  fail_count=$((fail_count + 1))
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "required command missing: $1"
  fi
}

dig_short() {
  local server="$1"
  local port="$2"
  local name="$3"
  local type="$4"

  dig @"$server" -p "$port" "$name" "$type" +short +time=2 +tries=1 2>/dev/null | sed '/^$/d'
}

dig_status() {
  local server="$1"
  local port="$2"
  local name="$3"
  local type="$4"

  dig @"$server" -p "$port" "$name" "$type" +time=2 +tries=1 2>/dev/null \
    | awk '/status:/ { sub(/^.*status: /, ""); sub(/,.*/, ""); print; exit }'
}

expect_a() {
  local label="$1"
  local server="$2"
  local name="$3"
  local expected="$4"
  local got

  got="$(dig_short "$server" 53 "$name" A | paste -sd ' ' -)"
  if [[ " $got " == *" $expected "* ]]; then
    pass "$label A $name -> $expected via $server"
  else
    fail "$label A $name expected $expected via $server, got: ${got:-<empty>}"
  fi
}

expect_unbound_no_forward_a() {
  local name="pi.home.lan"
  local got status

  got="$(dig_short "$UNBOUND_SERVER" "$UNBOUND_PORT" "$name" A | paste -sd ' ' -)"
  status="$(dig_status "$UNBOUND_SERVER" "$UNBOUND_PORT" "$name" A)"
  if [[ -z "$got" && "$status" == "NXDOMAIN" ]]; then
    pass "Unbound direct forward $name A has no A answer and status NXDOMAIN"
  elif [[ -z "$got" ]]; then
    pass "Unbound direct forward $name A has no A answer (status ${status:-unknown})"
  else
    fail "Unbound direct forward $name A should not return A records, got: $got"
  fi
}

expect_unbound_ptr() {
  local ip="192.168.1.55"
  local expected="pi.home.lan."
  local got

  got="$(dig @"$UNBOUND_SERVER" -p "$UNBOUND_PORT" -x "$ip" +short +time=2 +tries=1 2>/dev/null | sed '/^$/d' | paste -sd ' ' -)"
  if [[ " $got " == *" $expected "* ]]; then
    pass "Unbound PTR $ip -> $expected"
  else
    fail "Unbound PTR $ip expected $expected via $UNBOUND_SERVER:$UNBOUND_PORT, got: ${got:-<empty>}"
  fi
}

main() {
  require_cmd dig
  if (( fail_count > 0 )); then
    exit 1
  fi

  if [[ "$(hostname 2>/dev/null || true)" != "pi" && "$UNBOUND_SERVER" == "127.0.0.1" ]]; then
    log "NOTE: default Unbound check is Pi-local at 127.0.0.1:5335; run on Pi or override UNBOUND_SERVER."
  fi

  expect_a "AdGuard forward" "$ADGUARD_SERVER" "pi.home.lan" "192.168.1.55"
  expect_a "AdGuard forward" "$ADGUARD_SERVER" "macmini.home.lan" "192.168.1.86"
  expect_a "AdGuard forward" "$ADGUARD_SERVER" "adguard.home.lan" "192.168.1.55"
  expect_unbound_no_forward_a
  expect_unbound_ptr

  if (( fail_count > 0 )); then
    log "DNS authority check failed with $fail_count failure(s)."
    exit 1
  fi

  log "DNS authority check passed."
}

main "$@"
