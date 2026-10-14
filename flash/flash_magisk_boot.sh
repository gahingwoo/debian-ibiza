#!/bin/bash
# Flash the Magisk-patched LOS boot to boot_a (slot A only). Nothing else is touched.
#   cd ~/Desktop/ibiza/LOS && bash flash_magisk_boot.sh              (flash patched boot)
#   cd ~/Desktop/ibiza/LOS && ROLLBACK=1 bash flash_magisk_boot.sh   (flash the original LOS boot.img back)
# Patched file: ../magisk/boot.img  (Magisk v30.7 patch of exactly this LOS boot.img, SHA1 106b5a6a...)
set -u
LOS="$(cd "$(dirname "$0")" && pwd)"
PATCHED="$LOS/../magisk/boot.img"; ORIG="$LOS/boot.img"
PATCHED_SHA=54ced3de6e9bc324d8ea1555bc9d0c7ddd702d516728bfee227e2618bbf80f16
ORIG_SHA=046d4fb3c4446599932dc372a9e9f437f9fff84ecbd631e55d77d1c723a0f8a2
die(){ echo "ERROR: $*" >&2; exit 1; }
run(){ echo "+ $*"; "$@" || die "failed: $*"; }
command -v fastboot >/dev/null || die "fastboot not found"
if [ "${ROLLBACK:-0}" = "1" ]; then F="$ORIG"; EXP="$ORIG_SHA"; NAME="ORIGINAL LOS boot"; else F="$PATCHED"; EXP="$PATCHED_SHA"; NAME="Magisk-patched boot"; fi
[ -f "$F" ] || die "missing $F"
[ "$(shasum -a 256 "$F" | awk '{print $1}')" = "$EXP" ] || die "checksum mismatch for $F"
if adb devices 2>/dev/null | grep -qw device; then run adb reboot bootloader
else fastboot devices | grep -q . || die "no adb or fastboot device"; fi
for i in $(seq 1 30); do fastboot devices | grep -q . && break; sleep 2; done
fastboot getvar current-slot 2>&1 | grep -i "current-slot"
fastboot getvar unlocked 2>&1 | grep -i unlocked || true
read -r -p "Flash $NAME to boot_a? current-slot must be 'a'. Type yes: " ans
[ "$ans" = "yes" ] || die "aborted"
run fastboot flash boot_a "$F"
run fastboot reboot
echo "Done. Wait ~2 minutes, then:  adb devices ; adb shell getprop sys.boot_completed"
