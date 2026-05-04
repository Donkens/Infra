# SSH Hardening Baseline

Status: baseline
Scope: Mac mini, MacBook Pro, Raspberry Pi DNS node, UDR-7, Opti/Proxmox, HAOS SSH add-on, Docker VM, and GitHub SSH flows.

## Summary

SSH access should be explicit, key-based, minimally scoped, and documented by role. Admin clients may connect to infrastructure hosts. Routers, HAOS, and service nodes should remain SSH targets only unless a concrete outbound automation requires otherwise.

Default posture:

- key-only automation checks
- `ForwardAgent no`
- explicit `Host` stanzas
- documented identity files
- short connect timeouts for audits
- no private keys in Git, chats, issues, or docs

## Host role model

| Host | Role | SSH posture |
|---|---|---|
| Mac mini (`mini`) | Primary admin client | May SSH to infra hosts; GitHub uses dedicated GitHub key. |
| MacBook Pro (`mbp`) | Secondary admin client | May SSH to infra hosts; GitHub uses MBP key. |
| Pi (`pi`) | DNS/service node | GitHub access allowed for repo sync; lateral SSH not required by default. |
| UDR-7 (`udr`) | Gateway/router | SSH target only; not a jump host. |
| Opti (`opti`) | Proxmox/compute host | SSH target/admin host; private Proxmox host key stays local. |
| HAOS (`ha`) | Home Assistant SSH add-on | Admin target only; no outbound SSH by default. |
| Docker VM (`docker`) | Service VM | SSH auth not fully provisioned yet; bootstrap through Proxmox/cloud-init. |
| GitHub | Repo remote | Dedicated keys where practical. |

## Client defaults

Recommended baseline for client SSH config:

```sshconfig
Host *
  ForwardAgent no
  IdentitiesOnly yes
  ServerAliveInterval 30
  ServerAliveCountMax 3
```

Notes:

- `IdentitiesOnly yes` should be set per explicit host if a global setting breaks unrelated hosts.
- `ForwardAgent no` is the default. Enable agent forwarding only for a narrow documented flow.
- Avoid relying on username fallbacks. Always set `User` in infra host stanzas.

## Audit command pattern

Use non-interactive SSH for audits and automation:

```bash
ssh -o BatchMode=yes -o NumberOfPasswordPrompts=0 -o ConnectTimeout=5 <host> 'hostname; whoami; uname -a'
```

For config review:

```bash
ssh -G <host> | awk '/^(hostname|user|port|identityfile|identitiesonly|forwardagent|passwordauthentication|pubkeyauthentication) / { print }'
```

This prevents password prompts from hiding broken key-based auth.

## Known host handling

Policy:

- Do not disable host-key checking as a normal workflow.
- Prefer stable DNS names or stable IPs and document which one is pinned.
- If a VM is rebuilt and its host key changes, remove only that host's entry.
- Do not wipe the entire `known_hosts` file.

Safe targeted cleanup pattern:

```bash
ssh-keygen -F <host> || true
ssh-keygen -R <host>
ssh-keyscan -t ed25519 <host-or-ip> >> ~/.ssh/known_hosts
ssh-keygen -F <host-or-ip>
```

Use this only for hosts you control and have verified through a trusted local path.

## GitHub SSH policy

| Client | GitHub key policy |
|---|---|
| Mac mini | Use dedicated `id_ed25519_github`. |
| MacBook Pro | Use MBP key unless/until a dedicated GitHub key is created. |
| Pi | Use dedicated `id_ed25519_github_pi` for repo sync. |
| Opti/Docker VM | Use dedicated deploy/user key only if repo automation is needed. |

GitHub stanzas should keep:

```sshconfig
Host github.com
  User git
  HostName github.com
  IdentitiesOnly yes
  ForwardAgent no
```

## Agent forwarding

Default: disabled.

Allowed only when all conditions are true:

