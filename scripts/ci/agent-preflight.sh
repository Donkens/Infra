#!/usr/bin/env bash
# Purpose: Run repo-only CI/preflight checks for autonomous agent changes.
# Author:  codex-agent | Date: 2026-05-06
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly REPO_ROOT

log() { echo "[$(basename "$0")] $*" >&2; }
die() { log "ERROR: $*"; exit 1; }

run_markdown_links() {
  log "Markdown links"
  python3 "$SCRIPT_DIR/check-markdown-links.py"
}

run_secret_scan() {
  log "Secret-pattern scan"
  cd "$REPO_ROOT"

  if git ls-files | grep -E '(^|/)AdGuardHome\.yaml$' >/dev/null; then
    die "Tracked raw AdGuardHome.yaml is blocked"
  fi

  python3 - <<'PY'
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

SECRET_RE = re.compile(
    r"-----BEGIN (?:RSA |DSA |EC |OPENSSH |PGP )?PRIVATE KEY-----"
    r"|github_pat_[A-Za-z0-9_]{20,}"
    r"|gh[pousr]_[A-Za-z0-9_]{20,}"
    r"|xox[baprs]-[A-Za-z0-9-]{20,}"
    r"|AKIA[0-9A-Z]{16}"
    r"|(?:ADGUARD_PASSWORD|KUMA_PUSH_TOKEN|GITHUB_TOKEN|GH_TOKEN|API_KEY|SECRET_KEY|ACCESS_TOKEN|REFRESH_TOKEN)\s*[:=]\s*[\"']?[A-Za-z0-9_./+=:@-]{16,}",
    re.IGNORECASE,
)

EXCLUDED = {
    Path("docs/security/secrets-policy.md"),
    Path("scripts/ci/agent-preflight.sh"),
}

result = subprocess.run(
    ["git", "ls-files"],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
)

failures: list[str] = []
for raw in result.stdout.splitlines():
    path = Path(raw)
    if path in EXCLUDED:
        continue
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except IsADirectoryError:
        continue
    for lineno, line in enumerate(lines, 1):
        if SECRET_RE.search(line):
            failures.append(f"{path}:{lineno}: secret-like pattern")

if failures:
    print("Obvious secret-like patterns found:")
    for item in failures:
        print(item)
    sys.exit(1)

print("Secret patterns OK")
PY
}

run_runtime_file_guard() {
  log "Runtime file guard"
  cd "$REPO_ROOT"

  local tracked_runtime
  tracked_runtime="$(git ls-files 'logs/*' 'state/*' | grep -Ev '^(logs|state)/\.gitkeep$' || true)"
  if [[ -n "$tracked_runtime" ]]; then
    printf '%s\n' "$tracked_runtime"
    die "Tracked runtime files under logs/ or state/ are blocked"
  fi
}

run_unsafe_example_scan() {
  log "Unsafe example scan"
  cd "$REPO_ROOT"

  python3 - <<'PY'
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOTS = ("docs", "config", "runbooks", "inventory", "scripts")
TEXT_EXTS = {
    ".bash",
    ".conf",
    ".env",
    ".example",
    ".ini",
    ".md",
    ".service",
    ".sh",
    ".timer",
    ".txt",
    ".yaml",
    ".yml",
}

IMAGE_LATEST_RE = re.compile(r"(?i)\bimage\s*:\s*['\"]?[^#\s'\"]+:latest\b")
DOCKER_LATEST_RE = re.compile(r"(?i)\bdocker\s+(?:run|pull|compose\b[^\n#]*\bup\b)[^\n#]*:latest\b")
WILDCARD_BIND_RE = re.compile(r"(?<![0-9])0\.0\.0\.0\s*:")
FENCE_RE = re.compile(r"^\s*(```|~~~)\s*([A-Za-z0-9_-]+)?")
RISKY_MD_FENCES = {"bash", "conf", "dockerfile", "env", "ini", "sh", "shell", "yaml", "yml"}


def git_files() -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", *ROOTS],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    )
    return [Path(line) for line in result.stdout.splitlines() if line]


def is_text_target(path: Path) -> bool:
    return path.suffix in TEXT_EXTS or any(part.endswith(".example") for part in path.parts)


def md_code_lines(path: Path) -> list[tuple[int, str]]:
    lines: list[tuple[int, str]] = []
    in_fence = False
    include_fence = False
    for lineno, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        match = FENCE_RE.match(line)
        if match:
            if not in_fence:
                lang = (match.group(2) or "").lower()
                include_fence = lang in RISKY_MD_FENCES
                in_fence = True
            else:
                in_fence = False
                include_fence = False
            continue
        if in_fence and include_fence:
            lines.append((lineno, line))
    return lines


def scan_lines(path: Path) -> list[tuple[int, str, str]]:
    if path.suffix == ".md":
        candidates = md_code_lines(path)
    else:
        candidates = list(enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1))

    findings: list[tuple[int, str, str]] = []
    for lineno, line in candidates:
        if IMAGE_LATEST_RE.search(line) or DOCKER_LATEST_RE.search(line):
            findings.append((lineno, "latest tag example", line.strip()))
        if WILDCARD_BIND_RE.search(line):
            findings.append((lineno, "0.0.0.0 bind example", line.strip()))
    return findings


failures: list[str] = []
for path in git_files():
    if not is_text_target(path):
        continue
    for lineno, reason, line in scan_lines(path):
        failures.append(f"{path}:{lineno}: {reason}: {line}")

if failures:
    print("Unsafe examples found:")
    for item in failures:
        print(item)
    sys.exit(1)

print("Unsafe examples OK")
PY
}

main() {
  run_markdown_links
  run_secret_scan
  run_runtime_file_guard
  run_unsafe_example_scan
  log "PASS"
}

main "$@"
