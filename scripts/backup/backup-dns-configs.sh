#!/usr/bin/env bash
set -euo pipefail
# backup-dns-configs.sh
# Backup AdGuardHome + Unbound configs (Pi3-safe, low overhead)
#
# Default:
#   - Config-only backup -> state/backups/dns-backup-YYYYmmdd_HHMMSS/
#
# Options:
#   --with-data     Include AdGuardHome work/data dir tar.gz (can be bigger)
#   --export-repo   Export sanitized config snapshots into repo config/
#   --help          Show help
WITH_DATA=0
EXPORT_REPO=0
for arg in "$@"; do
  case "$arg" in
    --with-data)   WITH_DATA=1 ;;
    --export-repo) EXPORT_REPO=1 ;;
    --help|-h)
      cat <<'USAGE'
Usage: backup-dns-configs.sh [--with-data] [--export-repo]
  --with-data     Include AdGuardHome work/data dir in backup tar.gz
  --export-repo   Export sanitized snapshots to repo config/
USAGE
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 2
      ;;
  esac
done
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TS="$(date '+%Y%m%d_%H%M%S')"
HOST="$(hostname)"
BACKUP_ROOT="$REPO_ROOT/state/backups"
DEST="$BACKUP_ROOT/dns-backup-$TS"
mkdir -p "$DEST"/{adguard,unbound,meta}
mkdir -p "$BACKUP_ROOT"
log() { echo "[$(date '+%H:%M:%S')] $*"; }
warn() { echo "[$(date '+%H:%M:%S')] WARN: $*" >&2; }
# Detect AdGuardHome config + work dir
AG_CONFIG=""
for p in \
  /home/pi/AdGuardHome/AdGuardHome.yaml \
  /opt/AdGuardHome/AdGuardHome.yaml \
  /etc/AdGuardHome.yaml \
  /usr/local/etc/AdGuardHome.yaml
do
  if [ -f "$p" ]; then AG_CONFIG="$p"; break; fi
done
AG_WORK_DIR=""
for p in \
  /home/pi/AdGuardHome/work \
  /opt/AdGuardHome/work \
  /var/lib/AdGuardHome \
  /usr/local/var/AdGuardHome
do
  if [ -d "$p" ]; then AG_WORK_DIR="$p"; break; fi
done
# Unbound paths (Debian/RPi OS typical)
UNBOUND_ETC="/etc/unbound"
UNBOUND_MAIN="/etc/unbound/unbound.conf"
UNBOUND_D_DIR="/etc/unbound/unbound.conf.d"
log "Creating backup at: $DEST"
# Metadata
{
  echo "timestamp=$TS"
  echo "hostname=$HOST"
  echo "repo_root=$REPO_ROOT"
  echo "with_data=$WITH_DATA"
  echo "export_repo=$EXPORT_REPO"
  echo "adguard_config=${AG_CONFIG:-not_found}"
  echo "adguard_work_dir=${AG_WORK_DIR:-not_found}"
  echo "unbound_main=$UNBOUND_MAIN"
  echo "unbound_conf_d=$UNBOUND_D_DIR"
  echo
  echo "[service_status]"
  systemctl is-active AdGuardHome 2>/dev/null || true
  systemctl is-active unbound 2>/dev/null || true
  echo
  echo "[service_enabled]"
  systemctl is-enabled AdGuardHome 2>/dev/null || true
  systemctl is-enabled unbound 2>/dev/null || true
} > "$DEST/meta/manifest.txt"
# AdGuard config
if [ -n "$AG_CONFIG" ] && [ -f "$AG_CONFIG" ]; then
  cp -a "$AG_CONFIG" "$DEST/adguard/AdGuardHome.yaml"
  log "Backed up AdGuard config: $AG_CONFIG"
else
  warn "AdGuard config not found"
fi
# Optional AdGuard data/work dir (can be larger)
if [ "$WITH_DATA" -eq 1 ]; then
  if [ -n "$AG_WORK_DIR" ] && [ -d "$AG_WORK_DIR" ]; then
    tar -czf "$DEST/adguard/adguard_work.tar.gz" -C "$AG_WORK_DIR" .
    log "Backed up AdGuard work dir (tar.gz): $AG_WORK_DIR"
  else
    warn "AdGuard work dir not found; skipping --with-data"
  fi
