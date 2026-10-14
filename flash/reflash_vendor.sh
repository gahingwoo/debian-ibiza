#!/bin/bash
# Re-flash ONLY vendor_a with vendor.nolive.img (LiveDisplay sysfs HAL declarations/service removed).
# Why: vendor.lineage.livedisplay-service.sysfs aborts ("None of AdaptiveBacklight paths could be opened",
#      no panel), but its AIDL HALs are declared in VINTF, so system_server waits forever in
#      LiveDisplayService.onBootPhase -> sys.boot_completed never set -> Watchdog kills system_server.
# Data is kept (no wipe). Slot B, bootloader and firmware are not touched.
# Run (phone booted with adb, OR in bootloader fastboot):
#   export ADB_VENDOR_KEYS=$HOME/Desktop/ibiza/adbkeys/adbkey
#   cd ~/Desktop/ibiza/LOS && bash reflash_vendor.sh
set -u
cd "$(dirname "$0")/images" || exit 1
die(){ echo "ERROR: $*" >&2; exit 1; }
run(){ echo "+ $*"; "$@" || die "failed: $*"; }
command -v fastboot >/dev/null || die "fastboot not found"
[ "$(shasum -a 256 vendor.nolive.img | awk '{print $1}')" = "fbd36ee68e3d59c107b21a2c2ea8b694a8f05e54b13432494b65efd3e1c55036" ] || die "vendor.nolive.img checksum failed"
if adb devices 2>/dev/null | grep -qw device; then
  echo "adb device found -> rebooting to fastbootd"; run adb reboot fastboot
else
  fastboot devices | grep -q . || die "no adb or fastboot device"
  run fastboot reboot fastboot
fi
echo "waiting for fastbootd..."
for i in $(seq 1 30); do
  fastboot getvar is-userspace 2>&1 | grep -qi "is-userspace: yes" && break
  sleep 2
done
fastboot getvar is-userspace 2>&1 | grep -i "is-userspace"
fastboot getvar current-slot 2>&1 | grep -i "current-slot"
read -r -p "current-slot must be 'a' and is-userspace 'yes'. Type yes to flash vendor_a: " ans
[ "$ans" = "yes" ] || die "aborted"
run fastboot flash vendor_a vendor.nolive.img
run fastboot reboot
echo "Done. Wait ~2 minutes, then:  adb devices ; adb shell getprop sys.boot_completed"
