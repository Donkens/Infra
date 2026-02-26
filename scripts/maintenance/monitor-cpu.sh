#!/bin/bash
echo "CPU Frequency Monitoring (Performance Governor)"
echo "=============================================="
echo ""
for i in {0..3}; do
  freq=$(sudo cat /sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_cur_freq 2>/dev/null)
  gov=$(sudo cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor 2>/dev/null)
  mhz=$((freq / 1000))
  echo "CPU$i: $mhz MHz | Governor: $gov"
done
