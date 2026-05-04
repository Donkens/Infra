# Proxmox firewall review — opti

Date: 2026-05-03

## Status

Phase 2A completed 2026-05-03 — review and design. No live changes were made in
Phase 2A. **Phase 2B applied 2026-05-03:** `host.fw` and `cluster.fw` written,
`pve-firewall` reloaded. Host firewall is now active with the approved allowlist.
See Phase 2B section below for full details.

## PVE firewall current state

| Field | Value |
| --- | --- |
| `pve-firewall` service | `active (running)` since 2026-05-02 16:38:10 CEST |
| `pve-firewall` enabled | `enabled` (preset: enabled) |
| `.fw` files under `/etc/pve` | **none** — no rules loaded (Phase 2A baseline) |
| `cluster.fw` | did not exist — **created Phase 2B** |
| `host.fw` | did not exist — **created Phase 2B** |
| `datacenter.cfg` firewall setting | none — only `keyboard: sv` |
| Effective firewall (Phase 2A) | **passthrough** — service ran but enforced nothing |
| Effective firewall (Phase 2B) | **active** — allowlist rules enforced |

The PVE firewall daemon is running and managing iptables/ebtables chains, but
because no `.fw` files exist, its default policy is accept-all. All traffic
passes freely.

## Current listeners on opti

| Port | Proto | Bind | Service | Exposure | Risk |
| --- | --- | --- | --- | --- | --- |
| `22` | TCP | `0.0.0.0` + `[::]` | sshd | Default LAN | ✅ Hardened: key-only, `prohibit-password` |
| `111` | TCP+UDP | `0.0.0.0` + `[::]` | rpcbind (portmapper) | Default LAN | ⚠️ Unnecessarily exposed — see rpcbind audit |
| `8006` | TCP | `*` | pveproxy (Web UI/API) | Default LAN | Management; trusted LAN access acceptable |
| `3128` | TCP | `*` | spiceproxy | Default LAN | SPICE console; management use only |
| `25` | TCP | `127.0.0.1` | postfix | localhost only | ✅ OK |
| `85` | TCP | `127.0.0.1` | pvedaemon | localhost only | ✅ OK |
| `323` | UDP | `127.0.0.1` + `::1` | chronyd | localhost only | ✅ OK |

**Practical exposure note:** `opti` has a single physical interface (`nic0 →
vmbr0`) on `192.168.1.60/24`. All `0.0.0.0`/`*` bindings are reachable only
from Default LAN (`192.168.1.0/24`) and localhost. HAOS VM VLAN 30 traffic
flows through the bridge tap interface (`tap101i0`) and is not routed back to
the Proxmox host management stack without an explicit IP route.

## Network state

| Interface | Address | Role |
| --- | --- | --- |
| `lo` | `127.0.0.1/8`, `::1` | Loopback |
| `nic0` | (unaddressed) | Physical uplink |
| `vmbr0` | `192.168.1.60/24` | Management bridge |
| `tap101i0` | (bridge member) | HAOS VM VLAN 30 tap |

Route: `default via 192.168.1.1 dev vmbr0`. Only one routing domain for the
host itself.

## rpcbind audit

### What was found

| Field | Value |
| --- | --- |
| `rpcbind.service` | `active (running)` |
| `rpcbind.socket` | `active (running)` — socket-activated, triggers service |
| Listening | `0.0.0.0:111` TCP+UDP, `[::]:111` TCP+UDP |
| `rpcinfo -p` | Only `portmapper` v2/v3/v4 registered — no NFS server registered |
| Reverse deps (service) | `multi-user.target` only |
| Reverse deps (socket) | `rpcbind.service`, `sockets.target` |

### Installed NFS-related packages

| Package | Status |
| --- | --- |
| `nfs-common 1:2.8.3-1` | ✅ installed — NFS client support |
| `rpcbind 1.2.7-1` | ✅ installed |
| `libnfsidmap1` | ✅ installed |
| `nfs-kernel-server` | not installed |

### Active NFS-related units

| Unit | State | Notes |
| --- | --- | --- |
| `nfs-blkmap.service` | **active (running)** | pNFS block layout mapping daemon |
| `rpc-statd-notify.service` | active (exited) | Notified NFS peers at boot |
| `nfs-client.target` | enabled in `multi-user.target` | Brings up NFS client stack |
| `rpc-gssd.service` | inactive | GSS/Kerberos for NFS — not active |
| `nfs-utils.service` | inactive | NFS utilities — not active |
| `nfs-kernel-server` | not-found | NFS server not installed |

