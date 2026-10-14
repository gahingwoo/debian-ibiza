#!/bin/bash
export ADB_VENDOR_KEYS=$HOME/Desktop/ibiza/adbkeys/adbkey
cd "$(dirname "$0")"
adb shell 'gsi_tool wipe 2>&1 | tail -n 1'
adb push system.img.gz /sdcard/Download/ibiza_dsu.gz | tail -n 1
adb shell 'am force-stop com.android.dynsystem; sleep 2; am start-activity -n com.android.dynsystem/com.android.dynsystem.VerificationActivity -a android.os.image.action.START_INSTALL -d file:///sdcard/Download/ibiza_dsu.gz --el KEY_SYSTEM_SIZE 16777216 --el KEY_USERDATA_SIZE 536870912 >/dev/null'
for i in $(seq 1 40); do sleep 3; s=$(adb shell 'gsi_tool status' | tr '\n' ' '); case "$s" in installed*) break;; esac; done
echo "status: $s"
adb shell 'gsi_tool enable -s 2>&1 | tail -n 1'
adb reboot
echo rebooting