1. The source and target hosts are trusted.
2. The workflow requires the agent rather than a direct key/deploy key.
3. The flow is documented.
4. The setting is scoped to a specific host, not global.

Do not enable agent forwarding for routers, HAOS, Docker services, or broad unknown hosts.

## Password authentication

Client-side `PasswordAuthentication yes` in `ssh -G` does not prove the server accepts passwords. It only means the client may try password auth if key auth fails.

For automation and audits, enforce:

```bash
-o BatchMode=yes -o NumberOfPasswordPrompts=0
```

Optional hardening for explicit infra stanzas:

```sshconfig
PasswordAuthentication no
KbdInteractiveAuthentication no
```

Apply gradually per host after verifying key-only access and keeping a recovery path.

## Per-host policy

### Mac mini

- Primary admin client.
- May connect to Pi, MBP, UDR, Opti, HAOS, and Docker VM once provisioned.
- GitHub should use the dedicated GitHub key.
- Keep private keys local.

### MacBook Pro

- Secondary admin client.
- May connect to Pi, Mac mini, UDR, Opti, HAOS, and Docker VM once provisioned.
- Good for cross-checking Mac mini auth and repo sync.

### Pi

- Primary DNS/service node.
- May connect to GitHub for repo sync.
- Should not become a broad jump host.
- Lateral SSH to Mac mini, MBP, UDR, HAOS, or Opti is not required by default.

### UDR-7

- Router/gateway.
- SSH target only.
- Keep no private client keys on UDR unless a future automation explicitly requires it.
- Old `authorized_keys` backups may be archived/removed later after review.

### Opti / Proxmox

- Compute/virtualization host.
- Local Proxmox SSH key material may exist and must stay on host.
- Do not paste or commit `/root/.ssh/id_rsa` or Proxmox cluster secrets.
- Treat Opti as a sensitive admin target.

### HAOS

- SSH add-on/admin shell target.
- Do not store persistent private keys inside the add-on unless a documented automation requires it.
- Do not print HA tokens, add-on options, or `secrets.yaml`.

### Docker VM

- SSH auth currently incomplete until admin keys are provisioned.
- Bootstrap via Proxmox console/cloud-init or another trusted local path.
- After provisioning, document the exact user/key and rerun auth-side verification.
- Avoid giving Docker VM broad SSH access to other hosts.

## Key rotation guidance

Rotate keys when:

- a private key may have been exposed
- a host changes owner/role
- a device is retired
- a key is reused in too many roles
- a no-pass key has unclear scope

Rotation pattern:

1. Add new public key.
2. Verify new key-only login.
3. Remove old public key.
4. Verify old key no longer works if practical.
5. Update docs with fingerprints only.
6. Keep rollback path until the new key is proven.

## Recovery path

Before making SSH changes on a remote host:

- ensure console access exists, or
- ensure another admin host/session remains connected, or
- ensure the host has an alternate trusted recovery path.

Do not change SSH server settings on UDR, Opti, Pi, or HAOS without a rollback plan.

## Safe verification checklist

- [ ] `ssh -G <host>` shows the intended `User`.
- [ ] `ssh -G <host>` shows the intended `IdentityFile`.
- [ ] `ForwardAgent no` unless explicitly documented.
- [ ] key-only login works with `BatchMode=yes`.
- [ ] `known_hosts` is pinned for the expected host/IP.
- [ ] no private keys were printed.
- [ ] docs store fingerprints, not private key material.

## Related docs

- [`auth-baseline.md`](auth-baseline.md)
- [`secrets-policy.md`](secrets-policy.md)
- [`github-key-cleanup-2026-05-04.md`](github-key-cleanup-2026-05-04.md)
- [`docker-auth-side-verification-2026-05-04.md`](docker-auth-side-verification-2026-05-04.md)
- [`../../runbooks/docker-vm-ssh-bootstrap.md`](../../runbooks/docker-vm-ssh-bootstrap.md)
