#!/usr/bin/env python3
# Dump record type descriptors from an OCF v2 (amd64) file with statically
# resolved method-table slots (simulates bbrun64 fixup, no loading).
# Usage: desc.py FILE [--all]
#   prints every marker run that looks like a record descriptor:
#   marker(8xFF) + slots + size field; slots resolved via fixup groups.
import struct, subprocess, sys

def load(path):
    d = open(path, 'rb').read()
    tag, proc, hs, ms, ds, cs, vs = struct.unpack_from('<7I', d, 0)
    assert tag in (0x6F4F4346, 0x46434F6F), 'bad magic'
    return d, dict(hs=hs, ms=ms, ds=ds, cs=cs, vs=vs)

def refs_of(path):
    refs = {}
    out = subprocess.run(['python3', __file__.rsplit('/',1)[0] + '/ocf.py', 'refs', path],
                         capture_output=True, text=True).stdout
    for line in out.splitlines():
        parts = line.split()
        if len(parts) == 2:
            refs[int(parts[0], 16)] = parts[1]
    return refs

def main():
    path = sys.argv[1]
    d, h = load(path)
    hs, ms, ds, cs = h['hs'], h['ms'], h['ds'], h['cs']
    meta = d[hs:hs+ms]; desc = d[hs+ms:hs+ms+ds]; code = d[hs+ms+ds:hs+ms+ds+cs]
    p = hs + ms + ds + cs

    def rnum():
        nonlocal p
        s = 0; y = 0
        b = d[p]; p += 1
        while b >= 128:
            y += (b - 128) << s; s += 7; b = d[p]; p += 1
        return (((b + 64) % 128 - 64) << s) + y

    refs = refs_of(path)
    # ref entries are END offsets: proc i spans (prev_end, own_end]
    sorted_refs = sorted(refs.items())
    def name(off):
        start = 0
        for a, n in sorted_refs:
            if start <= off < a:
                return '%s+%x' % (n, off - start)
            start = a
        return '?'

    groups = []
    for g in range(6):
        entries = []
        link = rnum()
        while link != 0:
            off = rnum()
            chain = []
            l = link; guard = 0
            while l != 0:
                guard += 1
                if guard > 100000: raise Exception('chain loop g%d' % (g + 1))
                is_code = l > 0
                abslink = l if is_code else -l
                if is_code: blk, so = 'code', abslink
                elif abslink < ms: blk, so = 'meta', abslink
                else: blk, so = 'desc', abslink - ms
                x = struct.unpack_from('<I', {'desc': desc, 'meta': meta, 'code': code}[blk], so)[0]
                t = (x >> 24) & 0xFF; n = x & 0xFFFFFF
                if n & 0x800000: n -= 0x1000000
                chain.append((blk, so, t))
                if t == 103: l = l + 8
                elif t == 104: l = 0
                else: l = n
            entries.append((off, chain))
            link = rnum()
        groups.append(entries)

    codemap = {}
    for off, chain in groups[4]:
        for blk, so, t in chain:
            codemap[(blk, so)] = off

    # find marker candidates: aligned 8xFF such that within 8..8*65 bytes there
    # is a plausible size word (4-byte, nonzero, < 1MB, followed by 4 zero bytes)
    out = []
    i = 0
    while True:
        j = desc.find(b'\xff' * 8, i)
        if j < 0: break
        i = j + 1
        if j % 8: continue
        # probe n = 1..64 slots; size field sits at j+8*(n+1); real desc has
        # id word at size+16 with low nibble in {1,5,9,0xD} (mRecord + attr*4)
        for n in range(1, 65):
            so = j + 8 * (n + 1)
            if so + 24 > len(desc): break
            size, pad = struct.unpack_from('<II', desc, so)
            idw, idhi = struct.unpack_from('<II', desc, so + 16)
            if pad == 0 and 0 < size < 0x100000 and size % 4 == 0 \
                    and idhi == 0 and (idw & 0xF) in (1, 5, 9, 0xD):
                out.append((j, n, size))
                break
    for j, n, size in out:
        tagoff = j + 8 * n
        print('desc @%#x: nslots=%d size=%#x tag=@%#x' % (j, n, size, tagoff))
        for k in range(n):
            so = j + 8 * (k + 1)
            num = n - 1 - k
            slot8 = struct.unpack_from('<Q', desc, so)[0]
            v = codemap.get(('desc', so))
            lo = slot8 & 0xFFFFFFFF
            if v is not None: s = '%-24s (code %#06x)' % (name(v), v)
            elif lo == 0x66000000: s = 'copy'
            elif lo == 0x64000000: s = 'abs(unresolved/import)'
            elif slot8 == 0: s = '0'
            else: s = 'raw=%x' % slot8
            print('  num %2d @tag-0x%02x: %s' % (num, 8 * (num + 1), s))

main()
