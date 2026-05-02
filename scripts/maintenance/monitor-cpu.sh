#!/usr/bin/env bash
# Purpose: Show CPU frequency and governor for all cores
# Author:  codex-agent | Date: 2026-04-29
set -euo pipefail
log() { echo "[$(basename "$0")] $*" >&2; }
die() { log "ERROR: $*"; exit 1; }

cpu_count=$(nproc 2>/dev/null || echo 4)

echo "CPU Frequency Monitoring (Performance Governor)"
echo "=============================================="
echo ""
for i in $(seq 0 $((cpu_count - 1))); do
  freq=$(cat "/sys/devices/system/cpu/cpu${i}/cpufreq/cpuinfo_cur_freq" 2>/dev/null || echo 0)
  gov=$(cat  "/sys/devices/system/cpu/cpu${i}/cpufreq/scaling_governor"  2>/dev/null || echo unknown)
  mhz=$(( ${freq:-0} / 1000 ))
  echo "CPU${i}: ${mhz} MHz | Governor: ${gov}"
done
