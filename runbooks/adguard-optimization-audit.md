# Runbook: AdGuard Home optimization audit

> Read-only performance and stability audit for AdGuard Home on Pi.
> No writes. No sudo. No service restart or reload. No config changes. No API write.

## Purpose

Collect enough data to answer four questions:

1. Is AdGuard Home healthy (no crashes, no SERVFAIL, no error bursts)?
2. Is latency acceptable (warm cache ≈ 0 ms, AdGuard overhead ≤ 5 ms)?
3. Are cache, TTL, and optimistic cache configured well?
4. Are there client policy or filter list improvements worth testing?

## Preconditions

- Pi reachable via `ssh pi`
- `dig` and `curl` available on Pi
- No planned writes during this runbook

## Rules

- No `sudo`
- No AdGuard config change, no YAML edit
- No `systemctl restart/reload` for any service
- No AdGuard API write (`POST`, `PUT`, `DELETE`)
- No raw `AdGuardHome.yaml` dump
- No raw query log, client list, rewrite list, or user rules dump
- If any command requires sudo or risks showing secrets: mark UNKNOWN and stop
- Read API data as safe summaries only; never print credentials, cookies, or tokens

---

## Audit commands

### 1. Host and repo verification

```bash
ssh pi 'hostname; whoami; id; echo "$HOME"; uname -a; cat ~/.machine-identity 2>/dev/null || echo "no identity file"'
ssh pi 'cd /home/pi/repos/infra && git status --short --branch && git log --oneline -5 && git rev-parse HEAD'
```

Expected: `hostname=pi`, `whoami=pi`, repo at `/home/pi/repos/infra`, branch `main`, working tree clean.

### 2. Read repo policy and sanitized config

```bash
ssh pi 'cd /home/pi/repos/infra && sed -n "1,60p" AGENTS.md'
ssh pi 'cd /home/pi/repos/infra && cat config/adguardhome/AdGuardHome.summary.sanitized.yml'
```

Note: `AdGuardHome.summary.sanitized.yml` is the only safe AdGuard config artifact in Git. Do not read raw `AdGuardHome.yaml`.

### 3. Service status and ports

```bash
ssh pi 'systemctl is-active AdGuardHome.service; systemctl is-enabled AdGuardHome.service'
ssh pi 'systemctl status AdGuardHome.service --no-pager -l | head -40'
ssh pi 'systemctl show AdGuardHome.service -p FragmentPath -p ExecStart -p User -p Group -p WorkingDirectory --no-pager'
ssh pi 'ss -tulpn 2>/dev/null | grep -E ":(53|443|853|3000)\b" || true'
```

Expected: `active`, `enabled`. Ports 53/tcp+udp, 443/tcp, 853/tcp+udp, 3000/tcp listening.

### 4. Resource check

```bash
ssh pi 'free -h'
ssh pi 'df -h / /boot/firmware'
ssh pi 'vcgencmd measure_temp; vcgencmd get_throttled'
ssh pi 'ps -o pid,user,%cpu,%mem,rss,comm,args -C AdGuardHome 2>/dev/null || true'
```

Expected: temp ≤ 70°C, `throttled=0x0`, RSS < 300 MB.

### 5. DNS latency — AdGuard vs direct Unbound

```bash
ssh pi 'for d in cloudflare.com google.com apple.com github.com openai.com speedtest.net; do
  echo "=== $d via AdGuard"
  dig @192.168.1.55 "$d" A +stats +time=2 +tries=1 | grep -E "status|Query time|SERVER"
  echo "=== $d direct Unbound"
  dig @127.0.0.1 -p 5335 "$d" A +stats +time=2 +tries=1 | grep -E "status|Query time|SERVER"
done'
```

Expected: warm-cache queries ≤ 3 ms via AdGuard, status `NOERROR` for all.

### 6. Warm-cache repeat behavior

```bash
ssh pi 'for d in github.com apple.com openai.com cloudflare.com; do
  echo "=== $d AdGuard warm cache"
  dig @192.168.1.55 "$d" A +stats +time=2 +tries=1 | grep "Query time"
  dig @192.168.1.55 "$d" A +stats +time=2 +tries=1 | grep "Query time"
done'
```

Expected: repeated queries 0–3 ms; second query ≤ first for cached entries.

### 7. Local names and PTR smoke tests

```bash
ssh pi 'for d in pi.home.lan adguard.home.lan macmini.home.lan macmini-wifi.home.lan mbp.home.lan udr.home.lan router.home.lan unifi.home.lan iphone.home.lan; do
  echo "=== $d"
  dig @192.168.1.55 "$d" A +short +time=2 +tries=1
done'

ssh pi 'for ip in 192.168.1.1 192.168.1.55 192.168.1.78 192.168.1.84 192.168.1.86 192.168.40.207; do
  echo "=== PTR $ip"
  dig @192.168.1.55 -x "$ip" +short +time=2 +tries=1
done'
```

Expected: all names resolve to expected IPs; all PTRs resolve to expected hostnames.

### 8. DoH endpoint smoke test

