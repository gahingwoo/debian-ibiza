#!/bin/bash
# Re-flash ONLY the product partition (slot A) with the fixed headless setup.
# Put the phone in bootloader fastboot first (power off, then hold Vol Down + Power), plug in.
# Run:  export ADB_VENDOR_KEYS=$HOME/Desktop/ibiza/adbkeys/adbkey
#       cd ~/Desktop/ibiza/LOS && bash reflash_product.sh          (keep data)
#       cd ~/Desktop/ibiza/LOS && WIPE=1 bash reflash_product.sh   (also wipe userdata, cleanest test)
set -u
cd "$(dirname "$0")/images" || exit 1
die(){ echo "ERROR: $*" >&2; exit 1; }
run(){ echo "+ $*"; "$@" || die "failed: $*"; }
command -v fastboot >/dev/null || die "fastboot not found"
shasum -a 256 -c SHA256SUMS 2>&1 | grep -E "product.img" || die "product.img checksum failed"
fastboot devices | grep -q . || die "no fastboot device"
run fastboot set_active a
run fastboot reboot fastboot
echo "waiting 15s for fastbootd..."; sleep 15
fastboot getvar is-userspace 2>&1 | grep -i "is-userspace"
run fastboot flash product_a product.img
if [ "${WIPE:-0}" = "1" ]; then run fastboot erase userdata; run fastboot erase metadata; fi
run fastboot reboot
echo "Done. Wait ~3 minutes, then:  adb devices"
