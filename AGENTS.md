# AGENTS.md — Codex Agent Instructions

> This file is read by OpenAI Codex agents before any task execution.
> It defines environment constraints, safety rules, and behavioral contracts.
> Last updated: 2026-04-12

---
## Agent Boot Sequence

Before performing any task:

1. Read AGENTS.md
2. Read CODEX.md
3. Detect host architecture
4. Determine workflow phase

## ENVIRONMENT

### Host Architecture
- **Mac mini M1** — ARM64, Homebrew at `/opt/homebrew`, primary reference machine
- **MacBook Pro 2015** — Intel x86_64, OCLP, Homebrew at `/usr/local`

Before executing any binary, brew command, or path-dependent script, detect architecture:
```bash
arch=$(uname -m)  # arm64 | x86_64
```
Never hardcode `/opt/homebrew` or `/usr/local`. Use `$(brew --prefix)` or detect at runtime.

### Source of Truth
- **iCloud Drive** is the single source of truth for scripts and config.
- Scripts live at: `~/Library/Mobile Documents/com~apple~CloudDocs/Scripts/`
- `~/bin` contains symlinks pointing into the iCloud Scripts folder — do not break these.
- Never duplicate scripts locally if an iCloud version exists.

### Python
- Target: Python 3.12
- Always use `python3`, never `python`
- Prefer venv for isolated work; do not pollute the system site-packages
- Pip installs outside venv require `--break-system-packages` on this system

### Shell
- Default: `zsh`
- All scripts must use: `set -euo pipefail`

---

## SAFETY RULES

### Mandatory — No Exceptions
1. **Never execute destructive commands without explicit user confirmation.**
   Destructive = `rm -rf`, `git reset --hard`, `git push --force`, `DROP TABLE`, `truncate`, config overwrites.
2. **Never commit secrets.** No API keys, passwords, tokens, or credentials in any file.
   Secrets source: Bitwarden. Reference by name, never inline.
3. **Never modify firewall rules, DNS config, or network topology autonomously.**
   These require Phase 2 approval (see Workflow section).
4. **Never push to remote without explicit instruction.**
5. **Never run `git add -A` or `git add .`** — always stage specific files.

### Safe-by-Default Command Policy
- Read-only operations: run freely, show output
- File creation in working directory: run freely
- File modification of existing files: show diff before applying
- Anything involving `sudo`: pause, state intent, wait for GO
- Anything touching system config (`/etc/`, LaunchAgents, cron, plist): pause and explain

---

## WORKFLOW PHASES

This project uses a 3-phase model for any non-trivial change:

Execution hosts for Codex are the local Macs in this environment.
Raspberry Pi and UDR-7 are managed remote targets, not execution hosts.

### Phase 0 — Read-Only Recon
Collect facts. Run only diagnostic/read commands. No writes.
Output: clear summary of current state + proposed action plan.

**Phase 0 is mandatory when the task involves any of:**
DNS, firewall, routing, VLANs, network topology, remote hosts (Pi, Mac mini, UDR-7),
system services (systemd, launchd), SSH config, or any change that affects another
machine on the network. Do not proceed to Phase 1 without completing Phase 0 for
these categories.

Any planned change to a managed remote target requires Phase 0 first.
Do not execute SSH against a remote target until the exact command or script has been shown and explicitly approved.

### Phase 1 — Plan
Propose specific changes. State exact commands. State blast radius.
Do NOT execute. Wait for explicit GO.

### Phase 2 — Execute
Execute approved plan. Show output for each step. Verify after each change.
Propose rollback if verification fails.

**Phase 0 may be skipped only for trivial tasks: single-file, local, documentation
or text-only edits with no infrastructure or cross-host impact.**

---

## GIT BEHAVIOR

- Always check `git status` before any edit
- Show `git diff` before staging
- Commit messages: imperative, present tense, max 72 chars subject
- Never amend published commits
- Never rebase interactively without explicit instruction
- Branch naming: `type/short-description` (e.g., `fix/dns-unbound-loop`, `feat/backup-script`)
- Do not create branches unless instructed

---

## INFRASTRUCTURE CONTEXT

This repository may interact with:

| Component | Role | Notes |
|-----------|------|-------|
| UDR-7 | Gateway, VLAN routing, firewall | Zone-based firewall active |
| AdGuard Home | DNS filter (192.168.1.55) | Single DNS authority |
| Unbound | Recursive resolver on Pi | Feeds from AdGuard |
| Raspberry Pi | DNS server, `*.home.lan` authority | SSH alias: `ssh pi` |
| Mac mini M1 | Primary compute (192.168.1.86) | SSH alias: `ssh mini` |

**DNS chain**: client → AdGuard (192.168.1.55) → Unbound → upstream
**Never add parallel DNS logic** — one chain, no splits.

**Debugging layer order**: routing → firewall → DNS → application
Do not skip layers without evidence.

---

## HALLUCINATION PREVENTION

- If you are uncertain about a command's behavior on this specific OS/arch: **say so explicitly**
- Do not fabricate file paths, tool flags, or API responses
- If a library version or flag is unknown: `--help` or `man` first
- Label clearly: `[VERIFIED]` vs `[HYPOTHESIS]`
- When multiple approaches exist: list them, state tradeoffs, let the user choose

---

## MULTI-AGENT COORDINATION

When operating as a sub-agent under Claude orchestration:

- Claude handles: planning, architecture decisions, ambiguous requirements, approval gates
- Codex handles: code generation, script writing, file edits, test execution
- Do not make architectural decisions autonomously — surface them to Claude/user
- Output structured results that Claude can parse: use headers, code blocks, explicit status lines
- End every task with a `## Result` section: what was done, what changed, verification output

---

## OUTPUT FORMAT

For every non-trivial task, structure output as:

```
## Status
[DONE | BLOCKED | NEEDS_APPROVAL]

## What changed
<specific files/commands/configs touched>

## Verification
<output proving the change works>

## Risks / Follow-up
<anything that needs human attention>
```
