#!/bin/bash
# Reboot the phone, grab the kernel log as early as adb allows, and decide whether the kernel booted at EL2.
#   cd ~/Desktop/ibiza/LOS && bash check_el.sh
# Output: ~/Desktop/ibiza/boot_dmesg.txt (full early log) + a verdict. Read-only on the phone except for the reboot.
set -u
OUT="$(cd "$(dirname "$0")/.." && pwd)/boot_dmesg.txt"

verdict(){  # $1 = dmesg file
  local f="$1"
  if ! head -n 5 "$f" | grep -q '^\[ *0\.000000\]'; then
    echo "INCOMPLETE: log does not start at 0.000000 (early lines already lost). Re-run the script."; return 2; fi
  if grep -q 'All CPU(s) started at EL2' "$f"; then
    echo "EL2: kernel booted with hypervisor mode available -> KVM is worth trying (kernel rebuild needed: CONFIG_VIRTUALIZATION is off)."; return 0
  elif grep -qiE 'CPU features: .*mismatch|started at EL1 and EL2|hyp mode mismatch|Mismatched' "$f"; then
    echo "MISMATCH: CPUs started in different modes (unusual). Send me boot_dmesg.txt."; return 3
  else
    echo "EL1: complete boot log, no 'started at EL2' line -> no hypervisor mode for Linux (EL2 is held by Qualcomm's hypervisor). KVM impossible; do NOT rebuild the kernel for it."; return 1
  fi
}
if [ "${1:-}" = "--selftest" ]; then verdict "${2:?file}"; exit $?; fi
command -v adb >/dev/null || { echo "adb not found"; exit 1; }

echo "rebooting..."; adb reboot || { echo "adb reboot failed"; exit 1; }
# 1) wait until the device is really gone (avoid the race where wait-for-device returns at once)
for i in $(seq 1 60); do adb get-state >/dev/null 2>&1 || break; sleep 0.5; done
# 2) wait for it to come back, then grab dmesg as fast as possible
adb wait-for-device
ok=0
for i in $(seq 1 240); do
  if adb shell dmesg > "$OUT" 2>/dev/null && [ -s "$OUT" ]; then ok=1; break; fi
  sleep 0.5
done
[ $ok = 1 ] || { echo "could not read dmesg"; exit 1; }
lines=$(wc -l < "$OUT"); first=$(head -n 1 "$OUT" | cut -c1-80)
echo "captured $lines lines; first: $first"
echo "--- relevant lines"; grep -iE 'CPU: All|psci|hyp mode|smccc|gunyah|qhee|Booted|kvm' "$OUT" | head -20 || true
echo "--- /dev/kvm: $(adb shell 'ls /dev/kvm 2>&1' | tr -d '\r')"
echo "--- verdict"; verdict "$OUT"; rc=$?
echo "(full log saved to $OUT)"
exit $rc
