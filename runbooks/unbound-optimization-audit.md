# Runbook: Unbound optimization audit

> Read-only performance and stability audit for the Unbound recursive resolver on Pi.
> No writes. No sudo. No service restart or reload. No config changes.

## Purpose

Collect enough data to answer three questions:

1. Is Unbound healthy (no errors, no DNSSEC failures, no request queue pressure)?
2. Is latency acceptable (warm cache ≈ 0 ms, cold recursion ≤ 200 ms median)?
3. Are there any config settings that should be tuned?

## Preconditions

- Pi reachable via `ssh pi`
- `unbound-control` available and working (named-pipe socket at `/run/unbound.ctl`)
- No planned writes during this runbook

## Rules

- No `sudo`
- No `unbound-control reload` or `unbound-control restart`
- No `systemctl restart/reload`
- No edits to `/etc/unbound/` or any live service config
- Read stats with `stats_noreset` only — never `stats` (which resets counters)

---

## Audit commands

### 1. Host and repo verification

```bash
ssh pi 'hostname; whoami; id; echo "$HOME"; uname -a; cat ~/.machine-identity 2>/dev/null || echo "no identity file"'
ssh pi 'cd /home/pi/repos/infra && git status --short --branch && git log --oneline -5 && git rev-parse HEAD'
```

Expected: `hostname=pi`, `whoami=pi`, repo `main`, working tree clean.

### 2. Config syntax check

```bash
ssh pi '/usr/sbin/unbound-checkconf /etc/unbound/unbound.conf'
```

Expected: `no errors in /etc/unbound/unbound.conf`

### 3. Service status

```bash
ssh pi 'systemctl is-active unbound.service; systemctl is-enabled unbound.service'
ssh pi 'systemctl status unbound.service --no-pager -l | tail -20'
```

Expected: `active`, `enabled`, no error lines in status tail.

### 4. Runtime status

```bash
ssh pi 'unbound-control status'
```

Note: version, uptime, threads, modules, control mode.

### 5. Statistics (read-only, no reset)

```bash
ssh pi 'unbound-control stats_noreset | sort'
```

Key counters to extract — see Metrics section below.

### 6. Listener check

```bash
ssh pi 'ss -tulpn 2>/dev/null | grep -E "(:5335)\b" || true'
```

Expected: only `127.0.0.1:5335` (loopback-only). No `0.0.0.0:5335` or external bind.

### 7. Cold latency smoke tests — A records

```bash
ssh pi 'for d in cloudflare.com google.com apple.com github.com openai.com speedtest.net; do
  echo "--- $d A"
  dig @127.0.0.1 -p 5335 "$d" A +stats +time=2 +tries=1 | grep -E "Query time|SERVER|status"
done'
```

### 8. Cold latency smoke tests — AAAA records

```bash
ssh pi 'for d in cloudflare.com google.com apple.com github.com openai.com; do
  echo "--- $d AAAA"
  dig @127.0.0.1 -p 5335 "$d" AAAA +stats +time=2 +tries=1 | grep -E "Query time|status"
done'
```

### 9. Warm-cache comparison (2 lookups per domain)

```bash
ssh pi 'for d in github.com apple.com openai.com cloudflare.com; do
  echo "=== $d warm cache"
  dig @127.0.0.1 -p 5335 "$d" A +stats +time=2 +tries=1 | grep "Query time"
  dig @127.0.0.1 -p 5335 "$d" A +stats +time=2 +tries=1 | grep "Query time"
done'
```

Expected: second lookup at 0 ms.

### 10. AdGuard path vs Unbound direct

```bash
ssh pi 'for d in github.com apple.com cloudflare.com; do
  echo "=== $d via AdGuard"
  dig @192.168.1.55 "$d" A +stats +time=2 +tries=1 | grep "Query time"
  echo "=== $d direct Unbound"
  dig @127.0.0.1 -p 5335 "$d" A +stats +time=2 +tries=1 | grep "Query time"
done'
```

Expected overhead: 0–5 ms for the AdGuard proxy hop.

### 11. Pi resource checks

```bash
ssh pi 'free -h'
ssh pi 'df -h / /boot/firmware'
ssh pi 'vcgencmd measure_temp; vcgencmd get_throttled'
ssh pi 'ps -o pid,user,%cpu,%mem,rss,comm,args -C unbound || true'
```

### 12. Journal — short look

```bash
ssh pi 'journalctl -u unbound.service -n 80 --no-pager | tail -40 || true'
```

Do not print secrets. If logs contain sensitive data, summarise only.

---

## Metrics to interpret

Extract these from `stats_noreset` output:

