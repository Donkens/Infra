# DNS/TLS cleanup baseline — 2026-04-26

## Summary

Five cleanup tasks completed on 2026-04-26 to establish a clean DNS/TLS baseline for the home.lan infrastructure. No functional regressions. All changes verified live from Mac mini.

TaskResultAdGuard DDR disabled✓DNS-bypass firewall policies (Default LAN)✓SSH to UDR non-interactive✓AdGuard AAAA rewrites cleaned✓Leaf-cert reissued with correct SANs✓

---

## 1. AdGuard DDR

**Change:** `handle_ddr: false` in `AdGuardHome.yaml`.

**Reason:** Apple DDR (Discovery of Designated Resolvers) caused TLS friction when AdGuard served a private CA cert. With DDR enabled, Apple clients attempted to upgrade to DoH/DoT using the cert's SAN list, which triggered trust errors for non-Apple-trusted CAs. Disabling DDR stops this negotiation entirely.

**State:** AdGuardHome restarted and active after change.

---

## 2. DNS-bypass firewall — Default LAN

Six new zone-based firewall policies added to UDR-7 to enforce Pi DNS on the Default LAN zone. IoT rules were not touched.

### Active policies

Policy nameIDDirectionProtocol`allow-pi-dns-upstream-to-wan-udp69ee4d011bc6e72d27743fa2`LAN→WANUDP/53`allow-pi-dns-upstream-to-wan-tcp69ee4d011bc6e72d27743fa5`LAN→WANTCP/53`block-internal-gateway-dns-udp69ee4d011bc6e72d27743fa8`LAN internalUDP/53`block-internal-gateway-dns-tcp69ee4d011bc6e72d27743fab`LAN internalTCP/53`block-internal-wan-dns-udp69ee4d011bc6e72d27743fae`LAN→WANUDP/53`block-internal-wan-dns-tcp69ee4d021bc6e72d27743fb1`LAN→WANTCP/53

### Policy ordering rationale

Pi upstream DNS against WAN is explicitly allowed (`allow-pi-dns-upstream-to-wan-*`) before the WAN block rules. This ensures the DNS chain `client → AdGuard (192.168.1.55) → Unbound → upstream` continues to function.

### Verified behaviour

- `dig @192.168.1.55` resolves correctly from Mac mini.
- `dig @192.168.1.1` (gateway) times out — bypass blocked.
- `dig @1.1.1.1` and `dig @8.8.8.8` time out — external bypass blocked.
- Both TCP and UDP verified from Mac mini.

### Removed stale policies

Two previously disabled/broken policies removed during cleanup:

IDReason`69ee12521bc6e72d27742add`Disabled, stale, no kernel presence`69ee12561bc6e72d27742ae1`Disabled, stale, no kernel presence

### Firewall backup paths (Mac mini Desktop)

```
/Users/yasse/Desktop/udr-firewall-backup/unifi-firewall-policies-before-20260426-193258.json
/Users/yasse/Desktop/udr-firewall-backup/unifi-firewall-groups-before-20260426-193258.json
/Users/yasse/Desktop/udr-firewall-backup/unifi-created-firewall-policies-20260426-193559.json
```

---

## 3. SSH baseline — UDR

SSH to UDR-7 now works non-interactively from Mac mini using key `id_ed25519_udr2`.

### SSH config block

Config lives in iCloud (symlinked):

```
~/.ssh/config -> ~/Library/Mobile Documents/com~apple~CloudDocs/Scripts/infra/ssh-config
```

```sshconfig
Host udr udr.home.lan 192.168.1.1
  HostName udr.home.lan
  User root
  IdentityFile ~/.ssh/id_ed25519_udr2
  IdentitiesOnly yes
  AddKeysToAgent yes
  UseKeychain yes
  ForwardAgent yes
```

### Verified aliases

All three aliases resolve identically via `ssh -G` and connect non-interactively in BatchMode:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=5 root@udr.home.lan 'hostname; date'
ssh -o BatchMode=yes -o ConnectTimeout=5 udr.home.lan 'hostname; date'
ssh -o BatchMode=yes -o ConnectTimeout=5 udr 'hostname; date'
```

`iptables-save` read-only access confirmed via SSH.

**SSH config backup:** `~/.ssh/config.bak.20260426-195513`

---

## 4. AdGuard AAAA cleanup

Three AAAA rewrites removed from `AdGuardHome.yaml`. They pointed to `fd12:3456:7801::` — a subnet prefix with no host part. UDR bridge interfaces (`br0`, `br10`, `br40`) carry only prefix addresses (`/64`) and have no stable ULA host address.

### Removed rewrites

```yaml
# Removed — subnet prefix, not a valid host address
- domain: udr.home.lan
  answer: 'fd12:3456:7801::'
