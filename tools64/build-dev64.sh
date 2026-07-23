#!/bin/sh
# Сборка Dev-пайплайна компилятора (amd64) в bbcp64use для компиляции внутри BB64.
# Порядок = по зависимостям. Запускать ПОСЛЕ test64.sh (он всё вайпит).
# bbcp64use/Dev удаляем перед компиляцией: 64-битные DevCP*.ocf ломают dev0
# ("corrupted code file"), а всё нужное (DevCommanders тоже) пересобирается ниже.
set -e
USE="$HOME/sources/bbcp64use"
rm -rf "$USE/Dev"
mkdir -p "$USE/Dev/Code" "$USE/Dev/Sym" "$USE/Dev/Mod"
ln -sf "$HOME/sources/bbcp/Dev/Mod/Commanders.odc" "$USE/Dev/Mod/Commanders.odc"
"$HOME/sources/bbcp/tools64/sync-odc.sh" >/dev/null 2>&1 || true
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
ConsCompiler64
LIST
echo 'DevOnce.Go64' | "$HOME/sources/bbcp/run-dev0"
