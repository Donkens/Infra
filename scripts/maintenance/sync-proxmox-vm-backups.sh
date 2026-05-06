#!/usr/bin/env bash
# Purpose: Pull Proxmox VM backup dumps from opti to Mac mini off-host copy
# Author:  codex-agent | Date: 2026-05-05
# Source:  opti:/var/lib/vz/dump/ (*.vma.zst, *.log, *.notes)
# Dest:    /Users/yasse/InfraBackups/proxmox-dumps/
# Schedule: LaunchAgent com.yasse.proxmox-vm-backup-sync at 04:00 daily
# Proxmox job: daily 03:00, keep-last=3 per VM — dest stays aligned via --delete
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly SRC_HOST="opti"
readonly SRC_PATH="/var/lib/vz/dump/"
readonly DEST_PATH="/Users/yasse/InfraBackups/proxmox-dumps/"
readonly LOG_FILE="/tmp/proxmox-vm-backup-sync.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*" | tee -a "$LOG_FILE" >&2; }
die() { log "ERROR: $*"; exit 1; }

# Ensure SSH agent is running with Keychain keys loaded.
# LaunchAgent context has no SSH_AUTH_SOCK — without this, BatchMode SSH fails at 04:00.
if [[ -z "${SSH_AUTH_SOCK:-}" ]] || ! ssh-add -l &>/dev/null; then
    eval "$(ssh-agent -s)" >/dev/null 2>&1
    ssh-add --apple-load-keychain 2>/dev/null || true
fi

log "Starting Proxmox VM backup sync: ${SRC_HOST}:${SRC_PATH} -> ${DEST_PATH}"

[[ -d "$DEST_PATH" ]] || die "Destination directory does not exist: $DEST_PATH"

# Verify opti is reachable
ssh -o ConnectTimeout=10 -o BatchMode=yes "$SRC_HOST" true \
    || die "Cannot reach $SRC_HOST — aborting sync"

rsync \
    --archive \
    --verbose \
    --human-readable \
    --progress \
    --delete \
    --include="*.vma.zst" \
    --include="*.vma.zst.notes" \
    --include="*.log" \
    --exclude="*" \
    "${SRC_HOST}:${SRC_PATH}" \
    "${DEST_PATH}" \
    2>&1 | tee -a "$LOG_FILE"

SYNC_EXIT=${PIPESTATUS[0]}

if [[ $SYNC_EXIT -eq 0 ]]; then
    log "Sync complete. Files in ${DEST_PATH}:"
    ls -lh "$DEST_PATH" | tee -a "$LOG_FILE"
else
    die "rsync exited with code $SYNC_EXIT"
fi
