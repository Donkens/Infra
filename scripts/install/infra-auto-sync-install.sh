#!/usr/bin/env bash
# infra-auto-sync-install.sh
# Kör med: sudo bash /home/pi/repos/infra/scripts/install/infra-auto-sync-install.sh
set -euo pipefail

REPO="/home/pi/repos/infra"
SOURCE_BACKUP_SCRIPT="$REPO/scripts/backup/backup-dns-configs.sh"
INSTALLED_BACKUP_DIR="/usr/local/lib/infra"
INSTALLED_BACKUP_SCRIPT="$INSTALLED_BACKUP_DIR/backup-dns-configs.sh"
WRAPPER_PATH="/usr/local/sbin/infra-backup-dns-export"
SUDOERS_PATH="/etc/sudoers.d/infra-backup"

echo "[1/8] Installerar root-owned backup script i /usr/local/lib/infra..."
install -d -m 755 -o root -g root "$INSTALLED_BACKUP_DIR"
install -m 755 -o root -g root "$SOURCE_BACKUP_SCRIPT" "$INSTALLED_BACKUP_SCRIPT"
sed -i 's|^REPO_ROOT=".*"|REPO_ROOT="/home/pi/repos/infra"|' "$INSTALLED_BACKUP_SCRIPT"
echo "      OK: $INSTALLED_BACKUP_SCRIPT"

echo "[2/8] Installerar root-owned wrapper i /usr/local/sbin..."
cat > "$WRAPPER_PATH" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec /usr/local/lib/infra/backup-dns-configs.sh --export-repo
EOF
chown root:root "$WRAPPER_PATH"
chmod 755 "$WRAPPER_PATH"
echo "      OK: $WRAPPER_PATH"

echo "[3/8] Installerar minimal sudoers-regel för wrapper..."
TMP_SUDOERS="$(mktemp)"
printf 'pi ALL=(root) NOPASSWD: %s\n' "$WRAPPER_PATH" > "$TMP_SUDOERS"
visudo -c -f "$TMP_SUDOERS"
cp "$TMP_SUDOERS" "$SUDOERS_PATH"
chmod 440 "$SUDOERS_PATH"
rm -f "$TMP_SUDOERS"
echo "      OK: $SUDOERS_PATH"

echo "[4/8] Installerar /usr/local/bin/infra-auto-sync.sh..."
cp "$REPO/scripts/install/infra-auto-sync.sh" /usr/local/bin/infra-auto-sync.sh
chown root:root /usr/local/bin/infra-auto-sync.sh
chmod 755 /usr/local/bin/infra-auto-sync.sh
echo "      OK: /usr/local/bin/infra-auto-sync.sh"
echo "[5/8] Installerar systemd units..."
cp "$REPO/systemd/units/infra-auto-sync.service" /etc/systemd/system/
cp "$REPO/systemd/timers/infra-auto-sync.timer"  /etc/systemd/system/
echo "      OK: service + timer"
echo "[6/8] Laddar om systemd och aktiverar timer..."
systemctl daemon-reload
systemctl enable --now infra-auto-sync.timer
echo "      OK: timer aktiverad"
echo "[7/8] Verifierar installerade paths..."
ls -l "$WRAPPER_PATH"
ls -l "$INSTALLED_BACKUP_SCRIPT"
grep -n 'REPO_ROOT=' "$INSTALLED_BACKUP_SCRIPT"

echo "[8/8] Verifierar timer..."
systemctl list-timers | grep infra-auto-sync
echo ""
echo "Klar! Kör manuellt test med:"
echo "  sudo -n $WRAPPER_PATH"
echo "  sudo systemctl start infra-auto-sync.service  # root/admin path"
echo "  journalctl -t infra-auto-sync -n 50 --no-pager"
