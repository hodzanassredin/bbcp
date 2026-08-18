#!/bin/sh
# errors64.sh Subsystem... — компилирует КАЖДЫЙ модуль подсистем по отдельности
# (DevCompiler64.CompileThis не останавливается на ошибках, в отличие от
# CompileSubs) и собирает все err-позиции в один отчёт.
# Запускать ПОСЛЕ test64.sh (нужны свежие osf зависимостей).
# Перевод позиций в строки: tools64/errpos.sh Sub Mod POS
set -e
. "$(dirname "$0")/env64.sh"
STASH="$USE/.dev-stash-err64"
[ -d "$USE/Dev" ] && mv "$USE/Dev" "$STASH"
trap '[ -d "$STASH" ] && mv "$STASH" "$USE/Dev"' EXIT
cmds=""
for sub in "$@"; do
	for odc in "$BB/$sub/Mod"/*.odc; do
		[ -e "$odc" ] || continue
		b=$(basename "$odc" .odc)
		case "$b" in *__*|*64_disabled) continue;; esac
		cmds="$cmds
DevCompiler64.CompileThis $sub$b"
	done
done
cd "$USE"
echo "$cmds" | "$BB/run-dev0" 2>&1 | grep -B1 'err = \|errors detected' | grep -v '^--$'
