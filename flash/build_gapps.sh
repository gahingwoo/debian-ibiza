#!/bin/bash
# Build GApps-injected product/system_ext images ON THE MAC (no recovery needed).
# Run:  bash ~/Desktop/ibiza/LOS/build_gapps.sh
# Inputs : LOS/images/product.tight.img (secured adb build) and LOS/images/system_ext.img
# Outputs: LOS/images/product.gapps.img, system_ext.gapps.img, SHA256SUMS.gapps
# Source : MindTheGapps-17.0.0-arm64-20260630_115006 (github.com/MindTheGapps/17.0.0-arm64), sha256 pinned below.
# Nothing here touches the phone. Originals are only READ.
set -euo pipefail
export PATH="$PATH:/usr/sbin:/sbin:/opt/homebrew/opt/e2fsprogs/sbin:/usr/local/opt/e2fsprogs/sbin:/opt/homebrew/opt/e2fsprogs/bin:/usr/local/opt/e2fsprogs/bin"
LOS="$(cd "$(dirname "$0")" && pwd)"; IMG="$LOS/images"; W="$LOS/gapps_work"
TAG=MindTheGapps-17.0.0-arm64-20260630_115006
URL="https://github.com/MindTheGapps/17.0.0-arm64/releases/download/$TAG/$TAG.zip"
ZIP_SHA=c12792c17fba02e470b00bdfc8f1fd7677f526131c1f7333c5bd23e91042671c
TIGHT_SHA=66ef580ac37b71d3457dc30f286f0412231385b6031356057b6265be071510d3
die(){ echo "ERROR: $*" >&2; exit 1; }
sha(){ shasum -a 256 "$1" | awk '{print $1}'; }
for t in debugfs e2fsck python3 unzip curl shasum; do command -v $t >/dev/null || die "missing tool: $t  (macOS: brew install e2fsprogs)"; done
[ -f "$IMG/product.tight.img" ] && [ -f "$IMG/system_ext.img" ] || die "base images not found in $IMG"
mkdir -p "$W"

# ---- 1. free space (need both outputs + zip + tree) ----
python3 - "$IMG" <<'PY'
import shutil,sys,os
free=shutil.disk_usage(sys.argv[1]).free
need=int(os.path.getsize(sys.argv[1]+'/product.tight.img')+os.path.getsize(sys.argv[1]+'/system_ext.img')+1.6e9)
print(f"free {free/1e9:.1f} GB, need ~{need/1e9:.1f} GB")
sys.exit(0 if free>need else 1)
PY
[ $? -eq 0 ] || die "not enough free disk space"

# ---- 2. verify base images are the known-good ones ----
if [ "${SKIP_BASE_CHECK:-0}" != "1" ]; then
  echo "checking base images..."
  [ "$(sha "$IMG/product.tight.img")" = "$TIGHT_SHA" ] || die "product.tight.img hash differs from the verified one"
  exp=$(grep -E '[[:space:]]system_ext\.img$' "$IMG/SHA256SUMS" | awk '{print $1}')
  [ -n "$exp" ] && [ "$(sha "$IMG/system_ext.img")" = "$exp" ] || die "system_ext.img does not match SHA256SUMS"
fi

# ---- 3. GApps zip: download + pin hash ----
ZIP="${ZIP_LOCAL:-$W/$TAG.zip}"
if [ -z "${ZIP_LOCAL:-}" ] && [ ! -f "$ZIP" ]; then
  echo "downloading $TAG.zip (~511 MB)..."
  curl -fL --retry 3 -C - -o "$ZIP" "$URL"
fi
[ "$(sha "$ZIP")" = "$ZIP_SHA" ] || die "GApps zip sha256 mismatch (expected $ZIP_SHA)"
echo "zip sha256 OK"
rm -rf "$W/tree"; mkdir -p "$W/tree"
unzip -q -o "$ZIP" 'system/product/*' 'system/system_ext/*' -d "$W/tree"
rm -rf "$W/tree/system/product/priv-app/VelvetTitan"   # installer drops it on non-tangorpro devices
[ -d "$W/tree/system/product" ] && [ -d "$W/tree/system/system_ext" ] || die "unexpected zip layout"

