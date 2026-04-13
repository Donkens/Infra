# Codex Task Templates & Reference

> Reference-only examples for infrastructure repositories, scripting, and automation.
> Live Codex Instructions and repo-local `AGENTS.md` are authoritative.
> Optional handoff material in this file is secondary and does not define Codex policy.

---

## PART 1 — Authority Note

This file is examples only.
Do not paste a replacement system prompt from here.
If anything in this file conflicts with live Codex Instructions or repo-local
`AGENTS.md`, `AGENTS.md` wins.

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

### Template D — Optional External Handoff

Use only when another agent or reviewer has already produced a plan.

```
[HANDOFF]
Task ID: <id>
Type: <script | config-edit | refactor | debug>

Architecture decision (already made, do not redesign):
<decision here>

Approved plan:
<Step-by-step approved plan>

Files in scope:
<explicit list>

Execute the plan. Report back using:
TASK: <id>
STATUS: DONE | PARTIAL | BLOCKED
SUMMARY: <1-2 lines, Swedish>
CHANGED: <files>
EVIDENCE: <key verification output>
ISSUES: <anything unexpected, if any>
NEXT: <one concrete next step>
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

## PART 3 — Optional External-Planner Workflow (reference only)

```
User request
     │
     ▼
┌─────────────┐
│  Planner /  │  ← Optional planning, architecture, approval gates
│  Reviewer   │
│  Phase 0/1  │    Produces handoff or approval context
└──────┬──────┘
       │  [User approves]
       ▼
┌─────────────┐
│    CODEX    │  ← Execution only
│  Phase 2    │    Executes approved plan
│             │    Reports concise STATUS/SUMMARY/CHANGED/EVIDENCE/NEXT
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Planner /  │  ← Optional verification or synthesis
│  Reviewer   │
└─────────────┘
```

Codex escalates back to the planner/reviewer when:
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