### rpcbind disable verdict

> **⚠️ NOT safe to disable without further work.**

`nfs-blkmap.service` is **actively running** and is part of the NFS client
stack (`nfs-client.target` enabled). Proxmox VE installs `nfs-common` to
support NFS storage targets. Disabling `rpcbind` would break NFS storage
functionality, even though no NFS storage is currently configured.

The safer mitigations, in order of preference:

1. **PVE host firewall** — block inbound port 111 from the network in
   `host.fw`; rpcbind continues to function for local NFS client services.
2. **rpcbind localhost-only binding** — edit `/etc/default/rpcbind` to add
   `-h 127.0.0.1` flag, preventing the service from listening on `0.0.0.0`.
   Requires testing that local NFS client services still function.
3. **Disable rpcbind** — only safe if `nfs-common` is removed or all NFS
   client units are explicitly stopped and masked. Not recommended without
   a dedicated analysis pass.

**Recommendation for now:** mitigate via PVE host firewall rule (block port 111
inbound) in Phase 2B, keep rpcbind running.

## Allowlist strategy

### Admin source IPs

| Device | IP(s) | VLAN |
| --- | --- | --- |
| Mac mini (Ethernet) | `192.168.1.86` | Default LAN |
| Mac mini (WiFi) | `192.168.1.84` | Default LAN |
| MacBook | `192.168.1.78` | Default LAN |
| Management subnet | `192.168.1.0/24` | Default LAN |

### Option A — Subnet allowlist `192.168.1.0/24` ✅ Recommended

Allow entire Default LAN subnet.

**Pros:** Simple; no lockout risk from DHCP IP changes; covers future admin
devices without config edits; Default LAN is a trusted zone behind UDR-7.

**Cons:** Any Default LAN device could reach Proxmox UI/SSH (acceptable in a
home lab where Default LAN is controlled).

### Option B — Strict per-IP allowlist

Allow only `192.168.1.78`, `192.168.1.84`, `192.168.1.86`.

**Pros:** Tighter — only named admin devices can connect.

**Cons:** DHCP drift or a new device requires a config edit; higher lockout
risk; DHCP reservations for all admin clients must be fully documented first.

**Verdict: Use Option A now.** Move to Option B in a later pass once DHCP
reservations for all admin devices are confirmed static in UniFi and documented
in `inventory/dhcp-reservations.md`.

## Draft host.fw — NOT APPLIED

The following is a **conceptual draft only**. It has not been written to
`/etc/pve/nodes/opti/host.fw` and the PVE firewall has not been enabled.

Syntax must be verified against Proxmox VE 9.x documentation before live
application in Phase 2B.

```
# /etc/pve/nodes/opti/host.fw
# DRAFT — NOT APPLIED — requires Phase 2B approval
# Proxmox VE 9.x host firewall syntax

[OPTIONS]
enable: 1

[RULES]
# SSH from trusted Default LAN
IN ACCEPT -source 192.168.1.0/24 -p tcp -dport 22 -log nolog
# Proxmox Web UI / API from trusted Default LAN
IN ACCEPT -source 192.168.1.0/24 -p tcp -dport 8006 -log nolog
# SPICE proxy from trusted Default LAN
IN ACCEPT -source 192.168.1.0/24 -p tcp -dport 3128 -log nolog
# ICMP from trusted Default LAN (ping, diagnostics)
IN ACCEPT -source 192.168.1.0/24 -p icmp -log nolog
# Drop all other inbound to host
IN DROP -log nolog
```

### Important notes for Phase 2B

- PVE firewall connection tracking handles `ESTABLISHED,RELATED` automatically —
  no explicit rule needed.
- These rules apply to the **host** only — not to VM/CT traffic flowing through
  the bridge. VM firewall is separate.
- rpcbind port 111: explicitly not in the allowlist above — this drops inbound
  port 111 connections from the network. rpcbind continues to function locally.
- `cluster.fw` does not need to exist for host-level firewall to work in a
  single-node cluster. Only `host.fw` with `enable: 1` is required.
- Verify `pve-firewall` syntax with `pve-firewall compile` or by checking
  `/var/lib/pve-firewall/` after writing the file (before enabling).
- Keep Proxmox Web UI console (noVNC) open as fallback during enablement.

## Rollback procedure for Phase 2B

If PVE host firewall is enabled and causes lockout:

```bash
# Via Proxmox Web UI → opti → Shell:
rm /etc/pve/nodes/opti/host.fw
systemctl reload pve-firewall

# Or via an open SSH session:
ssh opti 'rm /etc/pve/nodes/opti/host.fw && systemctl reload pve-firewall'
```

