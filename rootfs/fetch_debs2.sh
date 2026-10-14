#!/bin/bash
# Run as root in ibiza-build. Downloads (does not install) the given packages against the rootfs's dpkg state into extra_debs2/.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
R=/var/tmp/ibiza-rootfs; OUT=$HERE/extra_debs2
mkdir -p $OUT; rm -f $R/var/cache/apt/archives/*.deb
mount --bind /proc $R/proc; trap 'umount $R/proc 2>/dev/null' EXIT
cp /etc/resolv.conf $R/etc/resolv.conf
chroot $R apt-get update -qq
chroot $R apt-get install -y --download-only -qq "$@"
cp $R/var/cache/apt/archives/*.deb $OUT/
rm -f $R/etc/resolv.conf; printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > $R/etc/resolv.conf
ls -l $OUT
