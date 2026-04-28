# Unbound config snapshot

This directory contains the Git-tracked restore snapshot for the Pi Unbound
configuration. It intentionally tracks only active `.conf` files that should be
replayed during restore.

Live `/etc/unbound/unbound.conf.d` may contain local `.OFF` and `.bak` leftovers
from previous operator work. Those files are runtime-local history and must not
be tracked or copied back from this repo.

As of the 2026-04-28 audit, localhost/5335 binding is part of
`config/unbound/unbound.conf.d/pi.conf`; the old split
`00-localhost-5335.conf` snapshot was removed to match live Pi runtime.