```bash
ssh pi 'python3 - <<'"'"'PY'"'"'
import http.client, ssl, struct

qname = b"".join(bytes([len(p)]) + p.encode() for p in "cloudflare.com".split(".")) + b"\0"
query = struct.pack("!HHHHHH", 0x1234, 0x0100, 1, 0, 0, 0) + qname + struct.pack("!HH", 1, 1)

ctx = ssl._create_unverified_context()
conn = http.client.HTTPSConnection("adguard.home.lan", 443, context=ctx, timeout=5)
conn.request(
    "POST",
    "/dns-query",
    body=query,
    headers={"content-type": "application/dns-message", "accept": "application/dns-message"},
)
resp = conn.getresponse()
body = resp.read(512)
if len(body) < 12:
    raise SystemExit(f"DoH endpoint: UNKNOWN body_len={len(body)} http={resp.status}")

tid, flags, qd, an, ns, ar = struct.unpack("!HHHHHH", body[:12])
print(f"HTTP: {resp.status} RCODE: {flags & 0x000f} Answers: {an}")
PY'
```

Expected: `HTTP: 200 RCODE: 0 Answers: <n>` (NOERROR). Mark DoH endpoint UNKNOWN if TLS, HTTP, or DNS-wire parsing fails. Do not use JSON-style `GET ?name=...&type=...` as the primary smoke test; this AdGuard endpoint serves RFC8484 DNS-wire requests.

### 9. Safe AdGuard API check

Use only safe summary endpoints. Never print raw clients, rewrites, user rules, or query log.

```bash
ssh pi 'result=$(curl -sk --max-time 2 https://127.0.0.1/control/status 2>/dev/null | head -c 1000)
if echo "$result" | grep -qiE "password|token|cookie|secret|hash"; then
  echo "API: sensitive content — not printing"
elif [ -z "$result" ]; then
  echo "API: no response — auth required or service not reachable"
else
  echo "$result"
fi'
```

If auth is required: mark API metrics UNKNOWN. Do not attempt credential input in the audit.

Safe stats summary (counts only):

```bash
ssh pi 'curl -sk --max-time 2 https://127.0.0.1/control/stats 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); safe={k:v for k,v in d.items() if k in [\"num_dns_queries\",\"num_blocked_dns_queries\",\"avg_processing_time\"]}; print(safe)" \
  2>/dev/null || echo "API stats: UNKNOWN"'
```

### 10. Journal check

```bash
ssh pi 'journalctl -u AdGuardHome.service -n 80 --no-pager \
  | grep -E "error|warn|WARN|ERROR|fail|timeout|SERVFAIL|refused|panic|fatal|start|listen|tls|cert|filter|cache" \
  | head -60 || true'
```

Expected: no SERVFAIL, no panic, no repeated error bursts. Isolated `connection reset by peer` on port 853 is normal for DoT clients that disconnect abruptly.

### 11. Unbound stats (read-only, no reset)

```bash
ssh pi 'unbound-control stats_noreset 2>/dev/null | grep -E "^total\.|^num\.|^time\." | head -40'
```

Key counters: `total.num.queries`, `total.num.cachehits`, `total.num.queries_timed_out`, `total.recursion.time.avg`.

---

## Metrics to interpret

| Metric | Healthy | Concern |
|---|---|---|
| AdGuard service | `active (running)` | Anything else |
| AdGuard RSS | < 300 MB | > 400 MB |
| Pi temperature | ≤ 65°C | > 70°C |
| Pi throttling | `0x0` | Anything else |
| AdGuard warm-cache latency | 0–3 ms | > 10 ms |
| AdGuard vs Unbound overhead | < 5 ms | > 20 ms |
| Unbound timed-out queries | 0 | > 0 |
| Unbound avg recursion time | ≤ 200 ms | > 500 ms |
| Local rewrites | All expected names resolve | NXDOMAIN or wrong IP |
| PTR records | All expected PTRs resolve | Missing or wrong name |
| DoT connection resets | Occasional (1–5/day) | Repeated bursts |
| API stats | Available or UNKNOWN | Sensitive content visible |

---

## Verdict labels

| Verdict | Meaning |
|---|---|
| **PASS** | Healthy, no config change recommended |
| **TUNE CANDIDATE** | Healthy, small tuning or policy worth testing later |
| **NEEDS FIX** | Issue found that requires a change |
| **BLOCKED** | Insufficient access or data to conclude |

---

## Follow-up task template

If audit yields TUNE CANDIDATE or NEEDS FIX, open a new task with:

```
Host: pi
Task type: AdGuard config change
Files: /home/pi/AdGuardHome/AdGuardHome.yaml (live, root-owned) or AdGuard UI
Change: <exact setting and new value>
Requires: YAML workflow (see adguard-home-change-policy.md) or AdGuard UI
Validation: systemctl is-active AdGuardHome.service → ss ports → dig smoke tests
Rollback: restore AdGuardHome.yaml.bak.TIMESTAMP
```

---

## Related docs

- [AdGuard change policy](../docs/adguard-home-change-policy.md)
- [AdGuard client policy](../docs/adguard-home-client-policy.md)
- [AdGuard false-positive allowlist](../docs/adguard-home-false-positive-allowlist.md)
- [Raspberry Pi baseline](../docs/raspberry-pi-baseline.md)
- [DNS architecture](../docs/dns-architecture.md)
- [Unbound optimization audit](unbound-optimization-audit.md)
