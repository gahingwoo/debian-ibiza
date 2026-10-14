#!/bin/sh
# Samples SoC temperature, CPU frequencies, battery power and memory every 5 s into /run/ibiza/history.tsv
# (ts_ms  temp_C  little_MHz  big_MHz  battery_W(+charging)  mem_used_MB), keeping the last hour. Read by the Cockpit page.
OUT=/run/ibiza/history.tsv
mkdir -p /run/ibiza; : > $OUT; chmod 644 $OUT
ZONES=""
for z in /sys/class/thermal/thermal_zone*; do
  case "$(cat $z/type 2>/dev/null)" in cpu-*|cpuss-*) ZONES="$ZONES $z/temp";; esac
done
B=/sys/class/power_supply/qcom_battery
n=0
while true; do
  t=0
  for f in $ZONES; do read v < $f 2>/dev/null; [ "${v:-0}" -gt "$t" ] && t=$v; done
  read c0 < /sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq
  read c6 < /sys/devices/system/cpu/cpufreq/policy6/scaling_cur_freq
  read vn < $B/voltage_now; read cn < $B/current_now
  mt=0; ma=0
  while read k v _; do
    case $k in MemTotal:) mt=$v;; MemAvailable:) ma=$v; break;; esac
  done < /proc/meminfo
  read up _ < /proc/uptime
  now=$(date +%s)
  # current_now is negative while charging: power into the battery is positive
  awk -v ts=$now -v t=$t -v a=$c0 -v b=$c6 -v v=$vn -v c=$cn -v mt=$mt -v ma=$ma \
    'BEGIN{printf "%d000\t%.1f\t%d\t%d\t%.2f\t%d\n", ts, t/1000, a/1000, b/1000, -(v/1e6)*(c/1e6), (mt-ma)/1024}' >> $OUT
  n=$((n+1))
  if [ $n -ge 120 ]; then n=0; tail -n 720 $OUT > $OUT.tmp && mv $OUT.tmp $OUT; fi
  sleep 5
done
