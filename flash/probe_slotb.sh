#!/bin/bash
# Read-only probe of slot B state and partition sizes. Writes nothing to the phone.
#   cd ~/Desktop/ibiza/LOS && bash probe_slotb.sh
# Output: ../slotb_probe.txt . The phone ends up booting back into the current slot.
set -u
OUT="$(cd "$(dirname "$0")/.." && pwd)/slotb_probe.txt"
command -v fastboot >/dev/null || { echo "fastboot not found"; exit 1; }
gv(){ printf '%s = ' "$1"; fastboot getvar "$1" 2>&1 | grep -iE "^$1:|^\(bootloader\)" | head -1 | sed 's/^(bootloader) *//'; }
if adb devices 2>/dev/null | grep -qw device; then adb reboot bootloader; fi
for i in $(seq 1 30); do fastboot devices | grep -q . && break; sleep 2; done
fastboot devices | grep -q . || { echo "no fastboot device"; exit 1; }
{
echo "=== bootloader fastboot"
for v in current-slot slot-count unlocked secure version-bootloader slot-successful:a slot-successful:b slot-unbootable:a slot-unbootable:b slot-retry-count:a slot-retry-count:b partition-size:boot_a partition-size:boot_b partition-size:vendor_boot_a partition-size:vendor_boot_b partition-size:dtbo_b partition-size:vbmeta_b partition-size:super; do gv $v; done
} > "$OUT" 2>&1
fastboot reboot fastboot >/dev/null 2>&1
for i in $(seq 1 30); do sleep 2; fastboot getvar is-userspace 2>&1 | grep -q "is-userspace: yes" && break; done
{
echo "=== fastbootd"
for v in is-userspace super-partition-name snapshot-update-status is-logical:system_b partition-size:system_a partition-size:system_b partition-size:product_b partition-size:vendor_b partition-size:system_ext_b partition-type:system_b; do gv $v; done
} >> "$OUT" 2>&1
fastboot reboot >/dev/null 2>&1
cat "$OUT"
echo "saved to $OUT ; phone is rebooting into its current slot"
