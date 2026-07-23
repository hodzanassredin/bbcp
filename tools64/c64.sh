#!/bin/sh
# c64.sh Module [offset [n]] — fast single-module 64-bit compile into bbcp64use.
# With offset: disassemble CodeBlk at offset (ocf.py) after compiling.
# Usage: c64.sh SystemTestT1 [0x979 [0x120]]
set -e
BBCP="$HOME/sources/bbcp"
USE="$HOME/sources/bbcp64use"
mod="$1"
cd "$BBCP"
tools64/sync-odc.sh >/dev/null 2>&1
cd "$USE"
printf '%s\n' "$mod" > /tmp/compile1.txt
echo 'DevOnce.Go64' | "$BBCP/run-dev0" 2>&1 | grep -E '== |err =|TRAP' | head -8
if [ -n "$2" ]; then
	# найти ocf модуля: подсистема = префикс имени до первой заглавной-цепочки… проще: поиск
	ocf=$(ls "$USE"/*/Code/*.ocf 2>/dev/null | while read -r f; do
		b=$(basename "$f" .ocf)
		# имя модуля = Subsystem + basename
		case "$mod" in *"$b") echo "$f"; break;; esac
	done | head -1)
	echo "ocf: $ocf"
	python3 "$BBCP/tools64/ocf.py" dis "$ocf" "$2" "$3"
fi
