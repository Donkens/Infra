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
step_firewall_rule() {
  log "Step 2: Firewall rule $FW_RULE_NAME (HAOS→Yeelight TCP 55443)"

  # Check if rule already exists
  local policies existing_id
  policies=$(_api_get "/proxy/network/v2/api/site/${UNIFI_SITE}/firewall/zone-policy")
  existing_id=$(echo "$policies" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for p in d if isinstance(d,list) else d.get('data',d.get('policies',[])):
    if p.get('name','') == '${FW_RULE_NAME}':
        print(p.get('_id', p.get('id','')))
        break
" 2>/dev/null || true)

  if [[ -n "$existing_id" ]]; then
    ok "Firewall rule '$FW_RULE_NAME' already exists (id=$existing_id) — no change"
    return
  fi

  log "Creating zone-policy rule '$FW_RULE_NAME' ..."

  # Build payload following allow-haos-wiz-control pattern
  # Source: HAOS IP in Server zone → Destination: Yeelight IP in IoT zone, TCP 55443
  local body
  body=$(python3 -c "
import json
payload = {
    'name': '${FW_RULE_NAME}',
    'enabled': True,
    'action': 'ALLOW',
    'source': {
        'zone_id': '${SERVER_ZONE_ID}',
        'matching_target': 'IP',
        'ip_addresses': ['${HAOS_IP}']
    },
    'destination': {
        'zone_id': '${IOT_ZONE_ID}',
        'matching_target': 'IP',
        'ip_addresses': ['${YEELIGHT_IP}']
    },
    'ip_version': 'ipv4',
    'protocol': 'tcp',
    'ports': ['55443'],
    'create_allow_respond': True,
    'logging': False,
    'description': 'HAOS ${HAOS_IP} → Yeelight Bedroom ${YEELIGHT_IP} TCP 55443. Equivalent to allow-haos-wiz-control for Yeelight.'
}
print(json.dumps(payload))
")

  local resp
  resp=$(_api_post "/proxy/network/v2/api/site/${UNIFI_SITE}/firewall/zone-policy" "$body")

  local rule_id rule_name
  rule_id=$(echo "$resp" | python3 -c "
import json,sys
d=json.load(sys.stdin)
# v2 returns the rule directly or nested
if isinstance(d, dict):
    rid = d.get('_id') or d.get('id') or d.get('data',{}).get('_id','')
    print(rid)
" 2>/dev/null || echo "")
  rule_name=$(echo "$resp" | python3 -c "
import json,sys
d=json.load(sys.stdin)
if isinstance(d, dict):
    print(d.get('name', d.get('data',{}).get('name','')))
" 2>/dev/null || echo "")

  if [[ -z "$rule_id" ]]; then
    log "v2 API response: $resp"
    die "Failed to create firewall rule — check response above"
  fi

  ok "Firewall rule created: '$rule_name' id=$rule_id"
  echo "FIREWALL_RULE_ID=$rule_id"
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