- domain: unifi.home.lan
  answer: 'fd12:3456:7801::'
- domain: router.home.lan
  answer: 'fd12:3456:7801::'
```

### Current state — A-only for UDR names

QueryExpected answer`udr.home.lan A192.168.1.1unifi.home.lan A192.168.1.1router.home.lan A192.168.1.1udr.home.lan AAAA`(empty)`unifi.home.lan AAAA`(empty)`router.home.lan AAAA`(empty)

### Verification commands

```bash
dig @192.168.1.55 udr.home.lan A +short
dig @192.168.1.55 udr.home.lan AAAA +short
dig @192.168.1.55 unifi.home.lan A +short
dig @192.168.1.55 unifi.home.lan AAAA +short
dig @192.168.1.55 router.home.lan A +short
dig @192.168.1.55 router.home.lan AAAA +short
```

**AdGuardHome.yaml backup on Pi:** `/home/pi/AdGuardHome/AdGuardHome.yaml.bak.20260426-202721`

---

## 5. Leaf-cert cleanup

### Problem

Previous leaf-cert (serial `...B2`, issued 2025-11-30) contained SAN typo `udr.yasse.lan` instead of `udr.home.lan`. Also missing: `cockpit.home.lan`, `udr.home.lan`, `unifi.home.lan`, `router.home.lan`. The wildcard `*.home.lan`covered all `.home.lan` names functionally, so this was cleanup — not an emergency.

### CA used

```
CA:          Yasse-Root-CA
Fingerprint: 79:06:E8:F8:6B:45:B7:7B:19:B1:FC:20:56:62:4B:45:39:6B:99:44:A9:D9:A2:42:EE:EB:6D:8A:0E:36:A4:1E
Valid:       2025-11-30 → 2035-11-28
CA files:    ~/Library/Mobile Documents/com~apple~CloudDocs/Documents/Certs/rescued-from-backup-20251204/yasse-cert/
```

No root-CA rotation — CA is valid and trusted in Mac mini System.keychain.

### New leaf-cert

```
Serial:  47BBFE4CFB17175A5B930A3B3B0FE043954A52E7
SHA256:  4C:C6:BA:22:CA:93:EE:E8:EB:ED:2C:70:5A:ED:0B:31:B0:16:05:90:9D:93:E3:BD:A6:F8:C5:52:15:78:74:AA
Valid:   2026-04-26 → 2028-07-29  (825 days)
Issuer:  CN=Yasse-Root-CA
```

### SAN list

```
DNS:*.home.lan
DNS:home.lan
DNS:adguard.home.lan
DNS:pi.home.lan
DNS:cockpit.home.lan
DNS:udr.home.lan
DNS:unifi.home.lan
DNS:router.home.lan
IP:192.168.1.55
IP:192.168.1.1
IP:FD12:3456:7801:0:0:0:0:55
```

Removed: `udr.yasse.lan`, `fd12:3456:7801::`, `fd12:3456:7801::1`.

### Cert generation path (MacBook, iCloud)

```
OUT_DIR: ~/Library/Mobile Documents/com~apple~CloudDocs/Documents/Certs/yasse-leaf-v2/
Files:   fullchain.pem  privkey.pem  leaf.crt  leaf.csr  yasse-leaf-v2.cnf  yasse-root-ca.srl
```

### Deploy paths on Pi

ServiceFileOwnerModeAdGuard`/home/pi/AdGuardHome/certs/fullchain.pemroot:root644`AdGuard`/home/pi/AdGuardHome/certs/privkey.pemroot:root600`Cockpit`/etc/cockpit/ws-certs.d/10-yasse-wildcard.certroot:root644`Cockpit`/etc/cockpit/ws-certs.d/10-yasse-wildcard.keyroot:root640`

Note: `cockpit-ws` group does not exist on this Pi. Key owner is `root:root 640`, same as the original. Cockpit starts correctly.

### Pi backups (timestamp `20260426-203845`)

```
/home/pi/AdGuardHome/certs/fullchain.pem.bak.20260426-203845
/home/pi/AdGuardHome/certs/privkey.pem.bak.20260426-203845
/etc/cockpit/ws-certs.d/10-yasse-wildcard.cert.bak.20260426-203845
/etc/cockpit/ws-certs.d/10-yasse-wildcard.key.bak.20260426-203845
```

### Live verification

```bash
# Check serial and expiry
openssl s_client -connect adguard.home.lan:443 -servername adguard.home.lan \
  </dev/null 2>/dev/null | openssl x509 -noout -serial -dates