# ---- 4. copy bases, generate debugfs commands, inject ----
cp "$IMG/product.tight.img" "$IMG/product.gapps.img"
cp "$IMG/system_ext.img"    "$IMG/system_ext.gapps.img"
python3 - "$W" <<'PY'
import os,sys
W=sys.argv[1]
def gen(root,out):
    dirs=set(); files=[]
    for dp,dn,fn in os.walk(root):
        rel=os.path.relpath(dp,root)
        if rel!='.': dirs.add(rel)
        for f in fn: files.append(os.path.join(rel if rel!='.' else '',f))
    c=[]
    for d in sorted(dirs,key=lambda x:(x.count('/'),x)):
        c+= [f"mkdir /{d}",f"sif /{d} mode 040755",f"sif /{d} uid 0",f"sif /{d} gid 0",f"ea_set /{d} security.selinux u:object_r:system_file:s0"]
    for f in sorted(files):
        b=os.path.basename(f); ext=b.rsplit('.',1)[-1] if '.' in b else None
        mode='0100755' if (ext is None or ext=='sh') else '0100644'
        c+= [f"write {root}/{f} /{f}",f"sif /{f} mode {mode}",f"sif /{f} uid 0",f"sif /{f} gid 0",f"ea_set /{f} security.selinux u:object_r:system_file:s0"]
    open(out,'w').write('\n'.join(c)+'\n'); print(out,len(dirs),'dirs',len(files),'files')
gen(W+'/tree/system/product',W+'/product.cmds')
gen(W+'/tree/system/system_ext',W+'/system_ext.cmds')
PY
debugfs -w -f "$W/system_ext.cmds" "$IMG/system_ext.gapps.img" > "$W/se.log" 2>&1 || true
debugfs -w -f "$W/product.cmds"    "$IMG/product.gapps.img"    > "$W/prod.log" 2>&1 || true
if grep -iE "error|no space|not enough|couldn" "$W/prod.log" "$W/se.log" | grep -vi "already exists" | grep -q .; then
  grep -iE "error|no space|not enough|couldn" "$W/prod.log" "$W/se.log" | grep -vi "already exists" | head
  die "debugfs reported errors (see gapps_work/*.log)"
fi

# ---- 5. verify: every injected file byte-for-byte, then fsck ----
python3 - "$W" "$IMG" <<'PY'
import os,sys,subprocess,hashlib
W,IMG=sys.argv[1],sys.argv[2]
def h(f):
    d=hashlib.sha256()
    with open(f,'rb') as fh:
        for b in iter(lambda:fh.read(1<<20),b''): d.update(b)
    return d.hexdigest()
bad=0
for img,root in ((IMG+'/product.gapps.img',W+'/tree/system/product'),(IMG+'/system_ext.gapps.img',W+'/tree/system/system_ext')):
    n=0
    for dp,dn,fn in os.walk(root):
        for f in fn:
            full=os.path.join(dp,f); rel='/'+os.path.relpath(full,root)
            p=subprocess.Popen(['debugfs','-R',f'cat {rel}',img],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
            d=hashlib.sha256()
            for b in iter(lambda:p.stdout.read(1<<20),b''): d.update(b)
            p.wait(); n+=1
            if d.hexdigest()!=h(full): bad+=1; print('MISMATCH',img,rel)
    print(os.path.basename(img),'files verified',n)
sys.exit(1 if bad else 0)
PY
for i in product system_ext; do e2fsck -fn "$IMG/$i.gapps.img" >"$W/fsck_$i.log" 2>&1 || { tail -5 "$W/fsck_$i.log"; die "fsck failed for $i.gapps.img"; }; tail -1 "$W/fsck_$i.log"; done

# ---- 6. checksums for the flash script ----
( cd "$IMG" && shasum -a 256 product.gapps.img system_ext.gapps.img > SHA256SUMS.gapps && cat SHA256SUMS.gapps )
echo
echo "DONE. Send me the two SHA256 lines above. You can free ~1.2 GB later with:  rm -rf '$W'"
