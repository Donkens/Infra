#!/usr/bin/env bash
set -euo pipefail

# infra-auto-sync.sh — nightly GitOps-light config snapshot
# Runs as: pi (via systemd)
# Logs to: journald (tag: infra-auto-sync)

REPO_DIR="/home/pi/repos/infra"
BACKUP_SCRIPT="/home/pi/repos/infra/scripts/backup/backup-dns-configs.sh"
BACKUP_ARGS="--export-repo"
AUTO_SYNC_STAGE_PATHS=(
  "config/adguardhome/AdGuardHome.summary.sanitized.yml"
  "config/adguardhome/README.md"
  "config/unbound/unbound.conf"
  "config/unbound/unbound.conf.d/*.conf"
)
# Explicitly set HOME for systemd service context — git and ssh read ~/.ssh and ~/.gitconfig from $HOME.
export HOME="/home/pi"
export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=10"

log()  { echo "$*" | systemd-cat -t infra-auto-sync -p info; }
fail() { echo "ERROR: $*" | systemd-cat -t infra-auto-sync -p err; exit 1; }

log_multiline() {
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] && log "$line"
  done <<< "$1"
}

classify_git_error() {
  local output="$1"

  if grep -qiE 'Permission denied \(publickey\)|Authentication failed|Could not read from remote repository' <<< "$output"; then
    echo "auth"
  elif grep -qiE 'Could not resolve hostname|Name or service not known|Temporary failure in name resolution|Connection timed out|No route to host|Connection refused' <<< "$output"; then
    echo "network"
  elif grep -qiE 'fetch first|non-fast-forward' <<< "$output"; then
    echo "non-fast-forward"
  elif grep -qiE 'unstaged changes|uncommitted changes|Please commit or stash them|index contains uncommitted changes' <<< "$output"; then
    echo "dirty"
  elif grep -qiE 'CONFLICT|Resolve all conflicts manually|could not apply' <<< "$output"; then
    echo "rebase-conflict"
  else
    echo "other"
  fi
}

ensure_clean_worktree() {
  if [[ -n "$(git -C "$REPO_DIR" status --porcelain)" ]]; then
    fail "Repository has pre-existing uncommitted changes — aborting auto-sync"
  fi
}

stage_allowlisted_changes() {
  local remaining_status
  local unstaged_changes
  local untracked_changes

  git -C "$REPO_DIR" add -- "${AUTO_SYNC_STAGE_PATHS[@]}"

  unstaged_changes="$(git -C "$REPO_DIR" diff --name-only)"
  untracked_changes="$(git -C "$REPO_DIR" ls-files --others --exclude-standard)"
  if [[ -n "$unstaged_changes" || -n "$untracked_changes" ]]; then
    remaining_status="$(git -C "$REPO_DIR" status --short --untracked-files=all)"
    log "Auto-sync produced changes outside the allowlist:"
    log_multiline "$remaining_status"
    fail "Auto-sync aborting before commit"
  fi
}
update_divergence() {
  local counts
  counts="$(git -C "$REPO_DIR" rev-list --left-right --count HEAD...origin/main)"
  AHEAD_COMMITS="${counts%%$'\t'*}"
  BEHIND_COMMITS="${counts##*$'\t'}"
}

fetch_origin_main() {
  local output=""

  log "Fetching origin/main"
  if ! output="$(git -C "$REPO_DIR" fetch origin main 2>&1)"; then
    [[ -n "$output" ]] && log_multiline "$output"
    case "$(classify_git_error "$output")" in
      auth) fail "git fetch failed: authentication error talking to origin" ;;
      network) fail "git fetch failed: network error talking to origin" ;;
      *) fail "git fetch failed while updating origin/main" ;;
    esac
  fi

  [[ -n "$output" ]] && log_multiline "$output"
}

