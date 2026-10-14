#!/bin/bash
# Flash LineageOS 24 (ibiza, 20261011) with fastboot only - no recovery menu needed.
# Run from the LOS folder:  cd ~/Desktop/ibiza/LOS && bash flash_los.sh
# Phone must already be in bootloader fastboot mode (Vol Down + Power) and plugged in.
# Everything goes to slot A. Slot B is left untouched.
# product.img has the headless first-boot setup injected (adb key + adb on + skip wizard).
# vendor_boot.permissive.img = LOS vendor_boot + androidboot.selinux=permissive.
set -u
cd "$(dirname "$0")/images" || exit 1

die(){ echo "ERROR: $*" >&2; exit 1; }
ask(){ read -r -p "$1 [type yes] " a; [ "$a" = "yes" ] || die "aborted"; }
run(){ echo "+ $*"; "$@" || die "failed: $*"; }

command -v fastboot >/dev/null || die "fastboot not found. Install: brew install android-platform-tools"

echo "== 1/6 checking image files"
shasum -a 256 -c SHA256SUMS || die "image checksum mismatch"

echo "== 2/6 device state (read-only)"
fastboot devices | grep -q . || die "no fastboot device. Put the phone in fastboot mode and replug."
fastboot getvar all > ../getvar_all.txt 2>&1
# show only non-identifying lines
grep -i -E "product|unlocked|securestate|current-slot|slot-count|version-bootloader|version-baseband|fingerprint|is-userspace|max-download|super-partition|slot-successful|slot-unbootable" ../getvar_all.txt | grep -v -i -E "serial|imei|meid" 
echo
echo "Full getvar saved to ../getvar_all.txt (contains serial/IMEI - do not share unredacted)."
echo "Expect: product ibiza, bootloader unlocked, current-slot a or b."
ask "Does this look right (ibiza, unlocked)?"

echo "== 3/6 bootloader-mode flashes (slot A) - this WIPES the system, not firmware"
ask "Continue?"
run fastboot set_active a
run fastboot --disable-verity --disable-verification flash vbmeta_a vbmeta.img
run fastboot --disable-verity --disable-verification flash vbmeta_system_a vbmeta_system.img
run fastboot flash boot_a boot.img
run fastboot flash vendor_boot_a vendor_boot.permissive.img
run fastboot flash dtbo_a dtbo.img

echo "== 4/6 reboot into fastbootd (userspace fastboot) - screen is off, this is normal"
run fastboot reboot fastboot
echo "waiting 15s for fastbootd..."; sleep 15
fastboot getvar is-userspace 2>&1 | grep -i "is-userspace"
ask "Does it say is-userspace: yes?"

echo "== 5/6 rebuild super and flash logical partitions"
run fastboot wipe-super super_empty.img
run fastboot flash product_a product.img
run fastboot flash system_a system.img
run fastboot flash system_ext_a system_ext.img
run fastboot flash vendor_a vendor.img
run fastboot set_active a

echo "== 6/6 wipe userdata and reboot"
ask "Wipe userdata + metadata now?"
run fastboot -w
run fastboot reboot
echo
echo "Done. First boot takes a few minutes. Then:  adb devices   (use the key in ../../adbkeys)"