openssl s_client -connect adguard.home.lan:853 -servername adguard.home.lan \
  </dev/null 2>/dev/null | openssl x509 -noout -serial
openssl s_client -connect pi.home.lan:9090 -servername pi.home.lan \
  </dev/null 2>/dev/null | openssl x509 -noout -serial -dates

curl -Ik https://adguard.home.lan | head -5
curl -Ik https://pi.home.lan:9090 | head -5
```

All three endpoints verified serving new cert (serial `47BBFE...`) after deploy.

### Rollback

```bash
ssh pi@pi.home.lan '
  sudo cp /home/pi/AdGuardHome/certs/fullchain.pem.bak.20260426-203845 \
    /home/pi/AdGuardHome/certs/fullchain.pem
  sudo cp /home/pi/AdGuardHome/certs/privkey.pem.bak.20260426-203845 \
    /home/pi/AdGuardHome/certs/privkey.pem
  sudo systemctl restart AdGuardHome
  sudo cp /etc/cockpit/ws-certs.d/10-yasse-wildcard.cert.bak.20260426-203845 \
    /etc/cockpit/ws-certs.d/10-yasse-wildcard.cert
  sudo cp /etc/cockpit/ws-certs.d/10-yasse-wildcard.key.bak.20260426-203845 \
    /etc/cockpit/ws-certs.d/10-yasse-wildcard.key
  sudo systemctl restart cockpit'
```

---

## Operator checklist — future audit

Run from Mac mini against `192.168.1.55` (Pi DNS).

### DNS baseline

```bash
# A-records — all should return 192.168.1.1
dig @192.168.1.55 udr.home.lan A +short
dig @192.168.1.55 unifi.home.lan A +short
dig @192.168.1.55 router.home.lan A +short

# AAAA-records — all should be empty
dig @192.168.1.55 udr.home.lan AAAA +short
dig @192.168.1.55 unifi.home.lan AAAA +short
dig @192.168.1.55 router.home.lan AAAA +short

# DNS-bypass should time out
dig @192.168.1.1 google.com +timeout=3 || true
dig @1.1.1.1 google.com +timeout=3 || true
```

### TLS baseline

```bash
# Check serial — expected: 47BBFE4CFB17175A5B930A3B3B0FE043954A52E7
openssl s_client -connect adguard.home.lan:443 -servername adguard.home.lan \
  </dev/null 2>/dev/null | openssl x509 -noout -serial -dates
openssl s_client -connect pi.home.lan:9090 -servername pi.home.lan \
  </dev/null 2>/dev/null | openssl x509 -noout -serial -dates

# Confirm udr.yasse.lan is absent from SAN
openssl s_client -connect adguard.home.lan:443 -servername adguard.home.lan \
  </dev/null 2>/dev/null | openssl x509 -noout -text \
  | grep -E "DNS:|IP Address:|yasse.lan"
```

### SSH baseline

```bash
ssh -o BatchMode=yes -o ConnectTimeout=5 udr 'hostname; date'
```

### Service health

```bash
ssh pi@pi.home.lan 'sudo systemctl is-active AdGuardHome unbound cockpit'
```

---

## Next steps (low priority)

- Cert expires **2028-07-29** — no action needed until \~2028-04.
- Consider scripting leaf-cert renewal using `yasse-leaf-v2.cnf` as template.
- Consider moving CA files from iCloud `rescued-from-backup-20251204/` to a cleaner permanent path under `Documents/Certs/pki/`.
- `UDR_TLS_REAL/` in iCloud contains an older separate CA (fingerprint `4F:9C:F5...`) — can be archived or removed when convenient.
