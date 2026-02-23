# Restore Guide (Pi DNS Infra)

Restore-guide för Raspberry Pi 3 (DNS/infra-node) med:

- **AdGuard Home** (installerad under `/home/pi/AdGuardHome`)
- **Unbound** (`/etc/unbound`)
- **Infra-repo** (`/home/pi/repos/infra`)
- systemd health-check timers (`dns-health`, `backup-health`)

---

## 0) Mål

Efter restore ska följande fungera:

- AdGuardHome kör och lyssnar lokalt
- Unbound kör på localhost:5335
- DNS fungerar via AdGuard → Unbound
- `dns-health.sh`, `check-backups.sh`, `infra-status.sh` finns och fungerar
- systemd timers är aktiva
- repo är kopplat till GitHub (`origin`)

---

## 1) Bas-setup på ny Pi

### Uppdatera system
```bash
sudo apt update && sudo apt upgrade -y
```

---

### Installera paket
```bash
sudo apt install -y git unbound dnsutils curl ca-certificates
```
## 2) Klona infra-repo

Skapa repo-katalog
bash
mkdir -p ~/repos
cd ~/repos