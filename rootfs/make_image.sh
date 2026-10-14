#!/bin/bash
# Run as root in ibiza-build. Builds a 4 GiB ext4 image from /var/tmp/ibiza-rootfs and a sparse copy for fastboot.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
R=/var/tmp/ibiza-rootfs; RAW=/var/tmp/ibiza-root.raw; OUT=$HERE/ibiza-root.sparse.img
command -v img2simg >/dev/null || apt-get install -y -qq android-sdk-libsparse-utils
rm -f $RAW; truncate -s 4294967296 $RAW
mke2fs -t ext4 -b 4096 -m 1 -L ibiza-root -E root_owner=0:0 -d $R $RAW
e2fsck -fn $RAW
img2simg $RAW $OUT
ls -l $OUT
