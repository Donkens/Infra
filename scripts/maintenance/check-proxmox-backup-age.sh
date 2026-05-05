#!/usr/bin/env bash
# Purpose: Check Proxmox VM backup freshness on Mac mini off-host dumps, push to Uptime Kuma
# Author:  codex-agent | Date: 2026-05-06
# Runs on: Mac mini (daily at 05:00 via LaunchAgent com.yasse.proxmox-backup-age-check)
# Checks:  /Users/yasse/InfraBackups/proxmox-dumps/ — VMs 101 and 102
# Token:   /Users/yasse/.config/infra/proxmox-backup-monitor.env (chmod 600, never committed)
# Kuma:    Push monitor "Proxmox backup freshness" (ID 16, heartbeat 1500 min)
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly DUMP_DIR="/Users/yasse/InfraBackups/proxmox-dumps"
readonly ENV_FILE="/Users/yasse/.config/infra/proxmox-backup-monitor.env"
readonly LOG_FILE="/tmp/check-proxmox-backup-age.log"
readonly MAX_AGE_SECONDS=129600   # 36 timmar
readonly MIN_SIZE_BYTES=104857600 # 100 MB

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*" | tee -a "$LOG_FILE"; }

# Ladda token — aldrig skriv ut token i klartext
[[ -f "$ENV_FILE" ]] || { log "FAIL: env-fil saknas: $ENV_FILE"; exit 1; }
# shellcheck source=/dev/null
source "$ENV_FILE"
[[ -n "${KUMA_PUSH_TOKEN:-}" ]] || { log "FAIL: KUMA_PUSH_TOKEN ej satt i env-filen"; exit 1; }
[[ -n "${KUMA_PUSH_BASE:-}" ]]  || { log "FAIL: KUMA_PUSH_BASE ej satt i env-filen"; exit 1; }

# Bygg push-URL — token används bara i URL, aldrig i logg
PUSH_URL="${KUMA_PUSH_BASE}/${KUMA_PUSH_TOKEN}"

push() {
  local status="$1" msg="$2"
  # Maskera token i logg-rad
  log "Push: status=$status msg=$msg"
  curl -fsS --max-time 10 \
    "${PUSH_URL}?status=${status}&msg=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$msg")&ping=" \
    -o /dev/null \
    && log "Push levererad OK" \
    || log "WARN: push misslyckades (curl fel)"
}

fail_reasons=()
now=$(date +%s)

check_vm() {
  local vmid="$1"
  local newest
  newest=$(ls -t "${DUMP_DIR}/vzdump-qemu-${vmid}-"*.vma.zst 2>/dev/null | head -1)

  if [[ -z "$newest" ]]; then
    fail_reasons+=("VM${vmid}: ingen backup-fil hittad")
    log "FAIL VM${vmid}: ingen fil i $DUMP_DIR"
    return
  fi

  local mtime size age_h
  mtime=$(stat -f %m "$newest")
  size=$(stat -f %z "$newest")
  age_s=$(( now - mtime ))
  age_h=$(echo "scale=1; $age_s / 3600" | bc)
  local fname
  fname=$(basename "$newest")

  log "VM${vmid}: $fname — ålder ${age_h}h, storlek $(( size / 1048576 )) MB"

  if (( age_s > MAX_AGE_SECONDS )); then
    fail_reasons+=("VM${vmid}: backup ${age_h}h gammal (max 36h)")
    log "FAIL VM${vmid}: för gammal (${age_h}h > 36h)"
  fi

  if (( size < MIN_SIZE_BYTES )); then
    fail_reasons+=("VM${vmid}: filstorlek $(( size / 1048576 )) MB under 100 MB")
    log "FAIL VM${vmid}: för liten ($(( size / 1048576 )) MB < 100 MB)"
  fi
}

log "--- Backup-ålderskontroll startar ---"
check_vm 101
check_vm 102

if [[ ${#fail_reasons[@]} -eq 0 ]]; then
  push "up" "OK - VM101 och VM102 backups farska"
  log "PASS: alla kontroller OK"
else
  # Bygg ett kort meddelande (max ~100 tecken för Kuma)
  msg=$(IFS="; "; echo "${fail_reasons[*]}")
  msg="${msg:0:100}"
  push "down" "$msg"
  log "FAIL: ${fail_reasons[*]}"
  exit 1
fi
