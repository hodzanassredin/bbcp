#!/bin/sh
# crash.sh [--gui] [extra bbrun64 args] — прогон bbrun64 под gdb с автоматической
# локализацией краша: rip и стек мапятся на Module+0xOFFSET, точка дизассемблируется.
# Адреса между запусками плавают (ASLR) — опорные данные = смещения в модуле.
# env: BB_CONSOLE=1 BB_STANDARD_DIR выставляются автоматически (консоль по умолчанию).
set -e
BB="$HOME/sources/bbcp"
USE="$HOME/sources/bbcp64use"
MODE="--console"
if [ "$1" = "--gui" ]; then MODE=""; shift; fi
cd "$USE"
LOG=/tmp/crash64.log
rm -f "$LOG"
if [ -n "$MODE" ]; then
	(echo ''; sleep 2) | BB_CONSOLE=1 BB_STANDARD_DIR="$USE" timeout 120 gdb -batch \
		-ex run -ex 'x/1i $rip' -ex 'x/40xg $rsp' -ex 'info registers rax rbx rcx rdx rdi rsi rbp' \
		--args "$BB/Dev/Rsrc/bbrun64" $MODE "$@" > "$LOG" 2>&1 || true
else
	BB_STANDARD_DIR="$USE" timeout 120 gdb -batch \
		-ex run -ex 'x/1i $rip' -ex 'x/40xg $rsp' -ex 'info registers rax rbx rcx rdx rdi rsi rbp' \
		--args "$BB/Dev/Rsrc/bbrun64" "$@" > "$LOG" 2>&1 || true
fi
python3 - "$BB" "$USE" "$LOG" <<'EOF'
import re, sys, subprocess, os
BB, USE, LOG = sys.argv[1], sys.argv[2], sys.argv[3]
log = open(LOG).read()
mods = []
for line in log.splitlines():
    m = re.search(r'\+\s+(\S+)\s+dad=0x([0-9a-f]+)\s+ms=(\d+)\s+ds=(\d+)\s+cs=(\d+)\s+cad=0x([0-9a-f]+)', line)
    if m: mods.append((m.group(1), int(m.group(6),16), int(m.group(5))))
def owner(a):
    for name,cad,cs in mods:
        if cad <= a < cad+cs: return name, a-cad
    return None, None
m3 = re.search(r'\n0x([0-9a-f]+) in \?\?', log)
if not m3:
    print("краша нет; последние строки лога:")
    print("\n".join(log.strip().splitlines()[-8:])); sys.exit(0)
crash = int(m3.group(1),16)
name, off = owner(crash)
print(f"CRASH rip={hex(crash)}  in {name}+0x{off:x}" if name else f"CRASH rip={hex(crash)} (вне модулей)")
for line in log.splitlines():
    if '=>' in line: print("  " + line.strip())
    if re.match(r'(rax|rbx|rcx|rdx|rdi|rsi|rbp)\s', line): print("  " + line.strip())
seen=set(); print("  стек (code refs):")
for line in log.splitlines():
    mm = re.match(r'0x[0-9a-f]+:\s+(0x[0-9a-f]+)\s+(0x[0-9a-f]+)', line)
    if mm:
        for v in mm.groups():
            a=int(v,16); n,o = owner(a)
            if n and (n,o) not in seen:
                seen.add((n,o)); print(f"    {n}+0x{o:x}")
# дизасм точки краша
if name:
    cands = [f"{USE}/{sub}/Code/{name[len(sub):]}.ocf" for sub in ("System","Std","Text","Form","Lin","Cons","Dev") if name.startswith(sub)]
    cands.append(f"{USE}/System/Code/{name}.ocf")	# Kernel, Files и др. без префикса
    for p in cands:
        if os.path.exists(p):
            out = subprocess.run(['python3', f'{BB}/tools64/ocf.py', 'dis', p, hex(off)], capture_output=True, text=True)
            first = [l for l in out.stdout.splitlines() if l.strip().startswith(';')]
            print(f"  дизасм ({first[0][2:] if first else '?'}):")
            body = [l for l in out.stdout.splitlines() if re.match(r'\s+[0-9a-f]+:', l)]
            print("\n".join("    "+l.strip() for l in body[:6]))
            break
EOF
