# Raspberry Pi 3B+ SDRAM OC baseline — 2026-04-27

> **HISTORICAL SNAPSHOT / STALE:** verify current state in `inventory/` and current runbooks before applying any changes.


## Summary

- Model: Raspberry Pi 3 Model B Plus Rev 1.3
- Role: DNS primary, AdGuard Home + Unbound
- Active config: `/boot/firmware/config.txt`
- Decision: keep `sdram_freq=550`
- Status: preliminarily stable after boot validation and stress-ng VM test
- Do not raise to `575` without better cooling and longer stability.

## Active config

- Path: `/boot/firmware/config.txt`
- Backup before OC change: `/boot/firmware/config.txt.bak.20260427-120716`

## OC block

```config
# yasse-sdram-oc-start
# RAM OC -- Minimal 550 MHz -- 2026-04-27
sdram_freq=550
# yasse-sdram-oc-end
```

## Validation

- Boot OK after config change.
- `vcgencmd get_config sdram_freq` returned `sdram_freq=550`.
- `stress-ng --vm 1 --vm-bytes 128M --timeout 10m --metrics-brief` passed.
- No undervoltage observed.
- No active throttling observed.
- No mmc, ext4, or OOM errors observed.
- AdGuard Home and Unbound were running after reboot.
- DNS ports were listening: `53`, `5335`, `853`.
- `vcgencmd get_throttled` showed `0x80000` after stress test.
- Meaning: historical soft temperature limit occurred since boot.
- Not active throttling.
- Not undervoltage.
- Daily temp after test period was around `52.6'C`.

## Policy

Keep this Pi conservative because it is the primary DNS node.

Recommended:

- Keep `sdram_freq=550`.
- Treat `550` as the current stable baseline.
- Improve cooling before any further OC experiments.
- Re-check `vcgencmd get_throttled`, `dmesg`, and `journalctl` after changes.

Avoid:

- Do not raise to `sdram_freq=575` unless cooling is improved and long-term stability remains clean.
- Do not add `over_voltage_sdram` while `550` is stable without it.
- Do not use `force_turbo=1`.
- Do not pursue further CPU OC on this DNS node.

## Rollback

```bash
sudo cp -a /boot/firmware/config.txt.bak.20260427-120716 /boot/firmware/config.txt
sudo reboot
```

## Follow-up checks

```bash
vcgencmd get_config sdram_freq
vcgencmd get_throttled
vcgencmd measure_temp
dmesg -T | grep -Ei 'under-voltage|voltage|thrott|mmc|i/o error|ext4|corrupt|reset|thermal|oom|killed process' | tail -120 || true
journalctl -b -p warning --no-pager | tail -120 || true
```