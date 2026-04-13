# AGENTS.md — Infra Repo: Agent Instructions

> Single source of truth for all agent policy. Read before any task.
> Updated: 2026-04-13

---

## DECISION RULES

**Is this task trivial?**
Trivial = single-file local edit, docs/text only, no infra/network/cross-host impact.
→ YES: Act immediately. Skip Phase 0/1.
→ NO (infra/network/remote/system service): Phase 0 mandatory.

**Does it touch sudo / existing file overwrite / remote push / destructive command?**
→ STOP: Show approval block. Wait for GO.

---

## ENVIRONMENT

```bash
arch=$(uname -m)                                  # arm64 | x86_64
brew_prefix=$(brew --prefix 2>/dev/null || true)  # /opt/homebrew | /usr/local
```

- Shell: zsh. All scripts: `set -euo pipefail`
- Python: `python3` (3.12). Prefer venv; `--break-system-packages` outside venv.
- Scripts source of truth: `~/Library/Mobile Documents/com~apple~CloudDocs/Scripts/`
- `~/bin` = symlinks into iCloud Scripts — don't break, don't duplicate.
- Never hardcode brew paths. Always `$(brew --prefix)`.

---

## SAFETY

### Hard blocked — never without explicit instruction
```
rm -rf *  |  git push --force  |  git reset --hard  |  sudo rm
DROP TABLE / TRUNCATE  |  systemctl stop/disable (production)
git add -A  |  git add .
```

### Approval gate — show this block, wait for GO
```
[APPROVAL REQUIRED]
Action:   <what>
Reason:   <why>
Risk:     <what could go wrong>
Rollback: <how to undo>
Command:  <exact command>
```
Triggers: `sudo`, overwrite existing file, `/etc/` or `LaunchAgents`, push to remote,
`--force/-f/--hard`, any change affecting a remote host on the network.

### Run freely (no approval)
```
git status/log/diff  |  ls/find/cat/head/tail  |  uname -m
brew list  |  ping/dig/nslookup/traceroute  |  python3 --version
```
Read-only SSH to managed targets: allowed — show exact command first.

---

## WORKFLOW PHASES

**Fast path (trivial tasks):** Act → Verify → Done. No phases.

**Phase 0 — Recon** *(mandatory for infra/network/remote tasks)*
Read-only only. Collect: `hostname`, `uname -a`, `uname -m`, `git status --short --branch`,
`brew --prefix`. No writes. Output: current state + proposed action plan.

**Phase 1 — Plan**
Propose exact commands + blast radius. No execution.
Wait for GO before any write, config change, or remote action.

**Phase 2 — Execute**
Execute approved plan step by step. Show output per step. Verify each step.
Propose rollback if verification fails.

---

## GIT

- `git status` before editing. `git diff HEAD -- <file>` before staging.
- Stage specific files only — never `git add -A` or `git add .`
- Commit: `<type>(<scope>): <subject ≤72 chars>` — types: fix/feat/chore/refactor/docs/infra
- Never amend published commits. Never push without instruction. No new branches unless asked.

---

## SCRIPTING STANDARDS

```bash
#!/usr/bin/env bash
# Purpose: <one line>
# Author:  codex-agent | Date: YYYY-MM-DD
set -euo pipefail
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log() { echo "[$(basename "$0")] $*" >&2; }
die() { log "ERROR: $*"; exit 1; }
```

- No secrets — Bitwarden (`op read`) or env vars. Never inline.
- Backup filenames: append `$(date +%Y%m%d_%H%M%S)`
- shellcheck-compatible
- Brew: always `$(brew --prefix)`, never hardcoded

---

## INFRASTRUCTURE CONTEXT

| Component | Role | Notes |
|-----------|------|-------|
| UDR-7 | Gateway / VLAN / firewall | Zone-based firewall active |
| AdGuard Home | DNS filter | 192.168.1.55 |
| Unbound | Recursive resolver | Pi, feeds from AdGuard |
| Raspberry Pi | DNS + `*.home.lan` | `ssh pi` |
| Mac mini M1 | Primary compute | `ssh mini`, 192.168.1.86 |

DNS chain: client → AdGuard (192.168.1.55) → Unbound → upstream
Never add parallel resolvers. One chain only.

Debug order: routing → firewall → DNS → application — don't skip layers without evidence.

---

## CONFIDENCE LABELS

- `[VERIFIED]` — tested/confirmed output
- `[LIKELY]` — high confidence, context-based
- `[HYPOTHESIS]` — needs verification before acting

If unsure about a flag, path, or behavior: run `--help` or `man` first. Never invent.

---

## OUTPUT FORMAT

**Non-trivial tasks:**
```
## Status        [DONE | BLOCKED | NEEDS_APPROVAL]
## What changed  <specific files / commands / configs>
## Verification  <output proving the change works>
## Risks         <anything needing human attention>
```

**Multi-agent reporting (Codex → Claude):**
```
TASK: <name>  STATUS: DONE|PARTIAL|BLOCKED
CHANGED: <files>  VERIFIED: <output>  ISSUES: <unexpected>  NEXT: <recommendation>
```

---

## MULTI-AGENT ROLES

- **Claude:** planning, architecture decisions, approval gates
- **Codex:** code generation, file edits, execution, structured reporting
- Surface architectural decisions and tradeoffs to Claude — don't decide autonomously.
- On unexpected state, ambiguity, or competing approaches: escalate, don't assume.
