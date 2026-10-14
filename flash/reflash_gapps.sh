#!/bin/bash
# Flash GApps-injected product_a + system_ext_a (slot A only; bootloader/firmware/slot B untouched).
#   cd ~/Desktop/ibiza/LOS && bash reflash_gapps.sh            (keep data)
#   cd ~/Desktop/ibiza/LOS && WIPE=1 bash reflash_gapps.sh     (also erase userdata+metadata; recommended, first boot grants GApps default permissions)
# ROLLBACK to the no-GApps state: bash reflash_product.sh  and flash system_ext.img (original) with fastboot in fastbootd.
set -u
cd "$(dirname "$0")/images" || exit 1
die(){ echo "ERROR: $*" >&2; exit 1; }
run(){ echo "+ $*"; "$@" || die "failed: $*"; }
command -v fastboot >/dev/null || die "fastboot not found"
shasum -a 256 -c SHA256SUMS.gapps || die "checksum failed (run build_gapps.sh first)"
if adb devices 2>/dev/null | grep -qw device; then run adb reboot fastboot
else fastboot devices | grep -q . || die "no adb or fastboot device"; run fastboot reboot fastboot; fi
for i in $(seq 1 30); do fastboot getvar is-userspace 2>&1 | grep -qi "is-userspace: yes" && break; sleep 2; done
fastboot getvar is-userspace 2>&1 | grep -i "is-userspace"
fastboot getvar current-slot 2>&1 | grep -i "current-slot"
read -r -p "current-slot must be 'a' and is-userspace 'yes'. Type yes to flash product_a + system_ext_a: " ans
[ "$ans" = "yes" ] || die "aborted"
run fastboot flash system_ext_a system_ext.gapps.img
run fastboot flash product_a product.gapps.img
if [ "${WIPE:-0}" = "1" ]; then run fastboot erase userdata; run fastboot erase metadata; fi
run fastboot reboot
echo "Done. Wait ~3 minutes, then:  adb devices ; adb shell getprop sys.boot_completed"
