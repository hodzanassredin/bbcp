#!/bin/sh
# Сборка Dev-пайплайна компилятора (amd64) в bbcp64use для компиляции внутри BB64.
# Порядок = по зависимостям. Запускать ПОСЛЕ test64.sh (он всё вайпит).
# bbcp64use/Dev удаляем перед компиляцией: 64-битные DevCP*.ocf ломают dev0
# ("corrupted code file"), а всё нужное (DevCommanders тоже) пересобирается ниже.
set -e
USE="$HOME/sources/bbcp64use"
BB="$HOME/sources/bbcp"
rm -rf "$USE/Dev"
mkdir -p "$USE/Dev/Code" "$USE/Dev/Sym" "$USE/Dev/Mod"
ln -sf "$BB/Dev/Mod/Commanders.odc" "$USE/Dev/Mod/Commanders.odc"
# Rsrc (меню!) и Docu — симлинки, иначе в GUI нет меню Dev
ln -sfn "$BB/Dev/Rsrc" "$USE/Dev/Rsrc"
ln -sfn "$BB/Dev/Docu" "$USE/Dev/Docu"
# copy .odc.txt files from bbcp to bbcp64use for imports (skip Commanders.odc which is already symlinked)
for f in "$BB"/Dev/Mod/*.odc.txt "$BB"/System/Mod/*.odc.txt "$BB"/Std/Mod/*.odc.txt "$BB"/Text/Mod/*.odc.txt "$BB"/Form/Mod/*.odc.txt "$BB"/Cons/Mod/*.odc.txt "$BB"/Obx/Mod/*.odc.txt; do
  [ -e "$f" ] || continue
  relpath="${f#$BB/}"
  [ "$relpath" = "Dev/Mod/Commanders.odc.txt" ] && continue
  # Dev/Mod/Compiler.odc.txt — 32-битный источник; в мире вместо него фасад
  # DevCompiler -> DevCompiler64 (bbcp/Mod64/DevCompiler.odc.txt), см. ниже
  [ "$relpath" = "Dev/Mod/Compiler.odc.txt" ] && continue
  dest="$USE/$relpath"
  [ "$f" -ef "$dest" ] && continue
  mkdir -p "$(dirname "$dest")"
  cp "$f" "$dest"
done
# DevCommanders компилируем ПЕРВЫМ: консольный хост (ConsInterp), на котором
# крутится OdcTextU.Batch, сам импортирует DevCommanders — без его ocf консоль
# не грузится ("code file for DevCommanders not found"). Dev/Code сейчас пуст,
# поэтому dev0 не спотыкается о 64-битные ocf.
cd "$USE"
printf 'DevCommanders\n' > /tmp/compile1.txt
echo 'DevOnce.Go64' | "$BB/run-dev0" | tail -1
# convert .odc.txt to .odc via OdcTextU.Batch — консольный хост самой BB64
# (UTF-8, KB/OdcTextUtf8.md). OdcTextU не зависит от Dev — работает и на
# свежевайпнутом Dev.
BATCH=/tmp/odc-batch.txt
rm -f "$BATCH"
nb=0
for f in "$USE"/Dev/Mod/*.odc.txt "$USE"/System/Mod/*.odc.txt "$USE"/Std/Mod/*.odc.txt "$USE"/Text/Mod/*.odc.txt "$USE"/Form/Mod/*.odc.txt "$USE"/Cons/Mod/*.odc.txt "$USE"/Obx/Mod/*.odc.txt; do
  [ -e "$f" ] || continue
  odc="${f%.txt}"
  printf 'I "%s" "%s"\n' "$f" "$odc" >> "$BATCH"
  nb=$((nb + 1))
done
if [ -f "$BATCH" ]; then
  out=$(cd "$USE" && echo 'OdcTextU.Batch' | BB_CONSOLE=1 BB_STANDARD_DIR="$USE" \
    timeout -k 5 600 "$BB/Dev/Rsrc/bbrun64" --console 2>&1)
  done_n=$(printf '%s\n' "$out" | grep -c '^Done! res:  0$')
  # Ошибки НЕ глушим — иначе сборка идёт по протухшим .odc.
  printf '%s\n' "$out" | grep -v '^Done! res:  0$' | grep -i 'fail\|not found\|bad \|error\|TRAP\|HALT' | head -5
  rm -f "$BATCH"
  if [ "$done_n" != "$nb" ]; then
    echo "build-dev64: odc import $done_n of $nb — FAILED" >&2
    exit 1
  fi
fi
"$BB/tools64/sync-odc.sh" || true
cd "$USE"
cat > /tmp/compile1.txt <<'LIST'
DevMarkers
DevCPM
DevCPT
DevCPB
DevCPS
DevCPP
DevCPH
DevCPE
DevCPLamd64
DevCPCamd64
DevCPVamd64
DevSelectors
DevCommanders
DevCompiler64
DevCompiler
ConsCompiler64
ObxCompileLog
LIST
# фасад DevCompiler: источник Mod64/DevCompiler.odc -> мир как Dev/Mod/Compiler.odc
cp "$BB/Mod64/DevCompiler.odc" "$USE/Dev/Mod/Compiler.odc"
echo 'DevOnce.Go64' | "$HOME/sources/bbcp/run-dev0"
