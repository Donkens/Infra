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
