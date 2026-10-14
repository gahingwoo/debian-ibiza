#!/bin/bash
# Re-flash ONLY product_a with product.tight.img: ro.adb.secure=1, ro.secure=1,
# adb_keys = [adbkey.pub (Claude), mac_adbkey.pub (your Mac)]. ro.debuggable=1 kept (adb root still works).
# Data is kept. Slot B, bootloader, firmware untouched.
# ROLLBACK if adb shows "unauthorized": boot to fastboot (Vol Down + Power) and run  bash reflash_product.sh
#   (that flashes the old permissive product.img)
#   export ADB_VENDOR_KEYS=$HOME/Desktop/ibiza/adbkeys/adbkey   # only needed for the old image; new image also trusts your Mac key
#   cd ~/Desktop/ibiza/LOS && bash reflash_product_tight.sh
set -u
cd "$(dirname "$0")/images" || exit 1
die(){ echo "ERROR: $*" >&2; exit 1; }
run(){ echo "+ $*"; "$@" || die "failed: $*"; }
command -v fastboot >/dev/null || die "fastboot not found"
[ "$(shasum -a 256 product.tight.img | awk '{print $1}')" = "66ef580ac37b71d3457dc30f286f0412231385b6031356057b6265be071510d3" ] || die "product.tight.img checksum failed"
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
read -r -p "current-slot must be 'a' and is-userspace 'yes'. Type yes to flash product_a: " ans
[ "$ans" = "yes" ] || die "aborted"
run fastboot flash product_a product.tight.img
run fastboot reboot
echo "Done. Wait ~2 minutes, then (WITHOUT ADB_VENDOR_KEYS, to test your Mac key):  adb devices"