fi
# Unbound configs
if [ -d "$UNBOUND_ETC" ]; then
  mkdir -p "$DEST/unbound/etc-unbound"
  if [ -f "$UNBOUND_MAIN" ]; then
    cp -a "$UNBOUND_MAIN" "$DEST/unbound/etc-unbound/"
    log "Backed up Unbound main config"
  else
    warn "Unbound main config not found at $UNBOUND_MAIN"
  fi
  if [ -d "$UNBOUND_D_DIR" ]; then
    mkdir -p "$DEST/unbound/etc-unbound/unbound.conf.d"
    cp -a "$UNBOUND_D_DIR"/. "$DEST/unbound/etc-unbound/unbound.conf.d/" 2>/dev/null || true
    log "Backed up Unbound conf.d"
  fi
  # Useful extra files if present
  if [ -f "$UNBOUND_ETC/root.key" ]; then
    cp -a "$UNBOUND_ETC/root.key" "$DEST/unbound/etc-unbound/"
  fi
else
  warn "Unbound etc dir not found at $UNBOUND_ETC"
fi
# Checksums (helps verify restore later)
if command -v sha256sum >/dev/null 2>&1; then
  (
    cd "$DEST"
    find . -type f ! -name 'SHA256SUMS.txt' -print0 | sort -z | xargs -0 sha256sum
  ) > "$DEST/meta/SHA256SUMS.txt" || true
elif command -v shasum >/dev/null 2>&1; then
  (
    cd "$DEST"
    find . -type f ! -name 'SHA256SUMS.txt' -print0 | sort -z | xargs -0 shasum -a 256
  ) > "$DEST/meta/SHA256SUMS.txt" || true
fi
# Optional sanitized export into repo config/ (safe to git)
if [ "$EXPORT_REPO" -eq 1 ]; then
  mkdir -p "$REPO_ROOT/config/adguardhome" "$REPO_ROOT/config/unbound/unbound.conf.d"
  if [ -n "$AG_CONFIG" ] && [ -f "$AG_CONFIG" ]; then
    python3 - "$AG_CONFIG" "$REPO_ROOT/config/adguardhome/AdGuardHome.summary.sanitized.yml" <<'PY'
from datetime import datetime, timezone
from pathlib import Path
import sys
import yaml

source = Path(sys.argv[1])
dest = Path(sys.argv[2])

def as_dict(value):
    return value if isinstance(value, dict) else {}

def as_list(value):
    return value if isinstance(value, list) else []

def bool_or_none(value):
    return value if isinstance(value, bool) else None

def scalar_or_none(value):
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    return None

def first_present(*values):
    for value in values:
        if value is not None:
            return value
    return None

def count(value):
    if isinstance(value, (list, tuple, set, dict)):
        return len(value)
    return 0

def classify_bind_hosts(hosts):
    values = as_list(hosts)
    if not values:
        return "default"
    if any(str(v) in {"0.0.0.0", "::"} for v in values):
        return "all_interfaces"
    if all(str(v).startswith("127.") or str(v) == "::1" for v in values):
        return "loopback_only"
    return "specific_bind_hosts"

def upstream_kind(value):
    s = str(value).strip().lower()
    if not s:
        return "empty"
    if s.startswith("https://"):
        return "https"
    if s.startswith("tls://"):
        return "tls"
    if s.startswith("quic://"):
        return "quic"
    if s.startswith("sdns://"):
        return "sdns"
    if s.startswith("[/"):
        return "domain_routing_rule"
    if s.startswith("127.") or s.startswith("localhost") or s.startswith("::1"):
        return "loopback"
    if "://" in s:
        return "other_url"
    return "plain_host_or_ip"

def kind_counts(values):
    result = {}
    for item in as_list(values):
        kind = upstream_kind(item)
        result[kind] = result.get(kind, 0) + 1
    return dict(sorted(result.items()))

with source.open("r", encoding="utf-8", errors="replace") as fh:
    data = yaml.safe_load(fh) or {}

data = as_dict(data)
http = as_dict(data.get("http"))
dns = as_dict(data.get("dns"))
tls = as_dict(data.get("tls"))
querylog = as_dict(data.get("querylog"))
statistics = as_dict(data.get("statistics"))
filtering = as_dict(data.get("filtering"))
client_cfg = as_dict(data.get("clients"))

