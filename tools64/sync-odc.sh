#!/bin/sh
# Import all *.odc.txt that are newer than their .odc (or missing .odc)
# back into .odc via OdcTextU.Batch, running in the 64-bit world itself
# (console mode). Хост bbcb2 больше не нужен. Все .odc.txt — UTF-8
# (KB/OdcTextUtf8.md). Формат batch-файла: строки I "in.txt" "out.odc".
. "$(dirname "$0")/env64.sh"
BATCH=/tmp/odc-batch.txt
rm -f "$BATCH"
n=0
for txt in "$BB"/Mod64/*.odc.txt "$BB"/*/Mod/*.odc.txt; do
	[ -e "$txt" ] || continue
	odc="${txt%.txt}"
	if [ ! -e "$odc" ] || [ "$txt" -nt "$odc" ]; then
		printf 'I "%s" "%s"\n' "$txt" "$odc" >> "$BATCH"
		echo "sync: $txt"
		n=$((n + 1))
	fi
done
if [ "$n" -gt 0 ]; then
	if [ ! -f "$USE/Odc/Code/TextU.ocf" ]; then
		echo "sync-odc: мир не собран (нет Odc/Code/TextU.ocf)." >&2
		echo "  В git .odc всегда свежие: откатите .odc.txt (git checkout) или" >&2
		echo "  соберите мир (test64.sh), затем повторите." >&2
		rm -f "$BATCH"
		exit 1
	fi
	out=$(cd "$USE" && echo 'OdcTextU.Batch' | BB_CONSOLE=1 BB_STANDARD_DIR="$USE" \
		timeout -k 5 300 "$BB/Dev/Rsrc/bbrun64" --console 2>&1)
	done_n=$(printf '%s\n' "$out" | grep -c '^Done! res:  0$' || true)
	printf '%s\n' "$out" | grep -iv '^Done! res:  0$' | grep -i 'fail\|not found\|bad \|error\|TRAP\|HALT' | head -5
	rm -f "$BATCH"
	if [ "$done_n" != "$n" ]; then
		echo "sync-odc: imported $done_n of $n — FAILED" >&2
		exit 1
	fi
	echo "sync-odc: $n file(s) ok"
else
	echo "nothing to sync"
fi
