#!/usr/bin/env bash
# infra-auto-sync-install.sh
# Kör med: sudo bash /home/pi/repos/infra/scripts/install/infra-auto-sync-install.sh
set -euo pipefail

REPO="/home/pi/repos/infra"
BACKUP_SCRIPT="$REPO/scripts/backup/backup-dns-configs.sh"

echo "[1/5] Installerar sudoers-regel..."
printf 'pi ALL=(root) NOPASSWD: %s --export-repo\n' "$BACKUP_SCRIPT" \
  > /tmp/infra-backup-sudoers
visudo -c -f /tmp/infra-backup-sudoers
cp /tmp/infra-backup-sudoers /etc/sudoers.d/infra-backup
chmod 440 /etc/sudoers.d/infra-backup
echo "      OK: /etc/sudoers.d/infra-backup"

echo "[2/5] Installerar /usr/local/bin/infra-auto-sync.sh..."
cp "$REPO/scripts/install/infra-auto-sync.sh" /usr/local/bin/infra-auto-sync.sh
chown root:root /usr/local/bin/infra-auto-sync.sh
chmod 755 /usr/local/bin/infra-auto-sync.sh
echo "      OK: /usr/local/bin/infra-auto-sync.sh"

echo "[3/5] Installerar systemd units..."
cp "$REPO/systemd/units/infra-auto-sync.service" /etc/systemd/system/
cp "$REPO/systemd/timers/infra-auto-sync.timer"  /etc/systemd/system/
echo "      OK: service + timer"

echo "[4/5] Laddar om systemd och aktiverar timer..."
systemctl daemon-reload
systemctl enable --now infra-auto-sync.timer
echo "      OK: timer aktiverad"

echo "[5/5] Verifierar..."
systemctl list-timers | grep infra-auto-sync
echo ""
echo "Klar! Kör manuellt test med:"
echo "  sudo systemctl start infra-auto-sync.service"
echo "  journalctl -t infra-auto-sync -n 50 --no-pager"
