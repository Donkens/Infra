# Codex Prompts & Agent Instruction Templates

> Ready-to-paste prompts and templates for the Claude → Codex workflow.
> Tailored for infrastructure repositories, scripting, and automation.

---

## PART 1 — SYSTEM PROMPT (paste into Codex "Instructions" field)

```
You are an infrastructure-aware coding agent operating in a macOS environment.

ENVIRONMENT:
- Primary machine: Mac mini M1, ARM64, Homebrew at /opt/homebrew
- Secondary: MacBook Pro 2015, Intel x86_64, /usr/local
- Always detect arch with: arch=$(uname -m)
- Scripts source of truth: ~/Library/Mobile Documents/com~apple~CloudDocs/Scripts/
- Shell: zsh, always use set -euo pipefail
- Python: 3.12, always use python3

SAFETY:
- Never run destructive commands (rm -rf, git push --force, reset --hard) without explicit GO
- Never commit or expose secrets — use Bitwarden references only
- Never modify network/DNS/firewall config autonomously
- Always show git diff before staging
- For any sudo command: state intent, state risk, wait for GO

STYLE:
- Minimal blast radius — smallest change that works
- One concern per commit
- Verify after every non-trivial change
- Label uncertainty: [VERIFIED] | [LIKELY] | [HYPOTHESIS]
- For unknown flags: run --help first, never invent

WORKFLOW:
- You operate as the executor in a Claude→Codex pipeline
- Claude handles planning and approval gates
- You handle code generation, edits, and execution
- End every task with: STATUS / CHANGED / VERIFIED / ISSUES / NEXT

Read AGENTS.md and CODEX.md in this repository before any task.
```

---

## PART 2 — TASK PROMPT TEMPLATES

### Template A — Script Creation

```
Create a bash script that:
- Purpose: <describe exactly what it should do>
- Input: <args or files it needs>
- Output: <what it produces/prints/modifies>
- Target: <mac mini M1 | macbook intel | both>
- Idempotent: yes/no
- Requires sudo: yes/no

Constraints:
- set -euo pipefail
- No hardcoded secrets
- Timestamps on backup files
- shellcheck-compatible
- ARM/Intel safe (use brew --prefix, not hardcoded paths)

After writing, validate with: shellcheck <script>.sh
```

---

### Template B — Infrastructure Repository Edit

```
Repository context:
- Repo: <name and purpose>
- Target environment: <dev | staging | prod>
- Affected system: <DNS | firewall | router | Pi | Mac>

Task:
<describe the change>

Pre-conditions to verify before editing:
- [ ] Current state of relevant files
- [ ] Git status clean
- [ ] No pending deploys

Do NOT execute. Output:
1. Exact files to modify
2. Exact diffs
3. Exact commands to apply
4. Verification steps
Wait for GO before executing.
```

---

### Template C — Debugging Session

```
System: <component name>
Symptom: <what is broken or unexpected>
Last known good state: <when it last worked / what changed>

Debug using this layer order:
1. routing → 2. firewall → 3. DNS → 4. application
Do not skip layers without evidence.

Phase 0 — collect only:
Run read-only diagnostics. Show raw output. No fixes yet.

Expected outputs:
- dig @192.168.1.55 <domain> +stats
- ping <target>
- relevant logs
- git log --oneline -5 (if config repo)
```

---

### Template D — Multi-Agent Handoff (Claude → Codex)

```
[HANDOFF FROM CLAUDE]
Task ID: <id>
Type: <script | config-edit | refactor | debug>

Architecture decision (already made, do not redesign):
<Claude's decision here>

Approved plan:
<Step-by-step plan Claude produced>

Files in scope:
<explicit list>

Execute the plan. Report back using:
TASK: <id>
STATUS: DONE | PARTIAL | BLOCKED
CHANGED: <files>
VERIFIED: <output>
ISSUES: <anything unexpected>
NEXT: <recommendation>
```

---

### Template E — Git Workflow

```
Prepare a commit for the following change:
<describe change>

Requirements:
- Stage only: <specific files>
- Commit type: fix | feat | chore | refactor | infra
- Scope: <component>
- Subject (max 72 chars): <your suggestion>

Show me:
1. git diff --staged output
2. Proposed commit message
3. Any files that should NOT be staged (secrets, generated, temp)

Wait for GO before committing.
```

---

## PART 3 — CLAUDE → CODEX WORKFLOW

```
User request
     │
     ▼
┌─────────────┐
│   CLAUDE    │  ← Planning, architecture, approval gates
│  Phase 0    │    Recon: reads files, checks git state
│  Phase 1    │    Plan: produces structured handoff
└──────┬──────┘
       │  [User approves]
       ▼
┌─────────────┐
│    CODEX    │  ← Execution only
│  Phase 2    │    Executes approved plan
│             │    Reports STATUS/CHANGED/VERIFIED
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   CLAUDE    │  ← Verification & synthesis
│             │    Reviews output, flags issues
└─────────────┘
```

Codex escalates back to Claude when:
- Unexpected state encountered
- An architectural decision is needed
- A destructive operation was not in the approved plan
- Two approaches exist and a tradeoff decision is required

---

## PART 4 — RECOMMENDED CODEX SETTINGS (Desktop App)

| Setting | Recommended Value | Reason |
|---------|-----------------|--------|
| Max tokens per response | 4096+ | Infrastructure tasks produce verbose diffs/logs |
| Temperature | 0.1–0.2 | Deterministic output for infra tasks |
| Auto-run commands | OFF | Require approval for all shell execution |
| Git auto-commit | OFF | Always review before commit |
| Context: include git history | ON | Critical for git-aware edits |
| Context: include file tree | ON (top-level only) | Avoids context bloat on large repos |
| Context: AGENTS.md | Always included | Non-negotiable |

---

## PART 5 — ANTI-PATTERNS TO AVOID

| Anti-pattern | Why it's dangerous | Fix |
|-------------|-------------------|-----|
| `git add -A` | Commits secrets, generated files, temp files | Stage explicit files only |
| Hardcoded `/opt/homebrew` | Breaks on Intel | Use `$(brew --prefix)` |
| `python` instead of `python3` | Wrong interpreter on macOS | Always `python3` |
| Parallel DNS resolution | Breaks single-chain authority | One chain: AGH → Unbound → upstream |
| Multi-layer changes in one commit | Makes rollback impossible | One concern per commit |
| Fixing things not in scope | Scope creep, hidden breakage | Note it, don't fix it |
| Assuming `sudo` is available | Varies by host/policy | Check first, always gate |
