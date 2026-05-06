# Validate SSH reachability

Short read-only checks for admin-client SSH aliases. Use from `mini` or `mbp` only.

## Scope

- Admin clients: `mini`, `mbp`
- Docker VM aliases: `docker`, `docker.home.lan`, `proxy`, `proxy.home.lan`
- Expected target: `192.168.30.10`
- Expected user: `yasse`

## DNS resolution

```bash
for h in mini mbp; do
  echo "=== $h ==="
  ssh "$h" '
    for a in docker docker.home.lan proxy proxy.home.lan; do
      echo "--- $a ---"
      dscacheutil -q host -a name "$a" || true
    done
  '
done
```

## Effective SSH config

```bash
for h in mini mbp; do
  echo "=== $h ==="
  ssh "$h" '
    for a in docker docker.home.lan proxy proxy.home.lan; do
      echo "--- $a ---"
      ssh -G "$a" | grep -E "^(hostname|user|identityfile|identitiesonly) "
    done
  '
done
```

Expected effective values:

```text
hostname 192.168.30.10
user yasse
identityfile ~/.ssh/id_ed25519_macmini
identitiesonly yes
```

## BatchMode reachability

```bash
for h in mini mbp; do
  echo "=== $h ==="
  ssh "$h" '
    for a in docker docker.home.lan proxy proxy.home.lan; do
      echo "--- $a ---"
      ssh -o BatchMode=yes -o ConnectTimeout=5 "$a" "hostname; whoami"
    done
  '
done
```

Expected remote response:

```text
docker
yasse
```
