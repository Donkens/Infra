#!/usr/bin/env bash
# Purpose: Backup Docker VM 102 compose + appdata to local staging, with retention
# Author:  codex-agent | Date: 2026-05-04
# Install: /usr/local/sbin/docker-vm-backup (root:root 755) on Docker VM
# Run:     sudo /usr/local/sbin/docker-vm-backup
#          BACKUP_DIR=/custom/path sudo /usr/local/sbin/docker-vm-backup
set -euo pipefail
umask 0077

readonly SCRIPT_NAME="$(basename "$0")"
readonly TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

# Paths — override via environment if needed
SOURCE_COMPOSE="${SOURCE_COMPOSE:-/srv/compose}"
SOURCE_APPDATA="${SOURCE_APPDATA:-/srv/appdata}"
BACKUP_DIR="${BACKUP_DIR:-/srv/backups/docker-vm-102}"
RETENTION_KEEP="${RETENTION_KEEP:-7}"

readonly BACKUP_FILE="docker-vm-102-backup-${TIMESTAMP}.tar.gz"
readonly BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"
readonly SHA256_PATH="${BACKUP_DIR}/docker-vm-102-backup-${TIMESTAMP}.sha256"

log()  { echo "[${SCRIPT_NAME}] $*" >&2; }
die()  { log "ERROR: $*"; exit 1; }

# Preflight checks
[[ -d "$SOURCE_COMPOSE" ]] || die "SOURCE_COMPOSE not found: $SOURCE_COMPOSE"
[[ -d "$SOURCE_APPDATA" ]] || die "SOURCE_APPDATA not found: $SOURCE_APPDATA"

# Create backup directory (yasse owns /srv, no sudo required)
mkdir -p "$BACKUP_DIR"

log "=== Docker VM 102 backup started ==="
log "Timestamp:  ${TIMESTAMP}"
log "Sources:    ${SOURCE_COMPOSE}  ${SOURCE_APPDATA}"
log "Target:     ${BACKUP_PATH}"

# Strip leading slash for use with -C /
_COMPOSE_REL="${SOURCE_COMPOSE#/}"
_APPDATA_REL="${SOURCE_APPDATA#/}"

# Create tarball
# Excludes:
#   *.sock          — socket files cannot be archived and would cause tar to error
#   */tmp           — transient temp directories
#   */cache         — cache directories
#   */.cache        — hidden cache directories
#   */node_modules  — nodejs module trees (not present now, safe future-proofing)
#   */__pycache__   — python bytecode (not present now, safe future-proofing)
tar \
    --exclude='*.sock' \
    --exclude='*/tmp' \
    --exclude='*/tmp/*' \
    --exclude='*/cache' \
    --exclude='*/cache/*' \
    --exclude='*/.cache' \
    --exclude='*/.cache/*' \
    --exclude='*/node_modules' \
    --exclude='*/node_modules/*' \
    --exclude='*/__pycache__' \
    -czf "$BACKUP_PATH" \
    -C / \
    "$_COMPOSE_REL" \
    "$_APPDATA_REL" \
    || die "tar failed — backup aborted, removing partial file"

# Write SHA256 checksum using filename-only path so it verifies portably
# on any host after rsync (Mac mini uses shasum -a 256 -c, Linux uses sha256sum -c)
(cd "$BACKUP_DIR" && sha256sum "$BACKUP_FILE") > "$SHA256_PATH" \
    || die "sha256sum failed"

# Restrict permissions on backup files
chmod 600 "$BACKUP_PATH" "$SHA256_PATH"

# If running via sudo, chown output files back to the invoking user so rsync
# from Mac mini works without sudo (yasse is the designated VM admin)
if [[ -n "${SUDO_USER:-}" ]]; then
    chown "${SUDO_USER}:${SUDO_USER}" "$BACKUP_DIR" "$BACKUP_PATH" "$SHA256_PATH" 2>/dev/null || true
fi

# Sanitized summary — never print secrets
readonly BACKUP_SIZE="$(du -sh "$BACKUP_PATH" | cut -f1)"
readonly FILE_COUNT="$(tar -tzf "$BACKUP_PATH" 2>/dev/null | wc -l | tr -d ' ')"
readonly SHA256_VALUE="$(cut -d' ' -f1 "$SHA256_PATH")"

log "=== Backup summary ==="
log "File:       ${BACKUP_FILE}"
log "Size:       ${BACKUP_SIZE}"
log "Entries:    ${FILE_COUNT} files/dirs"
log "SHA256:     ${SHA256_VALUE}"
log "Checksum:   $(basename "$SHA256_PATH")"

# Verify the checksum immediately after writing
(cd "$BACKUP_DIR" && sha256sum -c "$(basename "$SHA256_PATH")" --status) \
    || die "Immediate checksum verification failed — backup may be corrupt"
log "Checksum:   VERIFIED OK"

# Retention: remove oldest backups beyond RETENTION_KEEP
TOTAL_BACKUPS=$(find "$BACKUP_DIR" -maxdepth 1 -name 'docker-vm-102-backup-*.tar.gz' | wc -l | tr -d ' ')
if [[ "$TOTAL_BACKUPS" -gt "$RETENTION_KEEP" ]]; then
    TO_DELETE=$(( TOTAL_BACKUPS - RETENTION_KEEP ))
    log "Retention:  removing ${TO_DELETE} old backup(s) (keeping newest ${RETENTION_KEEP})"
    # Oldest first via lexicographic sort (timestamp prefix YYYYmmdd-HHMMSS sorts correctly)
    find "$BACKUP_DIR" -maxdepth 1 -name 'docker-vm-102-backup-*.tar.gz' \
        | sort \
        | head -n "$TO_DELETE" \
        | while IFS= read -r old_backup; do
            log "  Removing: $(basename "$old_backup")"
            rm -f "$old_backup" "${old_backup%.tar.gz}.sha256"
          done
else
    log "Retention:  ${TOTAL_BACKUPS}/${RETENTION_KEEP} backups kept — no pruning needed"
fi

log "=== Done: ${BACKUP_PATH} ==="
