#!/usr/bin/env python3
# errpos.sh Subsystem Module POS [POS2 ...]
# Maps compiler error positions to source lines in the .odc.txt
# (compiler counts <odc-view .../> tags as 1 char; ODC line end = один 0DX,
# поэтому CRLF в файле считаем за ОДИН символ).
import re, sys

sub, mod = sys.argv[1], sys.argv[2]
path = '/home/hodza/sources/bbcp/%s/Mod/%s.odc.txt' % (sub, mod)
raw = open(path, 'rb').read()
try:
    txt = raw.decode('utf-8')
except UnicodeDecodeError:
    txt = raw.decode('cp1251')  # часть файлов с комментариями в cp1251
flat = re.sub(r'<odc-view [^>]*/>', '\x01', txt)
flat = flat.replace('\r\n', '\n')  # 0DX 0AX в модели = один символ
lines = flat.split('\n')
for a in sys.argv[3:]:
    pos = int(a, 0)
    line = flat[:pos].count('\n') + 1
    ctx = flat[max(0, pos - 100):pos + 100].replace('\x01', '<V>').replace('\n', ' | ')
    print('--- pos %d (line %d):' % (pos, line))
    print(ctx)
    print()
