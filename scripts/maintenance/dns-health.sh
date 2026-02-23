#!/usr/bin/env bash
set -euo pipefail
echo "== Services =="
systemctl is-active AdGuardHome || true
systemctl is-active unbound || true
echo
echo "== Ports (:53 :80 :3000) =="
ss -tulpn | egrep ':53|:80|:3000' || true
echo
echo "== DNS test (localhost) =="
if command -v dig >/dev/null 2>&1; then
  dig +short @127.0.0.1 google.com || true
  dig +short @127.0.0.1 openai.com || true
else
  echo "dig not installed (sudo apt install -y dnsutils)"
fi
echo
echo "== Recent logs (AdGuardHome) =="
journalctl -u AdGuardHome -n 20 --no-pager || true
echo
echo "== Recent logs (unbound) =="
journalctl -u unbound -n 20 --no-pager || true
