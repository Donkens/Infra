# Docker VM Auth-side Verification — 2026-05-04

Mode: read-only / incomplete
Source target: Docker VM on Server VLAN
Command origin: MacBook Pro (`mbp`) / user `hd`

## Summary

Status: WARN / incomplete.

The Docker VM host key was observed and the MacBook known-hosts entry was cleaned up so the VM is now pinned by IP address rather than only by the short alias. SSH key login into the VM is not yet provisioned for either tested admin account.

No private keys, Docker secrets, compose files, environment files, or raw service configs were printed.

## Observed state

| Item | Result |
|---|---|
| VM reachability | Host key reachable |
| Host key type | ED25519 |
| Short alias attempt | Failed before remote script execution |
| IP host-key pin | Completed on MacBook |
| Admin login test as root | Public-key denial |
| Admin login test as user `yasse` | Public-key denial |
| Docker-side script | Not yet executed successfully |

## Interpretation

This is a normal early-VM/bootstrap state. The VM is reachable enough to present a stable host key, but the intended SSH user/key has not been provisioned yet.

Recommended policy:

| Flow | Policy |
|---|---|
| Mac mini -> Docker VM | allowed once key-only auth is provisioned |
| MacBook -> Docker VM | allowed once key-only auth is provisioned |
| Docker VM -> GitHub | allowed only if needed for repo/compose automation, preferably using a dedicated deploy/user key |
| Docker VM -> Pi/UDR/Macs | not required by default |
| Docker VM as broad jump host | discouraged |
| Docker socket access | document users/groups before granting broad access |

## Follow-ups

1. Add the intended Mac mini/MacBook public key through Proxmox console, cloud-init, or another trusted local bootstrap method.
2. Add an explicit SSH client stanza after the correct user/key is confirmed.
3. Run the full Docker VM auth-side check again after key provisioning succeeds.
4. Document Docker group membership and socket access once Docker is fully provisioned.
5. Keep Docker secrets, private SSH keys, `.env`, compose secrets, and raw app configs out of Git.

## Safe next validation

After provisioning the admin key, run a key-only SSH check with batch mode and a short connection timeout, then rerun the full Docker VM auth-side inventory.
