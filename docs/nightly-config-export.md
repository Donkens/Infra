# Nightly config export model

## Summary

The Raspberry Pi runtime config is the operational source of truth for live DNS service state.

The Git-tracked files under `config/` are exported snapshots from the Pi. They are useful for review, history, drift detection, and restore planning, but they are not the live authority by themselves.

## Source-of-truth model

```text
Pi runtime config
  -> nightly backup/export
  -> repo config snapshot
  -> GitHub history
```

Operational rule:

- Change live DNS behavior on the Pi only through an approved runtime change flow.
- Let the nightly export mirror the approved runtime state back into Git.
- Do not edit exported `config/` snapshots in GitHub and assume the Pi runtime changed.

## Export behavior

`backup-dns-configs.sh --export-repo` exports DNS state into the repo.

Runtime automation path (hardened model):

- `infra-auto-sync.service` runs as `pi` and calls `sudo -n /usr/local/sbin/infra-backup-dns-export`.
- `/usr/local/sbin/infra-backup-dns-export` is a root-owned wrapper.
- The wrapper executes `/usr/local/lib/infra/backup-dns-configs.sh --export-repo`.
- Sudo allowlist should permit only this wrapper command for `pi`.
- The repo-path script (`/home/pi/repos/infra/scripts/backup/backup-dns-configs.sh`) must not be directly allowlisted in sudoers.

AdGuard Home:

- Raw `AdGuardHome.yaml` stays local-only and must not be committed.
- Git receives `config/adguardhome/AdGuardHome.summary.sanitized.yml` only.
- The summary artifact contains metadata/counts and intentionally omits detailed sensitive values.

Unbound:

- `config/unbound/unbound.conf` is copied from `/etc/unbound/unbound.conf`.
- `config/unbound/unbound.conf.d/*.conf` is copied from `/etc/unbound/unbound.conf.d/*.conf`.
- These Unbound files are snapshots of runtime source files.

## Auto-sync allowlist

Nightly auto-sync may stage only the approved snapshot paths:

- `config/adguardhome/AdGuardHome.summary.sanitized.yml`
- `config/adguardhome/README.md`
- `config/unbound/unbound.conf`
- `config/unbound/unbound.conf.d/*.conf`

If an export creates changes outside the allowlist, auto-sync should abort before commit.

## 2026-04-30 ptr-local.conf note

Nightly commit `2857f2e` changed only a comment in `config/unbound/unbound.conf.d/ptr-local.conf`:

```diff
-# Tracked snapshot for Unbound PTR/reverse baseline.
+# Runtime source for Unbound PTR/reverse baseline.
```

Root cause:

- The runtime file on the Pi had already been edited to use the more accurate comment.
- The export script mirrored `/etc/unbound/unbound.conf.d/ptr-local.conf` into `config/unbound/unbound.conf.d/ptr-local.conf`.
- No PTR records, IP addresses, hostnames, DNS behavior, or service settings changed.

Conclusion:

- The change was expected and safe.
- `Runtime source` is clearer wording for the Pi-side file.
- No follow-up action is required.

## Auto-PASS criteria

An agent reviewing a nightly commit may treat the following as **Auto-PASS** and proceed without operator action:

- Only `generated_at` changed in `config/adguardhome/AdGuardHome.summary.sanitized.yml`.
- Only comment lines (lines beginning with `#`) changed in any `config/unbound/` snapshot.

Require **WARN / REVIEW** if any of the following changed:

- DNS semantic values: PTR records, hostnames, IP addresses, or upstream resolvers.
- Any AdGuard summary field other than `generated_at`.
- Any file outside the auto-sync allowlist was staged or committed.
- `state/dns-health.last` or `state/backup-health.last` indicates a health failure.

## Operator guidance

When a nightly commit changes `config/unbound/`:

1. Check whether the change is config semantics or only comments/timestamps.
2. For semantic changes, identify when and why the Pi runtime file changed.
3. Confirm the change stayed inside the auto-sync allowlist.
4. Confirm `dns-health` and `backup-health` stayed OK.
5. Leave harmless mirrored runtime comments as-is.

When a nightly commit changes only `generated_at` in the AdGuard summary, treat it as normal snapshot churn unless other summary fields changed.

Manual service start boundary:

- `systemctl start infra-auto-sync.service` is a root/admin operation.
- Running that start command interactively as `pi` is expected to fail with `Interactive authentication required` under the hardened model.
- For manual validation from `pi`, validate the export path directly with `sudo -n /usr/local/sbin/infra-backup-dns-export` instead of starting the systemd service.
