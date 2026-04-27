# Agent Host Verification Runbook

> Purpose: Prevent agents from operating on the wrong host, user, or repo.
> See `inventory/identity-map.md` for the canonical host table.
> See `AGENTS.md § HOST VERIFICATION` for the policy rules.

## Why This Exists

This infrastructure spans multiple hosts with **different local usernames and repo paths**:

- MacBook Pro: user `hd`, home `/Users/hd`, brew `/usr/local`
- Mac mini: user `yasse`, home `/Users/yasse`, brew `/opt/homebrew`
- Pi: user `pi`, home `/home/pi`, repo path lowercase `/home/pi/repos/infra`
- UDR-7: user `root`, hostname `udrhomelan`

An agent running in a workspace/sandbox sees a **mounted** copy of a repo — that path is not the target host. Without explicit verification, writes can land on the wrong machine.

## How to Verify the Current Host

Run these before any audit or write:

```bash
hostname          # must match inventory
whoami            # must match inventory SSH/local user
id                # confirm uid/groups
echo "$HOME"      # must match inventory home path
uname -a          # confirm arch and OS
```

Then read the local identity file if present:

```bash
cat ~/.machine-identity 2>/dev/null || echo "no identity file"
```

Cross-check all values against `inventory/identity-map.md`. If anything conflicts — **stop and report**.

## How to Verify a Remote Host

```bash
ssh <alias> 'hostname; whoami; id; echo "$HOME"; uname -a; cat ~/.machine-identity 2>/dev/null'
```

SSH aliases defined in `AGENTS.md § INFRA DEFAULTS`:
- `ssh mini` → Mac mini (user: `yasse`)
- `ssh pi` → Raspberry Pi (user: `pi`)
- `ssh udr` → UDR-7 (user: `root`)

## What to Do on Mismatch

If `~/.machine-identity` conflicts with `inventory/identity-map.md`:

1. **Stop immediately** — do not proceed with any write.
2. Report the exact mismatch: what the file says vs. what live commands return.
3. Wait for operator review before continuing.

The identity file may be stale (e.g., hardware replaced, hostname changed). Update `inventory/identity-map.md` and the local file after operator confirms the correct state.

## Common Pitfalls

| Pitfall | Why it matters |
|---|---|
| Workspace/sandbox path ≠ target host | Claude sandbox mounts the repo but runs on Linux, not the Mac |
| `/Users/hd` alone does not prove MacBook | Always verify `hostname` too |
| `/Users/yasse` alone does not prove Mac mini | Always verify `hostname` too |
| iCloud symlinks appear on multiple Macs | A script path under iCloud does not identify the host |
| UDR SSH user is `root`, not `ubnt` | Using `ubnt` will fail |
| UDR hostname is `udrhomelan` | DNS alias `udr.home.lan` resolves correctly but `hostname` returns `udrhomelan` |
| Pi repo is **lowercase** `/home/pi/repos/infra` | Not `Infra` — scripts and paths must use exact case |
| Mac mini and MacBook share the same GitHub remote | Confirm local identity before repo writes |
| Mac mini is on macOS beta | Behavior may differ from stable; note in audit reports |
