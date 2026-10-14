#!/bin/bash
# Stage 1: boot a RAM-only Linux from slot B. Writes ONLY boot_b, vendor_boot_b, dtbo_b, vbmeta_b, then switches the active slot to b.
# Slot A, super and userdata are not touched.
#   cd ~/Desktop/ibiza/LOS && bash flash_linuxb.sh            flash slot B and boot Linux
#   cd ~/Desktop/ibiza/LOS && BACK=1 bash flash_linuxb.sh     set slot A active again and boot Android (phone must be in fastboot or adb)
# After flashing, connect over USB: Mac gets a new "NCM" ethernet adapter; DHCP gives 10.55.0.x; telnet 10.55.0.2
# Blind rescue: hold Power ~10s to power off, then hold Vol-Down + Power to reach the bootloader, then BACK=1 bash flash_linuxb.sh
set -u
LOS="$(cd "$(dirname "$0")" && pwd)"; IMG="$LOS/images"
die(){ echo "ERROR: $*" >&2; exit 1; }
run(){ echo "+ $*"; "$@" || die "failed: $*"; }
command -v fastboot >/dev/null || die "fastboot not found"
tobl(){
  if adb devices 2>/dev/null | grep -qw device; then run adb reboot bootloader; fi
  for i in $(seq 1 30); do fastboot devices | grep -q . && break; sleep 2; done
  fastboot devices | grep -q . || die "no fastboot device (hold Vol-Down + Power to enter the bootloader)"
}
chk(){ [ "$(shasum -a 256 "$1" | awk '{print $1}')" = "$2" ] || die "checksum mismatch: $1"; }
if [ "${BACK:-0}" = "1" ]; then
  tobl
  run fastboot set_active a
  run fastboot reboot
  echo "Slot A active again. Android should come up in ~2 minutes."; exit 0
fi
BOOTB="$IMG/boot_b.linux.img"
chk "$LOS/vendor_boot.img" 031a305633d949f7c61e25341fb7c3c29646e341ece86ec16e094e6cda8501d1
chk "$LOS/dtbo.img" cc70e7f3fdbaadaa09a18a86452edfec3b7c54dcd33232313989a93fe2947852
chk "$LOS/vbmeta.img" e83df43b52b7faf6cd5c43d03843271a7f2a3ab61f8affdda9cace00e5add283
chk "$BOOTB" 9a43bcabd71ff0b0ece2b2e9ed338d58d72fe5dd664e52e9a58349d500da7382
tobl
fastboot getvar current-slot 2>&1 | grep -i current-slot
read -r -p "Write boot_b, vendor_boot_b, dtbo_b, vbmeta_b and make slot B active? current-slot must be 'a'. Type yes: " ans
[ "$ans" = "yes" ] || die "aborted"
run fastboot --disable-verity --disable-verification flash vbmeta_b "$LOS/vbmeta.img"
run fastboot flash dtbo_b "$LOS/dtbo.img"
run fastboot flash vendor_boot_b "$LOS/vendor_boot.img"
run fastboot flash boot_b "$BOOTB"
run fastboot set_active b
run fastboot reboot
echo "Booting slot B. Plug USB into the Mac, wait ~1 minute, then: telnet 10.55.0.2"
