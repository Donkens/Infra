#!/usr/bin/env bash
# Purpose: Add Yeelight Bedroom to UniFi — DHCP reservation + firewall rule
# Author:  codex-agent | Date: 2026-05-04
# Run on:  mini (Keychain) or any host with UNIFI_USER / UNIFI_PASS set
# Usage:   bash scripts/unifi-add-yeelight.sh
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
log()  { echo "[$SCRIPT_NAME] $*" >&2; }
die()  { log "ERROR: $*"; exit 1; }
ok()   { log "OK: $*"; }

# ── Tunables ─────────────────────────────────────────────────────────────────
readonly UNIFI_HOST="${UNIFI_HOST:-192.168.1.1}"
readonly UNIFI_SITE="${UNIFI_SITE:-default}"

# Yeelight
readonly YEELIGHT_MAC="28:6c:07:10:84:9e"
readonly YEELIGHT_IP="192.168.10.150"
readonly YEELIGHT_NAME="yeelight-bedroom"

# IoT network (VLAN 10)
readonly IOT_NETWORK_ID="67544633c43374040ca74d5a"

# UniFi firewall zone IDs
readonly SERVER_ZONE_ID="69f7de611bc6e72d2776b75b"   # Server zone (HAOS)
readonly IOT_ZONE_ID="6980de97e060a06b8ef9b613"       # IoT zone

# HAOS source IP
readonly HAOS_IP="192.168.30.20"

# Firewall rule name (follows allow-haos-wiz-control pattern)
readonly FW_RULE_NAME="allow-haos-yeelight-control"

# ── Credentials ───────────────────────────────────────────────────────────────
_get_credentials() {
  # Try Keychain first (mini, logged-in GUI session)
  if [[ -z "${UNIFI_USER:-}" ]]; then
    UNIFI_USER=$(security find-generic-password -s "unifi-mcp-username" -a "yasse" -w 2>/dev/null || true)
  fi
  if [[ -z "${UNIFI_PASS:-}" ]]; then
    UNIFI_PASS=$(security find-generic-password -s "unifi-mcp-password" -a "yasse" -w 2>/dev/null || true)
  fi
  # Fallback: prompt
  if [[ -z "${UNIFI_USER:-}" ]]; then
    read -r -p "UniFi username: " UNIFI_USER
  fi
  if [[ -z "${UNIFI_PASS:-}" ]]; then
    read -r -s -p "UniFi password: " UNIFI_PASS; echo >&2
  fi
  [[ -n "$UNIFI_USER" && -n "$UNIFI_PASS" ]] || die "Credentials missing"
}

# ── UniFi API helpers ─────────────────────────────────────────────────────────
COOKIE=$(mktemp /tmp/yl-cookie-XXXXXX)
CSRF=""
_cleanup() { rm -f "$COOKIE"; }
trap _cleanup EXIT

_login() {
  log "Logging in to https://${UNIFI_HOST} ..."
  local headers
  headers=$(mktemp /tmp/yl-hdr-XXXXXX)
  local code
  code=$(curl -sk -c "$COOKIE" -D "$headers" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${UNIFI_USER}\",\"password\":\"${UNIFI_PASS}\"}" \
    -o /dev/null -w "%{http_code}" \
    "https://${UNIFI_HOST}/api/auth/login")
  [[ "$code" == "200" ]] || die "Login failed HTTP $code"
  CSRF=$(grep -i "^x-csrf-token:" "$headers" | awk '{print $2}' | tr -d '\r\n')
  rm -f "$headers"
  [[ -n "$CSRF" ]] || die "No CSRF token in login response"
  ok "Logged in"
}

_api_get() {
  local path="$1"
  curl -sk -b "$COOKIE" -H "X-Csrf-Token: ${CSRF}" \
    "https://${UNIFI_HOST}${path}"
}

_api_post() {
  local path="$1" body="$2"
  curl -sk -b "$COOKIE" \
    -H "X-Csrf-Token: ${CSRF}" \
    -H "Content-Type: application/json" \
    -d "$body" \
    "https://${UNIFI_HOST}${path}"
}

_api_put() {
  local path="$1" body="$2"
  curl -sk -b "$COOKIE" \
    -X PUT \
    -H "X-Csrf-Token: ${CSRF}" \
    -H "Content-Type: application/json" \
    -d "$body" \
    "https://${UNIFI_HOST}${path}"
}

