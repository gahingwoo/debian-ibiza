#!/bin/bash
# Poll for ~90s after "fastboot boot": which state is the phone in?
#   cd ~/Desktop/ibiza/LOS/linuxb && bash watch_usb.sh
for i in $(seq 1 30); do
  A=$(adb devices 2>/dev/null | grep -w device | wc -l | tr -d ' ')
  F=$(fastboot devices 2>/dev/null | wc -l | tr -d ' ')
  S=$(ls /dev/cu.usbmodem* 2>/dev/null | tr '\n' ' ')
  U=$(system_profiler SPUSBDataType 2>/dev/null | grep -iE "linuxb|ibiza0001|Linux Foundation|Motorola|moto|Qualcomm" | sed 's/^ *//' | sort -u | tr '\n' '|')
  echo "t=$((i*3))s adb=$A fastboot=$F serial=[$S] usb=[$U]"
  if [ -n "$S" ] || [ "$A" != "0" ]; then break; fi
  sleep 3
done
echo "--- network adapters"; ifconfig | grep -E "^en[0-9]+:|inet 10\.55" 
echo "--- usb detail"; system_profiler SPUSBDataType 2>/dev/null | grep -B2 -A12 -iE "linuxb|ibiza0001|Linux Foundation" | head -40
