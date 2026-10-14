import sys,os,struct,zipfile,gzip,hashlib
HERE=os.path.dirname(os.path.abspath(__file__)); LOS=os.path.dirname(HERE); ROOT=os.path.dirname(LOS)
BOOT=os.path.join(LOS,'boot.img'); APK=os.path.join(ROOT,'magisk','Magisk-v30.7.apk'); OUT=os.path.join(LOS,'images',(sys.argv[1] if len(sys.argv)>1 else 'boot_b.linux.img'))
CMD=(sys.argv[2] if len(sys.argv)>2 else '').encode()
BOOT_SHA='046d4fb3c4446599932dc372a9e9f437f9fff84ecbd631e55d77d1c723a0f8a2'
APK_SHA='e0d32d2123532860f97123d927b1bb86c4e08e6fd8a48bfc6b5bee0afae9ebd5'
def sha(p):
    h=hashlib.sha256()
    with open(p,'rb') as f:
        for c in iter(lambda:f.read(1<<20),b''): h.update(c)
    return h.hexdigest()
assert sha(BOOT)==BOOT_SHA,'boot.img checksum mismatch'; assert sha(APK)==APK_SHA,'apk checksum mismatch'
bb=zipfile.ZipFile(APK).read('lib/arm64-v8a/libbusybox.so')
init=open(os.path.join(HERE,'init'),'rb').read()
ents=[]
def add(name,mode,data=b'',rdev=(0,0)): ents.append((name,mode,data,rdev))
for d in ['bin','sbin','dev','proc','sys','tmp','run','etc','usr','usr/bin','mnt']: add(d,0o040755)
add('dev/console',0o020600,b'',(5,1)); add('dev/null',0o020666,b'',(1,3))
add('bin/busybox',0o100755,bb); add('init',0o100755,init)
add('etc/passwd',0o100644,b'root::0:0:root:/:/bin/sh\n')
# firmware files the kernel wants before the real root is mounted (cfg80211 loads regulatory.db at 1.6 s)
FWD=os.path.join(HERE,'fw')
if os.path.isdir(FWD):
    add('lib',0o040755); add('lib/firmware',0o040755)
    for f in sorted(os.listdir(FWD)): add('lib/firmware/'+f,0o100644,open(os.path.join(FWD,f),'rb').read())
buf=bytearray(); ino=1
def pad(): 
    while len(buf)%4: buf.append(0)
for n,m,d,(rmaj,rmin) in ents:
    nm=n.encode()+b'\0'
    hdr='070701'+''.join('%08X'%v for v in [ino,m,0,0,1,0,len(d),0,0,rmaj,rmin,len(nm),0])
    buf+=hdr.encode()+nm; pad(); buf+=d; pad(); ino+=1
buf+=('070701'+''.join('%08X'%v for v in [0,0,0,0,1,0,0,0,0,0,0,11,0])).encode()+b'TRAILER!!!\0'; pad()
def lz4_legacy(data):
    out=bytearray(b'\x02\x21\x4c\x18')
    for i in range(0,len(data),8<<20):
        ch=data[i:i+(8<<20)]; n=len(ch); blk=bytearray()
        if n>=15:
            blk.append(15<<4); r=n-15
            while r>=255: blk.append(255); r-=255
            blk.append(r)
        else: blk.append(n<<4)
        blk+=ch; out+=struct.pack('<I',len(blk))+blk
    return bytes(out)
rd=lz4_legacy(bytes(buf))
f=open(BOOT,'rb'); h=bytearray(f.read(4096))
assert h[:8]==b'ANDROID!' and struct.unpack('<I',h[40:44])[0]==3
ksz,=struct.unpack('<I',h[8:12]); f.seek(4096); kernel=f.read(ksz)
h[12:16]=struct.pack('<I',len(rd))
assert len(CMD)<1536
h[44:44+1536]=CMD+b'\0'*(1536-len(CMD))
al=lambda x:(x+4095)//4096*4096
out=bytes(h)+kernel+b'\0'*(al(ksz)-ksz)+rd
out+=b'\0'*(al(len(out))-len(out))
assert len(out)<0x6000000
open(OUT,'wb').write(out)
print('kernel',ksz,'ramdisk(gz)',len(rd),'total',len(out)); print('sha256',sha(OUT))
