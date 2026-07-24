#!/bin/sh
# Compile modules (args or /tmp/compile1.txt) as amd64 into bbcp64use.
# Usage: go64.sh Kernel64 LinFiles ...
# bbcp64use/Dev на время прячем: 64-битные DevCP*.ocf ломают dev0
# ("corrupted code file"). Для модулей Dev* использовать build-dev64.sh!
# Делает sync-odc (.odc.txt -> .odc) и проверяет, что ocf реально обновился.
set -e
BB="$HOME/sources/bbcp"
USE="$HOME/sources/bbcp64use"
MARK=$(mktemp)
for m in "$@"; do
	case "$m" in
		Dev*) echo "go64.sh: для Dev* используйте build-dev64.sh" >&2; exit 1;;
		System*|Std*|Text*|Form*|Lin*|Cons*|Obx*|Sql*|Xhtml*|Crypto*|Keep*|Lists*|Async*|Http*|Json*|Mcp*|Llm*|Hr*|Fjson*|Hyper*|Eds*|Fig*|Babel*|Coco*|Comm*|Cpc*|Aos*|Co_*|Kernel64) ;;
		*) # голое имя допустимо только для модулей System/Mod/<name>.odc*
			if [ ! -e "$BB/System/Mod/$m.odc" ] && [ ! -e "$BB/System/Mod/$m.odc.txt" ]; then
				echo "go64.sh: '$m' — имя должно быть ПОЛНЫМ (LinFiles, не Files)" >&2; exit 1
			fi;;
	esac
done
"$BB/tools64/sync-odc.sh" >/dev/null 2>&1
touch "$MARK"
STASH="$USE/.dev-stash-go64"
[ -d "$USE/Dev" ] && mv "$USE/Dev" "$STASH"
trap '[ -d "$STASH" ] && mv "$STASH" "$USE/Dev"; rm -f "$MARK"' EXIT
cd "$USE"
[ $# -gt 0 ] && printf '%s\n' "$@" > /tmp/compile1.txt
echo 'DevOnce.Go64' | "$BB/run-dev0"
# проверка: ocf обновился с момента запуска?
fail=0
for m in "$@"; do
	ocf=$(ls "$USE"/*/Code/*.ocf 2>/dev/null | while read -r f; do
		b=$(basename "$f" .ocf); sub=$(basename "$(dirname "$(dirname "$f")")")
		if [ "$sub$b" = "$m" ]; then echo "$f"; break; fi
		if [ "$sub" = "System" ] && [ "$b" = "$m" ]; then echo "$f"; break; fi
	done | head -1)
	if [ -z "$ocf" ]; then echo "go64.sh: $m — ocf не найден" >&2; fail=1
	elif [ ! "$ocf" -nt "$MARK" ]; then echo "go64.sh: $m — ocf НЕ обновился!" >&2; fail=1; fi
done
[ $fail -eq 0 ]
