#!/usr/bin/env bash
set -euo pipefail

# infra-auto-sync.sh — nightly GitOps-light config snapshot
# Runs as: pi (via systemd)
# Logs to: journald (tag: infra-auto-sync)

REPO_DIR="/home/pi/repos/infra"
BACKUP_SCRIPT="/home/pi/repos/infra/scripts/backup/backup-dns-configs.sh"
BACKUP_ARGS="--export-repo"
export HOME="/home/pi"
export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=10"

log()  { echo "$*" | systemd-cat -t infra-auto-sync -p info; }
fail() { echo "ERROR: $*" | systemd-cat -t infra-auto-sync -p err; exit 1; }

# Sanity checks
[[ -d "$REPO_DIR/.git" ]]  || fail "Repo not found or not a git repo: $REPO_DIR"
[[ -f "$BACKUP_SCRIPT" ]]  || fail "Backup script not found: $BACKUP_SCRIPT"
git -C "$REPO_DIR" remote get-url origin >/dev/null 2>&1 \
  || fail "No git remote 'origin' configured in $REPO_DIR"

log "Starting nightly config snapshot"

# Export live configs into repo
log "Running: $BACKUP_SCRIPT $BACKUP_ARGS"
sudo -n "$BACKUP_SCRIPT" $BACKUP_ARGS 2>&1 | systemd-cat -t infra-auto-sync -p info

# Check for changes (staged + unstaged)
if git -C "$REPO_DIR" diff --quiet && git -C "$REPO_DIR" diff --cached --quiet; then
  log "No changes detected — skipping commit/push"
  exit 0
fi

TS="$(date --iso-8601=seconds)"
log "Changes detected — committing and pushing"

git -C "$REPO_DIR" add -A
git -C "$REPO_DIR" commit -m "auto: nightly config snapshot ${TS}"

if git -C "$REPO_DIR" push; then
  log "Push successful"
else
  fail "git push failed — check SSH key and remote connectivity"
fi
