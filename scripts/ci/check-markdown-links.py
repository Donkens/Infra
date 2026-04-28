#!/usr/bin/env python3
"""Check repo-internal Markdown links in tracked .md files."""

from __future__ import annotations

import re
import shlex
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote

LINK_RE = re.compile(r"(?<!!)\[[^\]]*\]\(([^)]*)\)")
SCHEME_RE = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")
FENCE_RE = re.compile(r"^\s*(```|~~~)")


def git_ls_files(pattern: str) -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", pattern],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    )
    return [Path(line) for line in result.stdout.splitlines() if line]


def first_link_token(raw: str) -> str | None:
    raw = raw.strip()
    if not raw:
        return None
    if raw.startswith("<") and raw.endswith(">"):
        return None
    try:
        parts = shlex.split(raw)
    except ValueError:
        parts = raw.split()
    return parts[0] if parts else None


def should_ignore(target: str) -> bool:
    if not target or target.startswith("#"):
        return True
    if SCHEME_RE.match(target):
        return True
    if target.startswith("<") and target.endswith(">"):
        return True
    return False


def iter_links(path: Path):
    in_fence = False
    for lineno, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        if FENCE_RE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        for match in LINK_RE.finditer(line):
            token = first_link_token(match.group(1))
            if token is not None:
                yield lineno, token


def check_file(path: Path, repo_root: Path) -> list[str]:
    broken: list[str] = []
    for lineno, target in iter_links(path):
        if should_ignore(target):
            continue
        target_path = unquote(target.split("#", 1)[0])
        if not target_path:
            continue
        candidate = (repo_root / target_path.lstrip("/")) if target_path.startswith("/") else (path.parent / target_path)
        if not candidate.exists():
            broken.append(f"{path}:{lineno}: broken link -> {target}")
    return broken


def main() -> int:
    repo_root = Path(
        subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
        ).stdout.strip()
    )
    broken: list[str] = []
    for path in git_ls_files("*.md"):
        broken.extend(check_file(path, repo_root))
    if broken:
        print("Broken Markdown links found:")
        for item in broken:
            print(item)
        return 1
    print("Markdown links OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
