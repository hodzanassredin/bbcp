#!/bin/sh
# Долинковать недостающие .osf из 32-битного дерева bbcp в bbcp64use.
# Sym-файлы portable (размеры вычисляются при импорте под processor),
# поэтому 32-битные .osf годятся для 64-битной компиляции.
# test64.sh делает rm */Sym/*.osf — поэтому вызывать после каждой пересборки.
set -e
BB="$HOME/sources/bbcp"
USE="$HOME/sources/bbcp64use"
n=0
for d in "$USE"/*/Sym; do
	sub=$(basename "$(dirname "$d")")
	src="$BB/$sub/Sym"
	[ -d "$src" ] || continue
	for f in "$src"/*.osf; do
		[ -e "$f" ] || continue
		b=$(basename "$f")
		if [ ! -e "$d/$b" ]; then ln -s "$f" "$d/$b"; n=$((n+1)); fi
	done
done
echo "link-sym: linked $n"
