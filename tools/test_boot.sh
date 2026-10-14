#!/bin/bash
# One-shot test: RAM-boot the Linux image, watch USB ~100s, Linux warm-reboots itself into Android, then pull pstore.
#   cd ~/Desktop/ibiza/LOS/linuxb && bash test_boot.sh
# Nothing is written to any partition. Do not touch the phone while it runs.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; IMG="$HERE/../images/${1:-boot_b.linux4.img}"
[ -f "$IMG" ] || { echo "missing $IMG"; exit 1; }
if adb devices 2>/dev/null | grep -qw device; then adb reboot bootloader; fi
for i in $(seq 1 30); do fastboot devices | grep -q . && break; sleep 2; done
fastboot devices | grep -q . || { echo "no fastboot device"; exit 1; }
fastboot boot "$IMG" || { echo "fastboot boot failed"; exit 1; }
echo "booted; watching USB for 100s"
for i in $(seq 1 33); do
  S=$(ls /dev/cu.usbmodem* 2>/dev/null | tr '\n' ' ')
  U=$(system_profiler SPUSBDataType 2>/dev/null | grep -iE "linuxb|ibiza0001|Linux Foundation" | sed 's/^ *//' | sort -u | tr '\n' '|')
  echo "t=$((i*3))s serial=[$S] usb=[$U]"
  if [ -n "$S" ] || [ -n "$U" ]; then echo "USB device seen. If you want to stay in Linux: connect, then run: touch /tmp/stay"; fi
  sleep 3
done
ifconfig | grep -B1 "10.55" 
echo "--- waiting for Linux to warm-reboot into Android, then pulling pstore"
for i in $(seq 1 100); do adb devices 2>/dev/null | grep -qw device && break; sleep 3; done
adb devices 2>/dev/null | grep -qw device || { echo "No adb after 5 min. Phone is hung. Hold Power ~15s to force a reboot (pstore will be lost), then try again."; exit 2; }
bash "$HERE/grab_pstore.sh"
