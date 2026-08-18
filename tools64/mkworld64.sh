#!/bin/sh
# Создаёт скелет мира bbcp64use с нуля (идемпотентно):
# <Sub>/{Code,Sym} — настоящие каталоги, Mod/Docu/Rsrc — симлинки в bbcp.
# Dev не создаём: его структуру строит build-dev64.sh (rm -rf + пересоздание).
# После mkworld64.sh: test64.sh System Lin Std Text Form Cons Obx
. "$(dirname "$0")/env64.sh"
mkdir -p "$USE"
ln -sfn "$BB/Docu" "$USE/Docu"
for sub in Comm Cons Fig Form Lin Obx Odc Std System Text; do
	mkdir -p "$USE/$sub/Code" "$USE/$sub/Sym"
	for part in Mod Docu Rsrc; do
		[ -e "$BB/$sub/$part" ] && ln -sfn "$BB/$sub/$part" "$USE/$sub/$part"
	done
done
echo "world skeleton ok: $USE"
