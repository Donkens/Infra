#!/usr/bin/env bash
# Purpose: Emit a read-only tar stream of Pi DNS backups for off-Pi sync.
# Author:  codex-agent | Date: 2026-04-29
set -euo pipefail

readonly SOURCE="/home/pi/repos/infra/state/backups"

usage() {
  echo "Usage: export-pi-dns-backups [--check|--help]" >&2
}

check_source() {
  if [ ! -d "$SOURCE" ]; then
    echo "ERROR: source missing: $SOURCE" >&2
    exit 1
  fi
  if [ ! -r "$SOURCE" ]; then
    echo "ERROR: source unreadable: $SOURCE" >&2
    exit 1
  fi
}

case "${1:-}" in
  "")
    check_source
    cd "$SOURCE"
    exec tar --numeric-owner -cpf - .
    ;;
  --check)
    check_source
    echo "OK source=$SOURCE" >&2
    ;;
  --help|-h)
    usage
    ;;
  *)
    echo "ERROR: unsupported argument" >&2
    usage
    exit 2
    ;;
esac
