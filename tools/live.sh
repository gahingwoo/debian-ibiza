#!/bin/bash
# Hands-off: RAM-boot Linux, wait for the USB serial, send "touch /tmp/stay" immediately, run diagnostics over serial and (if reachable) the network. Output: ~/Desktop/ibiza/linux_live.txt
#   cd ~/Desktop/ibiza/LOS/linuxb && bash live.sh
# Linux stays up afterwards (no auto-reboot). To go back to Android: adb is not available in Linux; hold Power ~15s.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; IMG="$HERE/../images/boot_b.linux4.img"; OUT="$HERE/../../linux_live.txt"
if adb devices 2>/dev/null | grep -qw device; then adb reboot bootloader; fi
for i in $(seq 1 30); do fastboot devices | grep -q . && break; sleep 2; done
fastboot devices | grep -q . || { echo "no fastboot device"; exit 1; }
fastboot boot "$IMG" || exit 1
DEV=""
for i in $(seq 1 40); do DEV=$(ls /dev/cu.usbmodemibiza* 2>/dev/null | head -n 1); [ -n "$DEV" ] && break; sleep 1; done
[ -n "$DEV" ] || { echo "serial never appeared"; exit 1; }
echo "serial: $DEV"; : > "$OUT"
stty -f "$DEV" 115200 cs8 -parenb -cstopb raw -echo clocal 2>/dev/null
exec 3<>"$DEV"
cat <&3 >> "$OUT" &
CP=$!
sleep 1
printf '\n' >&3; printf 'touch /tmp/stay\n' >&3; sleep 2
printf 'touch /tmp/stay\n' >&3
for c in 'echo MARK_START' 'uname -a' 'cat /proc/cmdline' 'cat /proc/uptime' 'ls /sys/class/net' 'ls /sys/class/udc' 'cat /sys/class/udc/*/state' 'free -m' 'cat /proc/partitions' 'for f in /sys/class/block/*/uevent; do grep -H PARTNAME $f; done' 'ls /tmp' 'dmesg | tail -n 25' 'echo MARK_END'; do
  printf '%s\n' "$c" >&3; sleep 1
done
sleep 3
kill $CP 2>/dev/null; exec 3>&-
echo "--- serial output (raw)"; cat -v "$OUT" | head -n 150
echo "--- network (nc 10.55.0.2:23)"; ifconfig | grep -B3 "inet 10.55" | head
(printf 'uname -a\n'; sleep 2) | nc -w 4 10.55.0.2 23 2>&1 | strings | head -n 5
echo "saved: $OUT"
