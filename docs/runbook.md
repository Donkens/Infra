# Pi DNS Runbook (AdGuard Home + Unbound)
## Status
sudo systemctl status AdGuardHome --no-pager
sudo systemctl status unbound --no-pager
## Restart
sudo systemctl restart AdGuardHome
sudo systemctl restart unbound
## Logs
journalctl -u AdGuardHome -n 100 --no-pager
journalctl -u unbound -n 100 --no-pager
## Follow logs (live)
journalctl -fu AdGuardHome
journalctl -fu unbound
## Ports
sudo ss -tulpn | egrep ':53|:80|:3000'
## DNS test
dig @127.0.0.1 google.com
dig @127.0.0.1 openai.com
