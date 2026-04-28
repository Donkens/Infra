# Runbook: verify backup-health automatic timer

> Read-only verification runbook. No writes, no service changes.

## Background

`backup-health.service` manual one-shot passed at 2026-04-28 21:20:43.
The automatic timer is scheduled to fire on its next interval after **2026-04-29 09:20:43**.
This runbook verifies that the automatic run completed successfully.

## Rules

- No `sudo`
- No `systemctl start/restart/reload`
- No `daemon-reload`
- No repo changes during this runbook

## Verification commands

```bash
# 1. Confirm identity and time
ssh pi 'hostname; whoami; date -Is'

# 2. Confirm repo is clean
ssh pi 'cd /home/pi/repos/infra && git status --short --branch && git log --oneline -3'

# 3. Check timer state
ssh pi 'systemctl status backup-health.timer --no-pager -l || true'

# 4. Check service state
ssh pi 'systemctl status backup-health.service --no-pager -l || true'

# 5. Check journal since manual one-shot baseline
ssh pi 'journalctl -u backup-health.service --since "2026-04-28 21:20:00" --no-pager || true'

# 6. Check state file
ssh pi 'cd /home/pi/repos/infra && echo "--- backup-health.last"; tail -n 8 state/backup-health.last 2>/dev/null || echo missing'

# 7. Check fail log
ssh pi 'cd /home/pi/repos/infra && echo "--- backup-health-fail.log"; tail -n 20 logs/backup-health-fail.log 2>/dev/null || echo missing'

# 8. Confirm hardening directives are present in live unit
ssh pi 'systemctl cat backup-health.service --no-pager | grep -E "NoNewPrivileges|ProtectSystem|ProtectHome|PrivateTmp|ReadWritePaths|TimeoutStartSec"'
```

## Expected PASS criteria

- Timer ran after `2026-04-28 21:20:43`
- `state/backup-health.last` contains `status=OK` with a timestamp after the baseline
- No new entries in `logs/backup-health-fail.log` after 2026-04-28 21:20:43
- All six hardening directives visible in `systemctl cat` output

## Verdict

| Result | Meaning |
|---|---|
| **PASS** | All criteria met; automatic timer verified. |
| **PENDING** | Timer has not fired yet — check back after 2026-04-29 09:20:43. |
| **NEEDS REVIEW** | Timer fired but state or fail-log indicates a problem; escalate before next run. |

## Related

- [docs/health-rollout-2026-04-28.md](../docs/health-rollout-2026-04-28.md)
- [docs/automation.md](../docs/automation.md)
- [docs/raspberry-pi-baseline.md](../docs/raspberry-pi-baseline.md)
