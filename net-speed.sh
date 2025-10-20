#!/usr/bin/env bash
# net-speed.sh — show default interface down/up speeds using /sys stats
# Prints: Net (iface): ▼ 123.4 KiB/s ▲ 45.6 KiB/s [IP]

set -euo pipefail

# Find default interface
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++){if($i=="dev"){print $(i+1); exit}}}')
[ -z "${IFACE:-}" ] && IFACE=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
[ -z "${IFACE:-}" ] && { echo "Net: -"; exit 0; }

RX_FILE="/sys/class/net/$IFACE/statistics/rx_bytes"
TX_FILE="/sys/class/net/$IFACE/statistics/tx_bytes"
if [ ! -r "$RX_FILE" ] || [ ! -r "$TX_FILE" ]; then
  echo "Net ($IFACE): -"
  exit 0
fi

now=$(date +%s)
rx=$(cat "$RX_FILE")
tx=$(cat "$TX_FILE")
state_file="/tmp/conky_net_${IFACE}.state"

prx=0; ptx=0; ptime=$now
if [ -r "$state_file" ]; then
  read -r prx ptx ptime < "$state_file" || true
fi

echo "$rx $tx $now" > "$state_file"

dt=$(( now - ptime ))
[ $dt -le 0 ] && dt=1

# Bytes per second
drx=$(( rx - prx ))
dtx=$(( tx - ptx ))
[ $drx -lt 0 ] && drx=0
[ $dtx -lt 0 ] && dtx=0

bps_down=$(awk -v b=$drx -v d=$dt 'BEGIN{printf "%.1f", b/d}')
bps_up=$(awk -v b=$dtx -v d=$dt 'BEGIN{printf "%.1f", b/d}')

human() {
  local bps=$1
  local unit="B/s"
  local val=$bps
  if awk 'BEGIN{exit !(ARGV[1]>=1024)}' "$bps"; then unit="KiB/s"; val=$(awk -v v=$bps 'BEGIN{printf "%.1f", v/1024}'); fi
  if awk 'BEGIN{exit !(ARGV[1]>=1024)}' "$val"; then unit="MiB/s"; val=$(awk -v v=$val 'BEGIN{printf "%.1f", v/1024}'); fi
  echo "$val $unit"
}

hdown=$(human "$bps_down")
hup=$(human "$bps_up")

IP4=$(ip -o -4 addr show dev "$IFACE" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1)
[ -n "$IP4" ] && IP4=" [$IP4]"

echo "Net ($IFACE): ▼ $hdown ▲ $hup$IP4"
