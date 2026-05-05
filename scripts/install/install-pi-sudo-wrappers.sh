#!/usr/bin/env bash
# Purpose: Install root-owned Pi sudo wrappers and exact sudoers allowlist.
# Author:  codex-agent | Date: 2026-05-05
set -euo pipefail
IFS=$'\n\t'

readonly REPO="/home/pi/repos/infra"
readonly SOURCE_DIR="$REPO/scripts/sudo-wrappers"
readonly TARGET_DIR="/usr/local/sbin"
readonly SUDOERS_PATH="/etc/sudoers.d/infra-pi-wrappers"
readonly EXISTING_BACKUP_WRAPPER="/usr/local/sbin/infra-backup-dns-export"

readonly -a WRAPPERS=(
  infra-dns-status
  infra-unbound-validate-reload
  infra-dns-reload
  infra-dns-restart
  infra-adguard-safe-restart
  infra-health-report
  infra-backup-health-check
  infra-restore-drill-check
)

readonly -a LEGACY_RISK_RULES=(
  "/bin/systemctl restart AdGuardHome"
  "/bin/systemctl restart unbound"
  "/usr/local/bin/unbound-control flush_zone *"
  "/usr/local/bin/unbound-control flush *"
)

log() { printf '[install-pi-sudo-wrappers] %s\n' "$*"; }
die() {
  log "STATUS: FAIL"
  log "RESULT: FAIL $*"
  exit 1
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "must run as root"
  fi
}

check_source_tree() {
  [ -d "$SOURCE_DIR" ] || die "missing $SOURCE_DIR"
  local wrapper
  for wrapper in "${WRAPPERS[@]}"; do
    [ -f "$SOURCE_DIR/$wrapper" ] || die "missing $SOURCE_DIR/$wrapper"
  done
}

report_legacy_sudoers_risk() {
  log "CHECK: legacy direct sudoers rules"
  local sudo_l
  sudo_l="$(sudo -l -U pi 2>/dev/null || true)"

  if id -nG pi 2>/dev/null | tr ' ' '\n' | grep -Fx sudo >/dev/null 2>&1; then
    die "pi is in sudo group; remove broad group sudo in a separate audited change before installing wrappers"
  fi

  local rule
  for rule in "${LEGACY_RISK_RULES[@]}"; do
    if printf '%s\n' "$sudo_l" | grep -F -- "$rule" >/dev/null 2>&1; then
      log "RESULT: WARN legacy direct sudo rule present: $rule"
      log "RESULT: WARN migrate operational use to /usr/local/sbin/infra-* wrappers, then remove the legacy rule in a separate approved change"
    else
      log "RESULT: PASS legacy rule absent: $rule"
    fi
  done

  if printf '%s\n' "$sudo_l" | grep -E 'NOPASSWD:[[:space:]]*ALL|\(ALL(:ALL)?\)[[:space:]]+ALL' >/dev/null 2>&1; then
    die "broad sudo rule detected for pi; remove broad sudo in a separate audited change before installing wrappers"
  fi
}

install_wrappers() {
  log "CHECK: install wrappers to $TARGET_DIR"
  install -d -m 0755 -o root -g root "$TARGET_DIR"

  local wrapper
  for wrapper in "${WRAPPERS[@]}"; do
    install -m 0755 -o root -g root "$SOURCE_DIR/$wrapper" "$TARGET_DIR/$wrapper"
    log "RESULT: PASS installed $TARGET_DIR/$wrapper"
  done

  if [ -e "$EXISTING_BACKUP_WRAPPER" ]; then
    log "RESULT: PASS preserved existing $EXISTING_BACKUP_WRAPPER"
  else
    log "RESULT: WARN existing backup export wrapper not found; not creating or replacing it here"
  fi
}

write_sudoers() {
  log "CHECK: sudoers drop-in"
  local tmp_sudoers
  tmp_sudoers="$(mktemp)"

  {
    printf '# Pi infra sudo wrapper allowlist\n'
    printf '# Managed by: %s\n' "$REPO/scripts/install/install-pi-sudo-wrappers.sh"
    printf '# Broad sudo for pi is intentionally not allowed.\n'
    printf '\n'
    local wrapper
    for wrapper in "${WRAPPERS[@]}"; do
      printf 'pi ALL=(root) NOPASSWD: %s/%s\n' "$TARGET_DIR" "$wrapper"
    done
  } > "$tmp_sudoers"

  chmod 0440 "$tmp_sudoers"
  visudo -cf "$tmp_sudoers" >/dev/null
  log "RESULT: PASS generated sudoers validates"

  if [ -e "$SUDOERS_PATH" ]; then
    local backup_path
    backup_path="${SUDOERS_PATH}.bak.$(date '+%Y%m%d-%H%M%S')"
    cp -p "$SUDOERS_PATH" "$backup_path"
    log "RESULT: PASS backed up previous sudoers to $backup_path"
  fi

  install -m 0440 -o root -g root "$tmp_sudoers" "$SUDOERS_PATH"
  rm -f "$tmp_sudoers"
  visudo -cf "$SUDOERS_PATH" >/dev/null
  log "RESULT: PASS installed and validated $SUDOERS_PATH"
}

verify_install() {
  log "CHECK: installed permissions"
  local wrapper
  for wrapper in "${WRAPPERS[@]}"; do
    [ -x "$TARGET_DIR/$wrapper" ] || die "$TARGET_DIR/$wrapper is not executable"
    owner_mode="$(stat -c '%U:%G %a' "$TARGET_DIR/$wrapper")"
    log "RESULT: $TARGET_DIR/$wrapper $owner_mode"
  done

  log "CHECK: pi sudo summary"
  sudo -l -U pi || true
  log "STATUS: PASS"
}

main() {
  require_root
  check_source_tree
  report_legacy_sudoers_risk
  install_wrappers
  write_sudoers
  verify_install
}

main "$@"