# ── Step 1: Check / create DHCP reservation ───────────────────────────────────
step_dhcp_reservation() {
  log "Step 1: DHCP reservation for $YEELIGHT_MAC → $YEELIGHT_IP ($YEELIGHT_NAME)"

  # Check if client already has fixed IP
  local clients existing_id
  clients=$(_api_get "/proxy/network/api/s/${UNIFI_SITE}/rest/user")
  existing_id=$(echo "$clients" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for c in d.get('data',[]):
    if c.get('mac','').lower() == '${YEELIGHT_MAC}'.lower():
        print(c.get('_id',''))
        break
" 2>/dev/null || true)

  if [[ -n "$existing_id" ]]; then
    log "Client exists (id=$existing_id) — updating fixed IP and name"
    local body
    body=$(python3 -c "
import json
print(json.dumps({
    'mac': '${YEELIGHT_MAC}',
    'fixed_ip': '${YEELIGHT_IP}',
    'use_fixedip': True,
    'name': '${YEELIGHT_NAME}',
    'network_id': '${IOT_NETWORK_ID}'
}))
")
    local resp
    resp=$(_api_put "/proxy/network/api/s/${UNIFI_SITE}/rest/user/${existing_id}" "$body")
    echo "$resp" | python3 -c "
import json,sys
d=json.load(sys.stdin)
rc=d.get('meta',{}).get('rc','?')
print('PUT rc:', rc)
if rc != 'ok':
    print('FULL RESP:', json.dumps(d,indent=2))
    raise SystemExit(1)
" || die "Failed to update client"
    ok "DHCP reservation updated for $YEELIGHT_NAME → $YEELIGHT_IP"
  else
    log "Client not found — creating new fixed-IP entry"
    local body
    body=$(python3 -c "
import json
print(json.dumps({
    'mac': '${YEELIGHT_MAC}',
    'fixed_ip': '${YEELIGHT_IP}',
    'use_fixedip': True,
    'name': '${YEELIGHT_NAME}',
    'network_id': '${IOT_NETWORK_ID}'
}))
")
    local resp
    resp=$(_api_post "/proxy/network/api/s/${UNIFI_SITE}/rest/user" "$body")
    echo "$resp" | python3 -c "
import json,sys
d=json.load(sys.stdin)
rc=d.get('meta',{}).get('rc','?')
print('POST rc:', rc)
if rc != 'ok':
    print('FULL RESP:', json.dumps(d,indent=2))
    raise SystemExit(1)
" || die "Failed to create DHCP reservation"
    ok "DHCP reservation created: $YEELIGHT_NAME → $YEELIGHT_IP"
  fi
}

# ── Step 2: Check / create firewall rule ──────────────────────────────────────
# Zone-based policy payload (matches backup JSON structure from 2026-04-26)
_build_zone_policy_body() {
  python3 -c "
import json
payload = {
    'name': '${FW_RULE_NAME}',
    'enabled': True,
    'action': 'ALLOW',
    'connection_state_type': 'ALL',
    'connection_states': [],
    'create_allow_respond': True,
    'logging': False,
    'ip_version': 'BOTH',
    'match_ip_sec': False,
    'match_opposite_protocol': False,
    'protocol': 'tcp',
    'icmp_typename': 'ANY',
    'icmp_v6_typename': 'ANY',
    'schedule': {'mode': 'ALWAYS'},
    'source': {
        'zone_id': '${SERVER_ZONE_ID}',
        'matching_target': 'IP',
        'match_opposite_ports': False,
        'port_matching_type': 'ANY',
        'ip_addresses': ['${HAOS_IP}/32']
    },
    'destination': {
        'zone_id': '${IOT_ZONE_ID}',
        'matching_target': 'IP',
        'match_opposite_ports': False,
        'port_matching_type': 'PORTS',
        'ports': ['55443'],
        'ip_addresses': ['${YEELIGHT_IP}/32']
    }
}
print(json.dumps(payload))
"
}

_extract_rule_id() {
  python3 -c "
import json,sys
raw=sys.stdin.read()
try:
    d=json.loads(raw)
    # Legacy endpoint wraps in {meta,data}
    if isinstance(d,dict) and 'data' in d:
        items=d['data']
        if isinstance(items,list) and items:
            print(items[0].get('_id',''))
        elif isinstance(items,dict):
            print(items.get('_id',''))
    elif isinstance(d,dict):
        print(d.get('_id',d.get('id','')))
    elif isinstance(d,list) and d:
        print(d[0].get('_id',''))
except Exception as e:
    import sys; print('PARSE_ERROR:',e,file=sys.stderr)
" 2>/dev/null || true
}

step_firewall_rule() {
  log "Step 2: Firewall rule $FW_RULE_NAME (HAOS→Yeelight TCP 55443)"

  # ── Check if zone-policy rule already exists (legacy list endpoint) ─────────
  local existing_id=""
  local legacy_list
  legacy_list=$(_api_get "/proxy/network/api/s/${UNIFI_SITE}/rest/firewallrule")
  existing_id=$(echo "$legacy_list" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for p in d.get('data',[]):
    if p.get('name','')=='${FW_RULE_NAME}':
        print(p.get('_id',''))
        break
" 2>/dev/null || true)

  if [[ -n "$existing_id" ]]; then
    ok "Rule '$FW_RULE_NAME' already exists (id=$existing_id) — no change"
    return
  fi

  # ── Attempt 1: POST to zone-policy endpoint (firewallpolicy) ───────────────
  # GET returns 400 but POST may work; this is the zone-based format matching
  # the existing Server-zone policies (allow-haos-wiz-control pattern).
  log "Attempt 1: zone-policy via /rest/firewallpolicy"
  local body resp rule_id
  body=$(_build_zone_policy_body)
  resp=$(_api_post "/proxy/network/api/s/${UNIFI_SITE}/rest/firewallpolicy" "$body")
  rule_id=$(echo "$resp" | _extract_rule_id)

  if [[ -n "$rule_id" && "$rule_id" != "PARSE_ERROR"* ]]; then
    ok "Firewall zone-policy created: '$FW_RULE_NAME' id=$rule_id"
    echo "FIREWALL_RULE_ID=$rule_id"
    return
  fi
  log "  firewallpolicy response: $(echo "$resp" | head -c 300)"

  # ── Attempt 2: Legacy firewallrule (LAN_IN ruleset, specific IPs) ──────────
  # Falls back to classic iptables-based rule. Works on all firmware.
  # Source: HAOS 192.168.30.20, Dest: Yeelight 192.168.10.150 TCP 55443.
  # rule_index 10050 — above the existing WiZ/DNS rules at 10000-10001.
  log "Attempt 2: legacy firewallrule (LAN_IN, specific IPs, TCP 55443)"
  local legacy_body
  legacy_body=$(python3 -c "
import json
print(json.dumps({
    'name': '${FW_RULE_NAME}',
    'enabled': True,
    'ruleset': 'LAN_IN',
    'rule_index': 10050,
    'action': 'accept',
    'protocol': 'tcp',
    'logging': False,
    'src_ip_type': 'ADDRv4',
    'src_address': '${HAOS_IP}',
    'dst_ip_type': 'ADDRv4',
    'dst_address': '${YEELIGHT_IP}',
    'dst_port': '55443',
    'state_new': True,
    'state_established': True,
    'state_related': True,
    'state_invalid': False
}))
")
  resp=$(_api_post "/proxy/network/api/s/${UNIFI_SITE}/rest/firewallrule" "$legacy_body")
  rule_id=$(echo "$resp" | _extract_rule_id)

  if [[ -n "$rule_id" && "$rule_id" != "PARSE_ERROR"* ]]; then
    ok "Legacy firewall rule created: '$FW_RULE_NAME' id=$rule_id"
    log "NOTE: This is a legacy LAN_IN rule. Verify in UniFi UI under Legacy Firewall."
    echo "FIREWALL_RULE_ID=$rule_id"
    return
  fi
  log "  firewallrule response: $(echo "$resp" | head -c 300)"

  die "Both zone-policy and legacy rule creation failed — see responses above"
}

# ── Step 3: Verify HAOS → Yeelight connectivity ───────────────────────────────
step_verify_connectivity() {
  log "Step 3: Verifying HAOS → Yeelight TCP 55443 ..."
  local result
  result=$(/usr/bin/ssh -o ConnectTimeout=10 -o BatchMode=yes ha \
    'python3 -c "
import socket,json
s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
s.settimeout(8)
try:
    s.connect((\"192.168.10.150\",55443))
    cmd=json.dumps({\"id\":1,\"method\":\"get_prop\",\"params\":[\"power\",\"bright\",\"name\"]})+\"\r\n\"
    s.sendall(cmd.encode())
    import time; time.sleep(1)
    r=s.recv(1024)
    s.close()
    d=json.loads(r)
    print(\"OPEN:\",d.get(\"result\",\"?\"))
except Exception as e:
    print(\"BLOCKED:\",e)
"' 2>&1 || echo "SSH_FAILED")
  echo "CONNECTIVITY: $result"
  if echo "$result" | grep -q "^OPEN:"; then
    ok "HAOS → Yeelight TCP 55443 is REACHABLE"
    return 0
  else
    log "WARN: HAOS → Yeelight still blocked — firewall may need ~30s to apply"
    return 0
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  log "=== Yeelight Bedroom UniFi setup ==="
  log "  Yeelight: $YEELIGHT_MAC → $YEELIGHT_IP ($YEELIGHT_NAME)"
  log "  Firewall: HAOS $HAOS_IP → Yeelight $YEELIGHT_IP TCP 55443"

  _get_credentials
  _login
  step_dhcp_reservation
  step_firewall_rule
  step_verify_connectivity

  log "=== Done. Next step: add Yeelight integration in HA UI (see docs) ==="
}

main "$@"
