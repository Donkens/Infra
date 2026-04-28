# Runbook: Pi reboot validation

> Read-only validation after reboot, kernel update, or package maintenance.
> No writes. No service restarts.

## Preconditions

- Pi is reachable by SSH
- No planned writes during this runbook

## Validation commands

```bash
# 1. Identity and uptime
ssh pi 'hostname; whoami; uptime; date -Is'

# 2. Kernel and OS
ssh pi 'uname -a; cat /etc/os-release'

# 3. Throttle and temperature
ssh pi 'vcgencmd get_throttled; vcgencmd measure_temp'

# 4. Disk space
ssh pi 'df -h / /boot/firmware'

# 5. Memory
ssh pi 'free -h'

# 6. Critical services active
ssh pi 'systemctl is-active AdGuardHome.service unbound.service ssh.service'

# 7. Listening ports
ssh pi 'ss -tulpn 2>/dev/null | grep -E ":(53|5335|853|3000|443|22)\b" || true'

# 8. DNS smoke test — Unbound direct
ssh pi 'dig @127.0.0.1 -p 5335 cloudflare.com A +short +time=2 +tries=1'

# 9. DNS smoke test — AdGuard primary
ssh pi 'dig @192.168.1.55 pi.home.lan A +short +time=2 +tries=1'

# 10. Health state files
ssh pi 'cd /home/pi/repos/infra && tail -n 5 state/dns-health.last 2>/dev/null || true'
ssh pi 'cd /home/pi/repos/infra && tail -n 5 state/backup-health.last 2>/dev/null || true'
```

## Expected results

| Check | Expected |
|---|---|
| `get_throttled` | `throttled=0x0` |
| AdGuardHome | `active` |
| unbound | `active` |
| ssh | `active` |
| DNS smoke tests | non-empty IP answer |
| Disk / | < 85% used |
| No new fail-log entries | no new lines after reboot timestamp |

## Escalation

If a check fails, follow this order before taking any action:

1. Routing — can you reach Pi at all?
2. Firewall — is the relevant port blocked?
3. DNS — is the resolver returning answers?
4. Application — is the service process running?

**No service restart without a separate explicit GO.**

## Related

- [docs/pi-maintenance-checklist.md](../docs/pi-maintenance-checklist.md)
- [docs/raspberry-pi-baseline.md](../docs/raspberry-pi-baseline.md)
- [docs/network-validation.md](../docs/network-validation.md)
- [docs/automation.md](../docs/automation.md)
