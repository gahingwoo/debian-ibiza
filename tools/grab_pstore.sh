#!/bin/bash
# After the phone has rebooted into Android, pull the previous boot's console (pstore) to the Mac.
# Do NOT reboot the phone a second time before running this.
#   cd ~/Desktop/ibiza/LOS/linuxb && bash grab_pstore.sh
set -u
D="$(cd "$(dirname "$0")/.." && pwd)/../pstore_$(date +%H%M%S)"; mkdir -p "$D"
echo "waiting for adb..."; adb wait-for-device
for i in $(seq 1 60); do [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && break; sleep 3; done
adb root >/dev/null 2>&1; adb wait-for-device; sleep 2
for f in console-ramoops-0 pmsg-ramoops-0; do adb exec-out "cat /sys/fs/pstore/$f" > "$D/$f" 2>/dev/null; done
adb shell "ls -la /sys/fs/pstore; cat /proc/cmdline" > "$D/info.txt" 2>&1
ls -la "$D"
echo "--- console: first lines"; head -n 8 "$D/console-ramoops-0" | cut -c1-160
echo "--- console: keywords"; grep -aiE "linuxb|panic|Oops|BUG:|dwc3|udc|usb|Unable to mount|Failed to execute|Run /init|Freeing unused|Kernel command line" "$D/console-ramoops-0" | tail -n 40 | cut -c1-200
echo "--- pmsg: linuxb lines"; strings "$D/pmsg-ramoops-0" | grep -i linuxb | tail -n 20
echo "saved in $D"