rebase_onto_origin_main_if_needed() {
  update_divergence

  if (( BEHIND_COMMITS == 0 )); then
    if (( AHEAD_COMMITS > 0 )); then
      log "Local branch already ahead of origin/main by ${AHEAD_COMMITS} commit(s)"
    else
      log "Local branch already in sync with origin/main"
    fi
    return 0
  fi

  log "Local branch diverged from origin/main (ahead=${AHEAD_COMMITS}, behind=${BEHIND_COMMITS}) — rebasing"

  local output=""
  if ! output="$(git -C "$REPO_DIR" rebase origin/main 2>&1)"; then
    [[ -n "$output" ]] && log_multiline "$output"
    git -C "$REPO_DIR" rebase --abort >/dev/null 2>&1 || true
    case "$(classify_git_error "$output")" in
      dirty) fail "git rebase blocked: repository has uncommitted changes" ;;
      rebase-conflict) fail "git rebase failed: conflict against origin/main — manual resolution required" ;;
      *) fail "git rebase failed while syncing with origin/main" ;;
    esac
  fi

  [[ -n "$output" ]] && log_multiline "$output"
}

sync_with_origin_main() {
  fetch_origin_main
  rebase_onto_origin_main_if_needed
}

# Sanity checks
[[ -d "$REPO_DIR/.git" ]]  || fail "Repo not found or not a git repo: $REPO_DIR"
[[ -f "$BACKUP_SCRIPT" ]]  || fail "Backup script not found: $BACKUP_SCRIPT"
git -C "$REPO_DIR" remote get-url origin >/dev/null 2>&1 \
  || fail "No git remote 'origin' configured in $REPO_DIR"

log "Starting nightly config snapshot"
ensure_clean_worktree
sync_with_origin_main

# Export live configs into repo
log "Running: $BACKUP_SCRIPT $BACKUP_ARGS"
sudo -n "$BACKUP_SCRIPT" $BACKUP_ARGS 2>&1 | systemd-cat -t infra-auto-sync -p info

# Check for changes (staged + unstaged)
if git -C "$REPO_DIR" diff --quiet && git -C "$REPO_DIR" diff --cached --quiet; then
  update_divergence
  if (( AHEAD_COMMITS == 0 )); then
    log "No changes detected — skipping commit/push"
    exit 0
  fi

  log "No new file changes detected — pushing ${AHEAD_COMMITS} pending local commit(s)"
fi

TS="$(date --iso-8601=seconds)"
if [[ -n "$(git -C "$REPO_DIR" status --porcelain)" ]]; then
  log "Changes detected — committing"
  stage_allowlisted_changes
  git -C "$REPO_DIR" commit -m "auto: nightly config snapshot ${TS}"
fi

sync_with_origin_main

# Retry logic for git push (3 attempts, 10s between)
MAX_ATTEMPTS=3
ATTEMPT=0
PUSH_OK=false

while (( ATTEMPT < MAX_ATTEMPTS )); do
  ATTEMPT=$((ATTEMPT + 1))
  log "Push attempt $ATTEMPT/$MAX_ATTEMPTS"

  PUSH_OUTPUT=""
  if PUSH_OUTPUT="$(git -C "$REPO_DIR" push 2>&1)"; then
    [[ -n "$PUSH_OUTPUT" ]] && log_multiline "$PUSH_OUTPUT"
    PUSH_OK=true
    log "Push successful"
    break
  fi

  [[ -n "$PUSH_OUTPUT" ]] && log_multiline "$PUSH_OUTPUT"

  case "$(classify_git_error "$PUSH_OUTPUT")" in
    auth)
      fail "git push failed: authentication error talking to origin"
      ;;
    network)
      if (( ATTEMPT < MAX_ATTEMPTS )); then
        log "git push hit a network error — retrying in 10s"
        sleep 10
        continue
      fi
      fail "git push failed after $MAX_ATTEMPTS attempts: network error talking to origin"
      ;;
    non-fast-forward)
      if (( ATTEMPT < MAX_ATTEMPTS )); then
        log "git push rejected: origin/main advanced — fetching and rebasing before retry"
        sync_with_origin_main
        continue
      fi
      fail "git push failed after $MAX_ATTEMPTS attempts: origin/main kept advancing"
      ;;
    *)
      if (( ATTEMPT < MAX_ATTEMPTS )); then
        log "git push failed for an unknown reason — retrying in 10s"
        sleep 10
        continue
      fi
      fail "git push failed after $MAX_ATTEMPTS attempts"
      ;;
  esac
done

if [[ "$PUSH_OK" != "true" ]]; then
  fail "git push did not complete successfully"
fi
