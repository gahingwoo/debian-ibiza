#!/bin/bash
# Add "log_buf_len=8M" to the vendor_boot header cmdline (in place, nothing else changes) so the kernel log keeps the whole boot.
#   cd ~/Desktop/ibiza/LOS && bash flash_logbuf.sh              (build + flash vendor_boot_a)
#   cd ~/Desktop/ibiza/LOS && ROLLBACK=1 bash flash_logbuf.sh   (flash vendor_boot.permissive.img back)
set -u
LOS="$(cd "$(dirname "$0")" && pwd)"
IMG="$LOS/images"
BASE="$IMG/vendor_boot.permissive.img"; NEW="$IMG/vendor_boot.logbuf.img"
die(){ echo "ERROR: $*" >&2; exit 1; }
run(){ echo "+ $*"; "$@" || die "failed: $*"; }
command -v fastboot >/dev/null || die "fastboot not found"
[ -f "$BASE" ] || die "missing $BASE"
if [ "${ROLLBACK:-0}" = "1" ]; then F="$BASE"; NAME="permissive vendor_boot (rollback)"
else
  python3 - "$BASE" "$NEW" <<'PY' || die "build failed"
import sys,shutil,struct
src,dst=sys.argv[1:3]
shutil.copyfile(src,dst)
f=open(dst,'r+b'); h=bytearray(f.read(4096))
assert h[:8]==b'VNDRBOOT' and struct.unpack('<I',h[8:12])[0]==3
cmd=bytes(h[28:28+2048]).split(b'\0')[0]
assert b'log_buf_len' not in cmd
new=cmd+b' log_buf_len=8M'
assert len(new)<2047
h[28:28+2048]=new+b'\0'*(2048-len(new))
f.seek(0); f.write(h); f.close()
a=open(src,'rb'); b=open(dst,'rb'); off=0; diffs=[]
while True:
    x=a.read(1<<20); y=b.read(1<<20)
    if not x: break
    if x!=y: diffs+=[off+i for i in range(len(x)) if x[i]!=y[i]]
    off+=len(x)
assert diffs and max(diffs)<28+2048, "unexpected change outside header cmdline"
print("patched header cmdline only; bytes changed:",len(diffs))
print("cmdline tail:",new[-80:].decode())
PY
  F="$NEW"; NAME="vendor_boot with log_buf_len=8M"
fi
echo "sha256: $(shasum -a 256 "$F" | awk '{print $1}')"
if adb devices 2>/dev/null | grep -qw device; then run adb reboot bootloader
else fastboot devices | grep -q . || die "no adb or fastboot device"; fi
for i in $(seq 1 30); do fastboot devices | grep -q . && break; sleep 2; done
fastboot getvar current-slot 2>&1 | grep -i "current-slot"
read -r -p "Flash $NAME to vendor_boot_a? current-slot must be 'a'. Type yes: " ans
[ "$ans" = "yes" ] || die "aborted"
run fastboot flash vendor_boot_a "$F"
run fastboot reboot
echo "Done. Wait ~2 minutes for adb, then: bash check_el.sh"
