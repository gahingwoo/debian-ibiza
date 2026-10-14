#!/bin/bash
set -u
adb root >/dev/null 2>&1
adb wait-for-device
adb shell '
echo "--- pstore"; ls -la /sys/fs/pstore 2>&1
echo "--- config"; zcat /proc/config.gz 2>&1 | grep -E "LOG_BUF_SHIFT|PSTORE|RAMOOPS"
echo "--- kallsyms"; grep -E " (__boot_cpu_mode|__hyp_stub_vectors|kvm_arm_init|is_hyp_mode_available)$" /proc/kallsyms
echo "--- cmdline"; cat /proc/cmdline
echo "--- kptr"; cat /proc/sys/kernel/kptr_restrict
echo "--- dmesg bytes"; dmesg | wc -c
echo "--- cpu features"; dmesg | grep -iE "CPU features|virtualization host|hyp" | head
echo "--- kcore"; ls -la /proc/kcore
'
