#!/usr/bin/env python3
# errpos.sh Subsystem Module POS [POS2 ...]
# Maps compiler error positions to source lines in the .odc.txt
# (compiler counts <odc-view .../> tags as 1 char).
import re, sys

sub, mod = sys.argv[1], sys.argv[2]
path = '/home/hodza/sources/bbcp/%s/Mod/%s.odc.txt' % (sub, mod)
txt = open(path).read()
flat = re.sub(r'<odc-view [^>]*/>', '\x01', txt)
lines = txt.split('\n')
for a in sys.argv[3:]:
    pos = int(a, 0)
    line = flat[:pos].count('\n') + 1
    ctx = flat[max(0, pos - 100):pos + 100].replace('\x01', '<V>').replace('\n', ' | ')
    print('--- pos %d (line %d):' % (pos, line))
    print(ctx)
    print()
