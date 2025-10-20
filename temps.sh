#!/usr/bin/env bash
# temps.sh — show CPU and GPU temperatures
# Tries lm-sensors, then sysfs; GPU via nvidia-smi or amdgpu hwmon

set -euo pipefail

cpu=""
gpu=""

# CPU temp via sensors
if command -v sensors >/dev/null 2>&1; then
  cpu=$(sensors 2>/dev/null | awk '/^Package id 0:|^Tctl:/{gsub("+","",$2); print $2; exit}') || cpu=""
  if [ -z "$cpu" ]; then
    cpu=$(sensors 2>/dev/null | awk '/^Core 0:/{gsub("+","",$3); print $3; exit}') || cpu=""
  fi
fi

# CPU temp via sysfs fallback (average of thermal_zone*)
if [ -z "$cpu" ]; then
  sum=0; n=0
  for f in /sys/class/thermal/thermal_zone*/temp; do
    [ -r "$f" ] || continue
    v=$(cat "$f" 2>/dev/null || echo 0)
    [ "$v" -gt 0 ] || continue
    # Some report in millidegree C
    if [ "$v" -gt 1000 ]; then v=$(( v / 1000 )); fi
    sum=$(( sum + v ))
    n=$(( n + 1 ))
  done
  if [ "$n" -gt 0 ]; then cpu="${sum/$n}°C"; fi
fi

# GPU temp NVIDIA
if command -v nvidia-smi >/dev/null 2>&1; then
  g=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | head -n1 || true)
  [ -n "${g:-}" ] && gpu="${g}°C"
fi

# GPU temp AMD via hwmon
if [ -z "$gpu" ]; then
  for f in /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input; do
    [ -r "$f" ] || continue
    v=$(cat "$f" 2>/dev/null || echo 0)
    [ "$v" -gt 0 ] || continue
    if [ "$v" -gt 1000 ]; then v=$(( v / 1000 )); fi
    gpu="${v}°C"
    break
  done
fi

out=""
[ -n "$cpu" ] && out="CPU: $cpu"
[ -n "$gpu" ] && { [ -n "$out" ] && out="$out | "; out="${out}GPU: $gpu"; }

[ -z "$out" ] && out="Temps: -"

echo "$out"