summary = {
    "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
    "source_path": str(source),
    "schema_version": scalar_or_none(data.get("schema_version")),
    "http": {
        "address_summary": classify_bind_hosts([http.get("address")] if http.get("address") is not None else []),
        "port": scalar_or_none(http.get("port")),
    },
    "dns": {
        "bind_hosts_count": count(dns.get("bind_hosts")),
        "bind_hosts_summary": classify_bind_hosts(dns.get("bind_hosts")),
        "port": scalar_or_none(dns.get("port")),
        "upstream_dns_count": count(dns.get("upstream_dns")),
        "upstream_dns_type_summary": kind_counts(dns.get("upstream_dns")),
        "bootstrap_dns_count": count(dns.get("bootstrap_dns")),
        "protection_enabled": bool_or_none(first_present(dns.get("protection_enabled"), filtering.get("protection_enabled"))),
        "filtering_enabled": bool_or_none(first_present(dns.get("filtering_enabled"), filtering.get("filtering_enabled"))),
        "blocking_mode": scalar_or_none(first_present(dns.get("blocking_mode"), filtering.get("blocking_mode"))),
        "cache_size": scalar_or_none(dns.get("cache_size")),
        "cache_ttl_min": scalar_or_none(dns.get("cache_ttl_min")),
        "cache_ttl_max": scalar_or_none(dns.get("cache_ttl_max")),
        "optimistic_cache": bool_or_none(first_present(dns.get("optimistic_cache"), dns.get("cache_optimistic"))),
        "enable_dnssec": bool_or_none(dns.get("enable_dnssec")),
        "handle_ddr": bool_or_none(dns.get("handle_ddr")),
    },
    "filtering_summary": {
        "filters_count": count(data.get("filters")),
        "whitelist_filters_count": count(data.get("whitelist_filters")),
        "rewrites_count": count(filtering.get("rewrites")),
        "user_rule_count": count(data.get("user_rules")),
    },
    "client_summary": {
        "persistent_client_count": count(client_cfg.get("persistent")),
        "runtime_client_sources_count": count(client_cfg.get("runtime_sources")),
    },
    "querylog": {
        "enabled": bool_or_none(querylog.get("enabled")),
        "file_enabled": bool_or_none(querylog.get("file_enabled")),
        "interval": scalar_or_none(querylog.get("interval")),
        "size_memory": scalar_or_none(querylog.get("size_memory")),
    },
    "statistics": {
        "enabled": bool_or_none(statistics.get("enabled")),
        "interval": scalar_or_none(statistics.get("interval")),
    },
    "tls": {
        "enabled": bool_or_none(tls.get("enabled")),
        "server_name": scalar_or_none(tls.get("server_name")),
        "port_https": scalar_or_none(tls.get("port_https")),
        "port_dns_over_tls": scalar_or_none(tls.get("port_dns_over_tls")),
        "certificate_path": scalar_or_none(tls.get("certificate_path")),
        "private_key_path": scalar_or_none(tls.get("private_key_path")),
    },
    "redaction_note": "Summary only. Detailed lists and sensitive values are omitted from Git artifacts.",
}

dest.parent.mkdir(parents=True, exist_ok=True)
with dest.open("w", encoding="utf-8") as fh:
    yaml.safe_dump(summary, fh, sort_keys=False, allow_unicode=False)
PY
    cat > "$REPO_ROOT/config/adguardhome/README.md" <<'EOF'
# AdGuard Home Git export

This directory contains the Git-tracked AdGuard Home summary artifact for the Raspberry Pi DNS node.

Tracked artifact:

- `AdGuardHome.summary.sanitized.yml`

Policy:

- Raw `AdGuardHome.yaml` must never be committed, pasted, or printed.
- Git-tracked AdGuard data must be summary/count metadata only.
- Detailed clients, rewrites, and user rules must remain counts only in Git.
- Detailed local artifacts, if needed for restore or debugging, belong under ignored `state/` paths and must not be pasted into prompts or docs.
- Restore and YAML fallback work must follow `docs/adguard-home-change-policy.md`.

The summary artifact is a reference for inventory and policy review. It is not a raw restore source.
EOF
    log "Exported sanitized AdGuard summary to repo config/adguardhome/"
  fi
  if [ -f "$UNBOUND_MAIN" ]; then
    cp -a "$UNBOUND_MAIN" "$REPO_ROOT/config/unbound/unbound.conf"
  fi
  if [ -d "$UNBOUND_D_DIR" ]; then
    find "$UNBOUND_D_DIR" -maxdepth 1 -type f -name '*.conf' -exec cp -a {} "$REPO_ROOT/config/unbound/unbound.conf.d/" \;
  fi
  log "Exported Unbound config snapshots to repo config/unbound/"
fi
# Final summary
SIZE_HUMAN="$(du -sh "$DEST" | awk '{print $1}')"
echo
echo "Backup complete ✅"
echo "Location: $DEST"
echo "Size:     $SIZE_HUMAN"
echo "Modes:    with_data=$WITH_DATA export_repo=$EXPORT_REPO"
# Optional latest symlink for convenience
ln -sfn "$DEST" "$BACKUP_ROOT/latest"
log "Updated symlink: $BACKUP_ROOT/latest"
