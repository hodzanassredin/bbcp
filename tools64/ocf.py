#!/usr/bin/env python3
# OCF v2 (amd64) parser: header, refs (proc names + code offsets), disasm helper.
# Usage:
#   ocf.py hdr FILE
#   ocf.py refs FILE [target_off_hex]     - list procs; with target: show enclosing proc
#   ocf.py dis FILE OFF [N]               - objdump N bytes of CodeBlk at OFF (hex ok)
#   ocf.py bytes FILE OFF [N]             - hex dump of CodeBlk at OFF
import struct, subprocess, sys

def load(path):
    d = open(path, 'rb').read()
    tag, proc, hs, ms, ds, cs, vs = struct.unpack_from('<7I', d, 0)
    assert tag in (0x6F4F4346, 0x46434F6F), 'bad magic'
    return d, dict(proc=proc, hs=hs, ms=ms, ds=ds, cs=cs, vs=vs)

def code_block(d, h):
    return d[h['hs'] + h['ms'] + h['ds']: h['hs'] + h['ms'] + h['ds'] + h['cs']]

def parse_refs(d, h):
    meta = d[h['hs']: h['hs'] + h['ms']]
    p = 0
    procs = []

    def getch():
        nonlocal p
        c = meta[p]; p += 1
        return c

    def refnum():
        s = 0; n = 0
        ch = getch()
        while ch >= 128:
            n += (ch - 128) << s; s += 7; ch = getch()
        return n + ((ch % 64) - (ch // 64) * 64) * (1 << s)

    def refname():
        nonlocal p
        e = meta.index(b'\x00', p)
        s = meta[p:e].decode('utf8', 'replace'); p = e + 1
        return s

    while p < len(meta) - 1:
        ch = meta[p]
        if ch >= 0xFD:          # variable entries: skip
            p += 1
            ch2 = getch()
            if ch2 == 0x10: p += 4
            refnum(); refname()
        elif 0 < ch < 0xFC:     # source refs
            p += 1; refnum()
        elif ch == 0xFC:        # procedure
            p += 1
            adr = refnum(); nm = refname()
            procs.append((adr, nm))
        else:
            p += 1
    procs.sort()
    return procs

def owner(procs, off):
    best = None
    # NB: ref entries are END offsets (CPE.OutRefName writes pc AFTER the proc
    # body), so proc i spans (procs[i-1].adr, procs[i].adr]; start of proc 0 = 0
    start = 0
    for adr, nm in procs:
        if start <= off < adr:
            return (start, nm)
        start = adr
    return best

def main():
    cmd, path = sys.argv[1], sys.argv[2]
    d, h = load(path)
    if cmd == 'hdr':
        print(h)
    elif cmd == 'refs':
        procs = parse_refs(d, h)
        if len(sys.argv) > 3:
            t = int(sys.argv[3], 0)
            adr, nm = owner(procs, t)
            print('%s+%#x' % (nm, t - adr))
        else:
            for adr, nm in procs:
                print('%6x  %s' % (adr, nm))
    elif cmd == 'dis':
        off = int(sys.argv[3], 0)
        n = int(sys.argv[4], 0) if len(sys.argv) > 4 else 0x120
        cb = code_block(d, h)
        tmp = '/tmp/ocf_dis.bin'
        open(tmp, 'wb').write(cb)
        try: procs = parse_refs(d, h)
        except Exception: procs = []	# refs могут не парситься — дизасм всё равно отдаём
        out = subprocess.run(['objdump', '-D', '-b', 'binary', '-m', 'i386:x86-64',
                              '--start-address=%d' % off, '--stop-address=%d' % (off + n),
                              '-M', 'att', tmp], capture_output=True, text=True).stdout
        if procs:
            adr, nm = owner(procs, off)
            print('; %s+%#x' % (nm, off - adr))
        print(out)
    elif cmd == 'bytes':
        off = int(sys.argv[3], 0)
        n = int(sys.argv[4], 0) if len(sys.argv) > 4 else 32
        cb = code_block(d, h)
        print(' '.join('%02x' % b for b in cb[off:off + n]))

main()
