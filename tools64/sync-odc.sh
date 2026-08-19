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
	# Cons/Mod/Compiler64.odc целенаправленно удалён (test64.sh: ConsCompiler64
	# собирает build-dev64, иначе err 249) — не считать его «ждущим синка»,
	# иначе после wipe мира (нет TextU.ocf) sync падает и тащит за собой go64.
	[ "$txt" = "$BB/Cons/Mod/Compiler64.odc.txt" ] && continue
	odc="${txt%.txt}"
	if [ ! -e "$odc" ] || [ "$txt" -nt "$odc" ]; then
		printf 'I "%s" "%s"\n' "$txt" "$odc" >> "$BATCH"
		echo "sync: $txt"
		n=$((n + 1))
	fi
done
if [ "$n" -gt 0 ]; then
	if [ ! -f "$USE/Odc/Code/TextU.ocf" ]; then
		# Мир мёртв (свежий клон или wipe в test64.sh). Если для каждого
		# txt есть .odc — это безобидно (на чистом клоне txt лишь новее
		# по mtime, содержимое то же): предупреждаем и выходим 0, чтобы
		# go64.sh компилировал имеющиеся .odc. Отсутствующий .odc — фатально.
		missing=0
		while IFS= read -r line; do
			odc="${line##*\" \"}"; odc="${odc%\"}"
			[ -e "$odc" ] || { echo "sync-odc: мир мёртв и нет $odc" >&2; missing=1; }
		done < "$BATCH"
		rm -f "$BATCH"
		if [ "$missing" -eq 0 ]; then
			echo "sync-odc: мир не собран (нет Odc/Code/TextU.ocf) — использую имеющиеся .odc ($n шт. новее по mtime)" >&2
			exit 0
		fi
		echo "sync-odc: мир не собран, а .odc отсутствуют — соберите мир (test64.sh)" >&2
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
