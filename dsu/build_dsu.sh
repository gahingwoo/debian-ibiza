#!/bin/bash
# Build the DSU system image (system-as-root ext4, 16 MiB) whose /system/bin/init is dsu_init. Needs the OrbStack VM ibiza-build.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
APK="$HERE/../../magisk/Magisk-v30.7.apk"          # only used for its static aarch64 busybox
rm -rf "$HERE/stage" && mkdir -p "$HERE/stage"
unzip -p "$APK" lib/arm64-v8a/libbusybox.so > "$HERE/stage/busybox"
cp "$HERE/dsu_init" "$HERE/stage/init"
orb -m ibiza-build sudo bash -c '
set -e
H='"$HERE"'; T=/var/tmp/dsu_tree; I=/var/tmp/dsu_system.img
rm -rf $T $I; mkdir -p $T/system/bin $T/system/etc
install -m 0755 $H/stage/busybox $T/system/bin/busybox
install -m 0755 $H/stage/init    $T/system/bin/init
ln -s /system/bin/init $T/init
for a in $($T/system/bin/busybox --list); do [ -e $T/system/bin/$a ] || ln -s busybox $T/system/bin/$a; done
ln -s system/bin $T/bin
ln -s system/bin $T/sbin
# same top-level mount points as the real system_a (system-as-root layout)
for d in apex bootstrap-apex bugreports cache config data data_mirror debug_ramdisk dev linkerconfig metadata mnt odm odm_dlkm oem postinstall proc product sdcard second_stage_resources storage sys system_dlkm system_ext tmp www vendor vendor_dlkm; do mkdir -p $T/$d; done
ln -s /system/etc $T/etc
truncate -s 16M $I
mke2fs -q -t ext4 -b 4096 -O ^has_journal -L system -E root_owner=0:0 -d $T $I
e2fsck -fn $I | tail -n 2
cp $I $H/system.img
'
gzip -kf "$HERE/system.img"
ls -l "$HERE/system.img" "$HERE/system.img.gz" | awk '{print $5, $9}'
shasum -a 256 "$HERE/system.img.gz" | cut -c1-16