The PVE firewall reverts to passthrough (accept-all) as soon as `host.fw` is
removed and the daemon is reloaded.

## Confirmed no live changes (Phase 2A)

No firewall rules were written, no rpcbind changes were made, no network
configuration was altered in Phase 2A. Phase 2B live changes are recorded below.

---

## Phase 2B — Host firewall applied (2026-05-03)

### Files written

`/etc/pve/firewall/cluster.fw`:

```
[OPTIONS]
enable: 1
```

`/etc/pve/nodes/opti/host.fw` (current — updated Phase 2C 2026-05-04):

```
[OPTIONS]
enable: 1

[RULES]
IN ACCEPT -source 192.168.1.0/24 -p tcp -dport 22 -log nolog
IN ACCEPT -source 192.168.1.0/24 -p tcp -dport 8006 -log nolog
IN ACCEPT -source 192.168.40.0/24 -p tcp -dport 8006 -log nolog
IN ACCEPT -source 192.168.1.0/24 -p tcp -dport 3128 -log nolog
IN ACCEPT -source 192.168.1.0/24 -p icmp -log nolog
IN DROP -log nolog
```

Phase 2B original (before Phase 2C addition):

```
IN ACCEPT -source 192.168.1.0/24 -p tcp -dport 22 -log nolog
IN ACCEPT -source 192.168.1.0/24 -p tcp -dport 8006 -log nolog
IN ACCEPT -source 192.168.1.0/24 -p tcp -dport 3128 -log nolog
IN ACCEPT -source 192.168.1.0/24 -p icmp -log nolog
IN DROP -log nolog
```

Note: `cluster.fw enable: 1` is required to activate the PVE firewall framework.
Without it, `pve-firewall compile` reports `firewall disabled` and `host.fw` is
not applied even with `enable: 1`. Both files are needed.

### compile result

`pve-firewall compile` returned `detected changes` and `PVE_FIREWALL_COMPILE_OK`.
Key compiled rules in `PVEFW-HOST-IN`:

- loopback: ACCEPT
- `INVALID`: DROP (connection tracking)
- `RELATED,ESTABLISHED`: ACCEPT (connection tracking)
- `192.168.1.0/24` → port 22 tcp: ACCEPT
- `192.168.1.0/24` → port 8006 tcp: ACCEPT
- `192.168.1.0/24` → port 3128 tcp: ACCEPT
- `192.168.1.0/24` → ICMP: ACCEPT
- All other inbound: DROP (via `PVEFW-Drop` then `DROP`)

PVE also auto-creates `PVEFW-0-management-v4` ipset with `192.168.1.0/24`,
adding redundant management-port rules for 22, 8006, 3128, 5900–5999 (noVNC),
60000–60050. This is PVE built-in behaviour and does not conflict.

Port 111 (rpcbind) has no ACCEPT rule and hits the final DROP. rpcbind service
continues to run locally and serves NFS client stack; inbound connections from
the network are now dropped at the host firewall.

### Post-reload validation

| Check | Result |
| --- | --- |
| `pve-firewall` status | `enabled/running` |
| New SSH session MBP | ✅ `NEW_SESSION_CURRENT_CLIENT_OK_AFTER_FW` |
| New SSH session Mac mini | ✅ `NEW_SESSION_MINI_OK_AFTER_FW` |
| Proxmox Web UI `https://opti.home.lan:8006` | ✅ HTTP 200 |
| `nc -vz opti.home.lan 22` | ✅ succeeded |
| `nc -vz opti.home.lan 8006` | ✅ succeeded |
| `nc -vz opti.home.lan 3128` | ✅ succeeded |
| rpcbind service | `active` (unchanged — no service changes) |
| VM 101 status | `running` |
| HAOS health | `issues: []`, `suggestions: []`, `unhealthy: []`, `unsupported: []` |

### Rollback

```bash
ssh opti 'rm -f /etc/pve/nodes/opti/host.fw /etc/pve/firewall/cluster.fw && systemctl reload pve-firewall'
```

Removes both files and reverts to passthrough.

---

## Future approval blocks

### ~~[APPROVAL REQUIRED] GO pve-host-firewall-enable Phase 2B~~ COMPLETED 2026-05-03

