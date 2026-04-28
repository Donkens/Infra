# Pi maintenance checklist

> Recurring read-only checklist. No writes, no service restarts.

## Recommended cadence

| When | Scope |
|---|---|
| Weekly (quick) | identity, git status, disk, memory, temp, timers, health states |
| Monthly (deeper) | all weekly checks + throttle, listening ports, DNS smoke tests, fail logs, backup freshness, CI/lint |
| After reboot or update | full checklist below |

## Checklist

### Identity and uptime

```bash
ssh pi 'hostname; whoami; uptime; date -Is'
ssh pi 'cat ~/.machine-identity 2>/dev/null || echo "no identity file"'
```

### Repo state

```bash
ssh pi 'cd /home/pi/repos/infra && git status --short --branch && git log --oneline -3'
```

### Disk and memory

```bash
ssh pi 'df -h / /boot/firmware'
ssh pi 'free -h'
```

### Temperature and throttle

```bash
ssh pi 'vcgencmd measure_temp'
ssh pi 'vcgencmd get_throttled'
```

Expected: `throttled=0x0`. Non-zero values indicate past or current thermal/voltage issues.

### Services active

```bash
ssh pi 'systemctl is-active AdGuardHome.service unbound.service ssh.service'
```

### Listening ports

```bash
ssh pi 'ss -tulpn 2>/dev/null | grep -E ":(53|5335|853|3000|443|22)\b" || true'
```

### DNS smoke tests

```bash
# Unbound direct
ssh pi 'dig @127.0.0.1 -p 5335 cloudflare.com A +short +time=2 +tries=1'

# AdGuard (Pi primary resolver)
ssh pi 'dig @192.168.1.55 pi.home.lan A +short +time=2 +tries=1'
```

### Timer states

```bash
ssh pi 'systemctl status dns-health.timer backup-health.timer infra-auto-sync.timer --no-pager -l || true'
```

### Health state files

```bash
ssh pi 'cd /home/pi/repos/infra && tail -n 5 state/dns-health.last 2>/dev/null || echo missing'
ssh pi 'cd /home/pi/repos/infra && tail -n 5 state/backup-health.last 2>/dev/null || echo missing'
```

### Backup freshness

```bash
ssh pi 'ls -lt /home/pi/repos/infra/state/backups/ 2>/dev/null | head -5 || echo "no backups dir"'
```

### Fail logs (no new entries is expected)

```bash
ssh pi 'cd /home/pi/repos/infra && tail -n 10 logs/dns-health-fail.log 2>/dev/null || echo missing'
ssh pi 'cd /home/pi/repos/infra && tail -n 10 logs/backup-health-fail.log 2>/dev/null || echo missing'
```

### Local CI/lint (if running on Pi)

```bash
ssh pi 'cd /home/pi/repos/infra && bash -n $(git ls-files "*.sh") 2>&1 | head -20 || true'
ssh pi 'cd /home/pi/repos/infra && python3 scripts/ci/check-markdown-links.py 2>&1 | tail -5 || true'
```

## Related

- [docs/raspberry-pi-baseline.md](raspberry-pi-baseline.md)
- [docs/network-validation.md](network-validation.md)
- [docs/automation.md](automation.md)
- [docs/health-rollout-2026-04-28.md](health-rollout-2026-04-28.md)