| Counter | Where to find | Interpretation |
|---|---|---|
| Total queries | `total.num.queries` | Query rate = total / uptime\_seconds |
| Cache hits | `total.num.cachehits` | — |
| Cache misses | `total.num.cachemiss` | — |
| **Hit ratio** | cachehits / (cachehits + cachemiss) | < 10% is normal when AdGuard has its own upstream cache |
| Avg recursion | `total.recursion.time.avg` | In seconds; multiply ×1000 for ms |
| Median recursion | `total.recursion.time.median` | More robust than avg; < 150 ms is good on residential WAN |
| Prefetch count | `total.num.prefetch` | Confirms prefetch: yes is active |
| Expired answers | `total.num.expired` | > 50/day suggests upstream instability |
| Bogus answers | `num.answer.bogus` | Must be 0 — any non-zero is a DNSSEC failure |
| SERVFAIL | `num.answer.rcode.SERVFAIL` | Must be 0 |
| Timed-out queries | `total.num.queries_timed_out` | Must be 0 |
| requestlist pressure | `total.requestlist.exceeded` | > 0 repeatedly = queue overflow risk |
| requestlist max | `total.requestlist.max` | Headroom left before queue overflow |
| TCP ratio | `num.query.tcp` / total queries | > 5% is unusual; indicates large responses or fragmentation |
| Unbound RSS | from `ps` output, RSS column | Expect 25–40 MB on Pi 3B+ |
| Temperature | `vcgencmd measure_temp` | < 60°C is healthy; > 75°C needs attention |
| Throttle | `vcgencmd get_throttled` | `0x0` = never throttled; any other value = investigate |

### Cache hit ratio context

Unbound sits behind AdGuard Home, which has its own 32 MB cache (`optimistic_cache: enabled`).
AdGuard absorbs the bulk of repeated lookups and forwards only genuine misses to Unbound.
Unbound's raw hit ratio therefore reflects only the overflow from AdGuard's cache — values of 5–15% are normal and expected. Do not size Unbound caches based solely on this number.

Current allocation is deliberately conservative:
- `msg-cache-size: 8m` (metadata)
- `rrset-cache-size: 16m` (RR data)

On Pi 3B+ (905 MB total RAM), increasing these beyond 16m/32m provides no measurable benefit unless queries per second exceed ~500/s, which is well above typical home-network load.

### Recursion histogram

`stats_noreset` includes a per-bucket histogram (`histogram.000000.*`). Buckets are in seconds. The distribution shows where cold-recursion time is concentrated. A healthy home-network distribution peaks in the 32–256 ms range for worldwide authoritative servers.

---

## Verdict labels

Use exactly one verdict label per audit run.

| Label | Meaning |
|---|---|
| **PASS** | Healthy, no config change recommended |
| **TUNE CANDIDATE** | One or more settings worth testing in a future task |
| **NEEDS FIX** | Real issue found (SERVFAIL, bogus, queue overflow, etc.) |
| **BLOCKED** | Insufficient access or data to complete the audit |

Record the verdict, date, and uptime at time of audit in the audit report or a dated `docs/` note.

---

## Config settings quick-reference

| Setting | Current value | Notes |
|---|---|---|
| `msg-cache-size` | 8m | Increase only if msg-cache fill > 90% |
| `rrset-cache-size` | 16m | Increase only if rrset-cache fill > 90% |
| `cache-min-ttl` | 300 | Minimum 5 min — reduces upstream chatter |
| `cache-max-ttl` | 86400 | 24 h cap |
| `cache-max-negative-ttl` | 300 | 5 min NXDOMAIN hold |
| `prefetch` | yes | Warm cache before TTL expiry |
| `prefetch-key` | yes | Prefetch DNSSEC keys |
| `aggressive-nsec` | yes | Synthesise NXDOMAIN from NSEC — reduces upstream queries |
| `serve-expired` | yes | Stale-while-revalidate safety net |
| `serve-expired-client-timeout` | 1800 | 1800 ms: "try fresh, fall back to stale". Set to 0 for instant stale (P3 option). |
| `use-caps-for-id` | yes | 0x20 anti-spoofing — monitor SERVFAIL if changed |
| `harden-referral-path` | no | Intentional compatibility setting; avoids extra referral-path validation lookups that can amplify timeout loops against weak or broken delegations. Revisit only if DNSSEC/security posture changes. |
| `do-ip6` | no | Correct for Tele2 IPv4-only WAN |
| `edns-buffer-size` | 1232 | RFC 8085 / RIPE recommendation — do not increase |
| `interface` | 127.0.0.1@5335 | Loopback-only — correct |
| `interface: ::1@5335` | present but inert | No-op: `do-ip6: no` prevents the bind |

---

## Known workarounds in active config

| File | Purpose |
|---|---|
| `31-nih-https-synthetic.conf` | Synthetic HTTPS (TYPE65) records for `nih.gov` family. Auth NS returns TIMEOUT for HTTPS queries; local synthetic avoids SERVFAIL. |
| `forward-dxcloud.conf` | Forward zone `dxcloud.episerver.net` → Cloudflare. Narrow scope workaround for authoritative server issues on that zone. |

---

## Follow-up task template

If audit yields TUNE CANDIDATE or NEEDS FIX, open a new task with:

```
Host: pi
Task type: Unbound config change
Files: /etc/unbound/unbound.conf.d/pi.conf (live) + config/unbound/unbound.conf.d/pi.conf (repo)
Change: <exact setting and new value>
Requires: sudo (live config is root-owned)
Validation: unbound-checkconf → systemctl reload unbound → stats_noreset comparison
Rollback: restore pi.conf.bak from /etc/unbound/unbound.conf.d/
```

---

## Related

- [config/unbound/unbound.conf.d/pi.conf](../config/unbound/unbound.conf.d/pi.conf)
- [docs/raspberry-pi-baseline.md](../docs/raspberry-pi-baseline.md)
- [docs/dns-architecture.md](../docs/dns-architecture.md)
- [runbooks/pi-reboot-validation.md](pi-reboot-validation.md)
- [docs/pi-maintenance-checklist.md](../docs/pi-maintenance-checklist.md)
