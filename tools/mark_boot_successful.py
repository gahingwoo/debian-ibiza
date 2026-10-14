# Marks boot_a "successful" in the A/B GPT attributes of the LUN holding it (what Android boot_control does). Usage: python3 mark_boot_successful.py /dev/sdd check|apply
# Verifies primary+backup GPT CRCs first; only flips attribute bit 54 of boot_a and rewrites both tables + CRCs. Do NOT use on the LUN holding userdata with sgdisk-style tools.
import sys, struct, zlib, os
DEV = sys.argv[1]; MODE = sys.argv[2]; BS = 4096
f = open(DEV, 'r+b' if MODE == 'apply' else 'rb')
def rd(lba, n=1):
    f.seek(lba * BS); return f.read(n * BS)
def parse(hlba):
    h = bytearray(rd(hlba)[:92])
    assert h[:8] == b'EFI PART', 'bad sig at %d' % hlba
    hs, hcrc = struct.unpack('<II', h[12:20])
    cur, alt, first, last = struct.unpack('<QQQQ', h[24:56])
    elba, n, esz, ecrc = struct.unpack('<QIII', h[72:92])
    assert hs == 92 and esz == 128
    c = bytearray(h); c[16:20] = b'\0\0\0\0'
    assert zlib.crc32(bytes(c)) & 0xffffffff == hcrc, 'header crc mismatch'
    f.seek(elba * BS); ents = bytearray(f.read(n * esz))
    assert zlib.crc32(bytes(ents)) & 0xffffffff == ecrc, 'entries crc mismatch'
    return dict(h=h, hlba=hlba, cur=cur, alt=alt, elba=elba, n=n, esz=esz, ents=ents)
P = parse(1); B = parse(P['alt'])
print('primary ok: entries lba', P['elba'], 'n', P['n'], '| backup ok: hdr lba', B['hlba'], 'entries lba', B['elba'])
assert P['ents'] == B['ents'], 'primary/backup tables differ'
idx = None
for i in range(P['n']):
    e = P['ents'][i*128:(i+1)*128]
    if e[:16] == bytes(16): continue
    nm = e[56:128].decode('utf-16le').split('\0')[0]
    at = struct.unpack('<Q', e[48:56])[0]
    if nm.endswith('_a') or nm.endswith('_b'):
        print('%-16s attr=%016x prio=%d active=%d retry=%d succ=%d unboot=%d' % (nm, at, (at>>48)&3, (at>>50)&1, (at>>51)&7, (at>>54)&1, (at>>55)&1))
    if nm == 'boot_a': idx = i
if MODE == 'apply':
    for X in (P, B):
        e = bytearray(X['ents'])
        at = struct.unpack('<Q', e[idx*128+48:idx*128+56])[0]
        at |= (1 << 54); at &= ~(1 << 55)
        e[idx*128+48:idx*128+56] = struct.pack('<Q', at)
        X['new'] = bytes(e)
    for X in (B, P):  # backup first, primary last
        h = bytearray(X['h']); h[88:92] = struct.pack('<I', zlib.crc32(X['new']) & 0xffffffff)
        h[16:20] = b'\0\0\0\0'; h[16:20] = struct.pack('<I', zlib.crc32(bytes(h)) & 0xffffffff)
        f.seek(X['elba'] * BS); f.write(X['new'])
        full = bytearray(rd(X['hlba'])); full[:92] = h
        f.seek(X['hlba'] * BS); f.write(bytes(full))
        f.flush(); os.fsync(f.fileno())
    P2 = parse(1); B2 = parse(P2['alt']); print('after: both CRCs valid')
