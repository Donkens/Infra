#!/usr/bin/env bash
# enable-extended-stats.sh
# Kör med: sudo bash /home/pi/repos/infra/scripts/install/enable-extended-stats.sh
set -euo pipefail

TARGET="/etc/unbound/unbound.conf.d/pi.conf"
BACKUP="${TARGET}.bak.$(date +%F-%H%M)"

echo "[1/5] Backup..."
cp "$TARGET" "$BACKUP"
echo "      OK: $BACKUP"

echo "[2/5] Kontrollerar om extended-statistics redan är aktiv..."
if grep -q "extended-statistics:" "$TARGET"; then
  echo "      Redan konfigurerad — inget att göra."
  grep "extended-statistics:" "$TARGET"
  exit 0
fi

echo "[3/5] Lägger till extended-statistics: yes efter verbosity-raden..."
sed -i 's/^  verbosity: 2$/  verbosity: 2\n  extended-statistics: yes/' "$TARGET"

echo "      Diff:"
diff "$BACKUP" "$TARGET" || true

echo "[4/5] Validerar config..."
if unbound-checkconf; then
  echo "      OK: config giltig"
else
  echo "      FEL: config ogiltig — rullar tillbaka"
  cp "$BACKUP" "$TARGET"
  echo "      Återställd till $BACKUP"
  exit 1
fi

echo "[5/5] Startar om Unbound..."
systemctl restart unbound
sleep 5

echo ""
echo "=== rcode-stats ==="
unbound-control stats_noreset | grep -i rcode
