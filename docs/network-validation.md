# Network validation

> Read-only validation commands for DNS, UniFi, and repo state.

Do not run write commands, service restarts, package installs, provisioning, or cleanup from this checklist.

## Pi DNS health

```bash
ssh pi 'hostname; ip -brief addr; ip route'
ssh pi 'systemctl is-active AdGuardHome || true; systemctl is-active unbound || true'
ssh pi 'ss -tulpn 2>/dev/null | grep -E "(:53|:443|:3000|:5335|:853)\b" || true'
```

## Unbound recursion

```bash
ssh pi 'dig @127.0.0.1 -p 5335 cloudflare.com A +short +time=2 +tries=1'
ssh pi 'dig @127.0.0.1 -p 5335 cloudflare.com AAAA +short +time=2 +tries=1'
```

## AdGuard LAN DNS

```bash
ssh pi 'dig @192.168.1.55 pi.home.lan A +short +time=2 +tries=1'
ssh pi 'dig @192.168.1.55 adguard.home.lan A +short +time=2 +tries=1'
ssh pi 'dig @192.168.1.55 macmini.home.lan A +short +time=2 +tries=1'
ssh pi 'dig @192.168.1.55 -x 192.168.1.55 +short +time=2 +tries=1'
```

## Mac client resolver check

Run from a normal LAN/MLO client, not only from Pi.

```bash
scutil --dns | grep -E 'nameserver\[[0-9]+\]|search domain\[[0-9]+\]'
route -n get default
ifconfig en0 | grep -E 'inet |inet6 fd12|status'
```

Expected Default/MLO client DNS: `192.168.1.55` and, where IPv6 resolver delivery is active, `fd12:3456:7801::55`.

## DNS bypass check

Run from ordinary clients. Do not use Pi as the only bypass test, because Pi is intentionally allowed to query upstream DNS.

```bash
dig @192.168.1.55 pi.home.lan A +short +time=2 +tries=1
dig @192.168.1.1 pi.home.lan A +short +time=2 +tries=1 || true
dig @1.1.1.1 cloudflare.com A +short +time=2 +tries=1 || true
```

Expected on Default/MLO clients when bypass blocking works:

- `@192.168.1.55` answers.
- `@192.168.1.1` times out.
- `@1.1.1.1` times out.

Expected on Pi:

- `@1.1.1.1` may answer because Pi DNS upstream is explicitly allowed.

## UDR dnsmasq listener observation

```bash
ssh udr 'ss -tulpn 2>/dev/null | grep -E "(:53)\b" || true'
```

UDR listening on gateway DNS is not by itself a failure. Client firewall behavior determines whether it is reachable as a bypass path.

## Proxmox VLAN 30 guest path

Use a temporary guest, not a persistent workload. The 2026-05-02 validation used
LXC CT `900` named `tmp-vlan30-test`, attached to `vmbr0` with VLAN tag `30` and
temporary IP `192.168.30.250/24`. The CT was destroyed after validation.

Read-only checks before creating a temporary test guest:

```bash
ssh -i ~/.ssh/id_ed25519_mbp -o IdentitiesOnly=yes root@192.168.1.60 'qm status 900 || true; pct status 900 || true'
ssh -i ~/.ssh/id_ed25519_mbp -o IdentitiesOnly=yes root@192.168.1.60 'grep -E "iface vmbr0|bridge-vlan-aware yes|bridge-vids 2-4094" /etc/network/interfaces; bridge vlan show dev nic0 | sed -n "1,90p"; pvesm status'
```

Expected temporary guest validation:

```bash
pct exec 900 -- ip -br addr
pct exec 900 -- ip route
pct exec 900 -- ping -c 3 192.168.30.1
pct exec 900 -- ping -c 3 192.168.1.55
pct exec 900 -- ping -c 3 1.1.1.1 || true
pct exec 900 -- getent hosts pi.home.lan || true
```

Cleanup requirement:

```bash
pct stop 900 || true
pct destroy 900 --purge || pct destroy 900 || true
pct status 900 || true
```

## HAOS VM 101 VLAN 30 runtime

Validated on 2026-05-02 after manual UniFi DHCP reservation for HAOS VM `101`.
The full VM MAC is not tracked in Git; `inventory/dhcp-reservations.md` stores a
masked value.

Expected live state:

- VM `101` named `haos` is running on `opti.home.lan`.
- HAOS uses Server VLAN 30 via `net0: virtio,bridge=vmbr0,tag=30`.
- HAOS receives `192.168.30.20/24`.
- Gateway is `192.168.30.1`.
- DNS is Pi `192.168.1.55`.
- `ha.home.lan` and `haos.home.lan` resolve to `192.168.30.20`.

Read-only validation:

```bash
ssh -i ~/.ssh/id_ed25519_mbp -o IdentitiesOnly=yes root@192.168.1.60 'qm status 101; qm agent 101 ping || true; qm guest cmd 101 network-get-interfaces || true'
ssh -i ~/.ssh/id_ed25519_mbp -o IdentitiesOnly=yes root@192.168.1.60 'ping -c 3 192.168.30.20; curl -I --connect-timeout 8 http://192.168.30.20:8123 || true'
dig +short @192.168.1.55 ha.home.lan A
dig +short @192.168.1.55 haos.home.lan A
```

## HAOS VM 101 backup and resolution baseline

Validated on 2026-05-02 through Proxmox QEMU guest agent only. Do not inspect
backup contents during routine validation.

Expected backup metadata:

| Field | Value |
| --- | --- |
| Name | `haos-onboarding-baseline-2026-05-02-full` |
| Date | `2026-05-02T21:50:45.400045+00:00` |
| Type | `full` |
| Protected | `false` |
| Size | `0.12 MB` |

Expected resolution state after `ha resolution check run backups`:

- `issues: []`
- `suggestions: []`
- `unhealthy: []`
- `unsupported: []`

Read-only validation:

```bash
ssh -i ~/.ssh/id_ed25519_mbp -o IdentitiesOnly=yes root@192.168.1.60 'qm guest exec 101 -- ha backups || true'
ssh -i ~/.ssh/id_ed25519_mbp -o IdentitiesOnly=yes root@192.168.1.60 'qm guest exec 101 -- ha resolution info || true'
ssh -i ~/.ssh/id_ed25519_mbp -o IdentitiesOnly=yes root@192.168.1.60 'qm guest exec 101 -- ha supervisor info || true'
```

Notes:

- Older partial backups may still exist.
- Core was not restarted, Supervisor was not reloaded/restarted, and the host was
  not rebooted while clearing the stale backup repair.
- `Advanced SSH & Web Terminal` may require separate follow-up if it remains in
  `state: error`; it is not required for backup verification.

## Git repo state

```bash
ssh pi 'cd /home/pi/repos/infra && git status --short --branch && git log --oneline -5'
```