```
Action:   Write /etc/pve/nodes/opti/host.fw and reload pve-firewall
          to apply the allowlist-based host firewall.

Reason:   PVE firewall currently passes all traffic. Applying host.fw
          blocks inbound connections to ports 22, 8006, 3128, 111 from
          non-Default-LAN sources and drops unexpected inbound traffic
          to the Proxmox host.

Risk:     Medium. A syntax error or missing allowlist entry can lock out
          SSH and Web UI.
          MITIGATED BY:
          - Proxmox Web UI noVNC console as fallback (does not use sshd)
          - Rollback: rm host.fw + systemctl reload pve-firewall
          - Keep one SSH session open during enablement
          - Allowlist covers entire 192.168.1.0/24 — low lockout risk

Rollback: ssh opti 'rm /etc/pve/nodes/opti/host.fw && \
            systemctl reload pve-firewall'
          Or via Proxmox Web UI → Shell.

Requires before GO:
  - Proxmox Web UI (8006) confirmed accessible at time of enablement
  - One open SSH session to opti held during the change
  - host.fw draft reviewed and approved by Yasse
  - Phase 2B: verify with pve-firewall compile before enabling
```

### [APPROVAL REQUIRED] GO rpcbind-restrict Phase 2B

```
Action:   Restrict rpcbind to localhost-only binding via
          /etc/default/rpcbind, preventing it from listening on
          0.0.0.0:111.

Reason:   rpcbind currently exposes port 111 on all interfaces. It
          cannot be disabled (nfs-blkmap.service is actively running),
          but it can be restricted to localhost. This removes the
          network-facing portmapper exposure while keeping NFS client
          services functional.

Risk:     Low-Medium. If rpcbind fails to start after the change,
          nfs-blkmap and related NFS client services will also fail.
          No NFS storage is currently configured, so immediate service
          impact is low. The PVE host firewall (Phase 2B) already
          blocks inbound port 111 from the network, so this is a
          defence-in-depth step, not a critical blocker.

Rollback: Remove the -h 127.0.0.1 flag from /etc/default/rpcbind
          and restart rpcbind:
          systemctl restart rpcbind

Requires before GO:
  - PVE host firewall already blocking port 111 (Phase 2B priority)
  - Verify /etc/default/rpcbind syntax on this Debian/Proxmox version
  - Confirm no NFS storage will be added before test

Note: Disable (not just restrict) rpcbind requires a separate deeper
      analysis of the full NFS client stack and is not recommended
      without first testing localhost-only restriction.
```

### GO server-vlan30-isolation — separate UniFi task

Server VLAN 30 isolation (restricting what HAOS and Docker VM 102 can
reach on Default LAN and other VLANs) is handled via UniFi zone-policy,
not PVE host firewall. This is a separate GO task and is not part of
the Proxmox firewall review.

---

## Phase 2C — MLO VLAN 40 access to Proxmox UI (2026-05-04)

### Root cause

iPhone 17 Pro (`192.168.40.207`, MLO VLAN 40 `192.168.40.0/24`) could not reach
`https://192.168.1.60:8006`. The PVE host firewall applied in Phase 2B allowlisted
only `192.168.1.0/24`; all other sources hit the final `IN DROP`. No UniFi rule
blocked the traffic — MLO VLAN 40 and Default LAN are both in the Internal zone,
so routing and UDR-side policy were not the issue.

### Change

Added one ACCEPT rule to `/etc/pve/nodes/opti/host.fw`:

```
IN ACCEPT -source 192.168.40.0/24 -p tcp -dport 8006 -log nolog
```

Placed after the existing Default LAN 8006 ACCEPT, before the 3128 rule.
MLO subnet gets **port 8006 only** — no SSH, SPICE, or ICMP from VLAN 40.

Backup before edit: `/etc/pve/nodes/opti/host.fw.bak-20260504`.

`pve-firewall compile` confirmed `detected changes` with the new rule present
in `PVEFW-HOST-IN` before reload. `systemctl reload pve-firewall` applied.

### Post-reload validation

| Check | Result |
| --- | --- |
| `nc -vz 192.168.1.60 8006` from Mac mini | ✅ succeeded |
| `nc -vz 192.168.1.60 22` from Mac mini | ✅ succeeded |
| Proxmox Web UI from iPhone `https://192.168.1.60:8006` | ✅ reachable — verified 2026-05-04 |
| Proxmox Web UI from iPhone `https://proxmox.home.lan:8006` | ✅ reachable — verified 2026-05-04 |

### Rollback

```bash
ssh opti 'cp /etc/pve/nodes/opti/host.fw.bak-20260504 /etc/pve/nodes/opti/host.fw && systemctl reload pve-firewall'
```
