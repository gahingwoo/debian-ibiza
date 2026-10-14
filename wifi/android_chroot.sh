#!/bin/sh
# Build a writable Android root in RAM (overlayfs over the read-only system_a; nothing is written to any partition) at /android.
# Needs /mnt/system_a and /mnt/vendor_a mounted ro (see andr1.sh) and /root/apex_rt/apex_payload.img (runtime APEX).
set -u
A=/android
mkdir -p /run/android/upper /run/android/work $A
if ! mountpoint -q $A; then
  mount -t overlay overlay -o lowerdir=/mnt/system_a,upperdir=/run/android/upper,workdir=/run/android/work $A || exit 1
fi
mountpoint -q $A/vendor || mount --bind /mnt/vendor_a $A/vendor
mkdir -p $A/apex/com.android.runtime
if ! mountpoint -q $A/apex/com.android.runtime; then
  [ -b /dev/loop3 ] || mknod /dev/loop3 b 7 3
  losetup -d /dev/loop3 2>/dev/null; losetup -r /dev/loop3 /root/apex_rt/apex_payload.img
  mount -o ro /dev/loop3 $A/apex/com.android.runtime
fi
mountpoint -q $A/proc || mount -t proc proc $A/proc
mountpoint -q $A/sys || mount --rbind /sys $A/sys
mountpoint -q $A/dev || mount --bind /dev $A/dev
mkdir -p $A/dev/socket $A/data $A/mnt/vendor
mountpoint -q $A/data || mount -t tmpfs tmpfs $A/data
mkdir -p $A/data/vendor/wifi/sockets $A/mnt/vendor/persist
echo "android root ready: $(ls $A/apex/com.android.runtime | tr '\n' ' ')"
