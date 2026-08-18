#!/bin/sh
# dev1.sh DevModule... — итеративная компиляция Dev-модулей в мир bbcp64use
# без полного build-dev64.sh. Прячет ТОЛЬКО Dev/Code (64-битные ocf ломают
# dev0: "corrupted code file"), Dev/Sym остаётся — импорты разрешаются,
# свежие osf/ocf сливаются обратно. Источники .odc.txt сначала sync-odc.
. "$(dirname "$0")/env64.sh"
"$BB/tools64/sync-odc.sh" >/dev/null 2>&1 || true
STASH="$USE/.devcode-stash-$$"
cleanup() {
	# без set -e: при ошибках компиляции ocf может не быть — всё равно восстановить
	cp "$USE/Dev/Code"/*.ocf "$STASH/" 2>/dev/null || true
	rm -rf "$USE/Dev/Code"
	mv "$STASH" "$USE/Dev/Code" 2>/dev/null || true
}
mv "$USE/Dev/Code" "$STASH" || { echo "dev1: нет $USE/Dev/Code" >&2; exit 1; }
mkdir -p "$USE/Dev/Code"
trap cleanup EXIT
# .odc правленных модулей — в мир (там копии от build-dev64, иначе компилируется старьё)
for m in "$@"; do
	b="${m#Dev}"
	if [ -f "$BB/Dev/Mod/$b.odc" ]; then cp -f "$BB/Dev/Mod/$b.odc" "$USE/Dev/Mod/$b.odc"; fi
done
cd "$USE"
printf '%s\n' "$@" > /tmp/compile1.txt
echo 'DevOnce.Go64' | "$BB/run-dev0" 2>&1 | grep -E 'compiling|err =|ERROR|mismatch|cannot open|FP249' | head -40 || true
