#!/usr/bin/env bash
# Purpose: Syntax-check all tracked .sh files; run shellcheck if available
# Author:  codex-agent | Date: 2026-04-29
set -euo pipefail
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log()  { echo "[$(basename "$0")] $*" >&2; }
die()  { log "ERROR: $*"; exit 1; }

repo_root="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
mapfile -t scripts < <(git -C "$repo_root" ls-files "*.sh")

[[ ${#scripts[@]} -eq 0 ]] && { echo "No shell scripts tracked."; exit 0; }

errors=0

echo "=== bash -n syntax check ==="
for f in "${scripts[@]}"; do
  if ! bash -n "$repo_root/$f" 2>&1; then
    log "FAIL: $f"
    (( errors++ )) || true
  fi
done

if command -v shellcheck &>/dev/null; then
  echo ""
  echo "=== shellcheck ==="
  for f in "${scripts[@]}"; do
    if ! shellcheck -S warning "$repo_root/$f" 2>&1; then
      (( errors++ )) || true
    fi
  done
else
  echo ""
  echo "(shellcheck not found — skipped; install via: apt-get install shellcheck)"
fi

if (( errors > 0 )); then
  die "$errors error(s) found."
fi

echo "Shell syntax OK (${#scripts[@]} files)"
