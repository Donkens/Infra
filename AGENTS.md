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

## OPERATING MODEL

- Default: standalone Codex. Read repo state, plan within scope, execute, and report under this file.
- External planner/reviewer workflows are optional. If the user provides a handoff,
  approved plan, or review context, use it as input, not as a dependency.
- Escalate when architecture is ambiguous, tradeoffs are material, or approval is required.

---

## EXECUTION CONTEXT

### If running in Codex Cloud
- **No SSH.** Do not attempt `ssh pi`, `ssh mini`, `ssh udr` or any remote host.
- **No runtime verification.** Cannot verify DNS, systemd status, service health, or network state.
  Do not fabricate verification output.
- **No Pi/UDR changes.** Flag any task requiring runtime access as:
  `[CLOUD BLOCKED — requires local execution]`
- **Permitted:** repo editing, script writing, config drafting, docs, refactoring, shellcheck.
  All output is draft — user verifies locally.
- Uncertain whether Cloud or local? **Assume Cloud restrictions apply.**

### If running locally (Codex desktop)
Full execution context. SSH available via `ssh pi` / `ssh udr` / `ssh mini`.
Follow Phase 0/1/2 below for any infra/network/remote task.

---

## LANGUAGE

- Swedish for summaries, explanations, planning, and status reporting.
- Original language for commands, paths, config keys, code, error messages, and
  technical terms.
- Do not translate literals.

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

`[APPROVAL REQUIRED]` and `[CLOUD BLOCKED — requires local execution]` are
structural control markers. Use them only as standalone blocks when applicable,
never as repeated report labels.

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

## UNCERTAINTY HANDLING

- State confirmed facts plainly. Do not add bracket tags such as `[VERIFIED]`,
  `[LIKELY]`, or `[HYPOTHESIS]`.
- Mention uncertainty only when it is real and actionable, in natural language.
  Examples: `Could not verify without sudo`, `Likely caused by X`,
  `Not confirmed from current API surface`.
- If unsure about a flag, path, or behavior: run `--help` or `man` first.
  Never invent.

---

## OUTPUT FORMAT

Write for fast human scanning. Conclusions first, evidence second.
Default to compact mode. If the output feels like an audit log, compress it further.
Bracketed markers are not part of normal reporting except the structural safety/runtime
markers defined above.

### Diagnostic / analytic tasks

Tasks involving health checks, diagnostics, network/DNS work, infra changes,
service changes, or system status analysis.

```
## Summary
- 2-5 bullets max
- Current state
- Biggest issue(s)
- What matters most
- Whether action is needed now

## Recommended changes
1. <Change>
   - Why: <reason>
   - Benefit: <impact>
   - Risk: <risk or "none">

2. <Optional cleanup>
   - Why: <reason>
   - Benefit: <impact>
   - Risk: <risk or "none">

## Evidence
- Group compactly by topic, for example: Runtime/API, Config, Logs, System state
- Evidence supports the summary and recommendations; do not attach proof to every sentence

## Uncertainties
- Only when something is genuinely unconfirmed
- Write naturally; no bracket tags

## Next step
- Exactly one concrete next step by default unless the user asked for options
```

Add `## Status [DONE | PARTIAL | BLOCKED | NEEDS_APPROVAL]` only when the
execution state needs to be explicit. Use it once, not on every line.

Do not emit giant "Verified findings" dumps, inline source spam, or cosmetic
findings as standalone items. Compress low-value findings under one optional
cleanup item.

### Non-diagnostic tasks (non-trivial)

```
## Status        [DONE | PARTIAL | BLOCKED | NEEDS_APPROVAL]
## Summary       <1-3 lines, Swedish>
## Actions       <specific files / commands / configs changed>
## Evidence      <compact proof the change works>
## Next step     <one concrete next step only if needed>
## Risks         <only if applicable — omit if none>
```

### Optional handoff format

Use only when the user explicitly wants a structured handoff to another agent or reviewer.

```
TASK: <name>  STATUS: DONE|PARTIAL|BLOCKED
SUMMARY: <1–2 lines, Swedish>
CHANGED: <files>
EVIDENCE: <key verification output or "not run">
ISSUES: <unexpected, if any>
NEXT: <one concrete next step>
```

### Trivial tasks

Trivial tasks (local file operations without system effect) do not require a structured report.
A short confirmation line is sufficient.
Example: `File updated successfully.`
