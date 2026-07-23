#!/bin/sh
# Сборка Dev-пайплайна компилятора (amd64) в bbcp64use для компиляции внутри BB64.
# Порядок = по зависимостям. Запускать ПОСЛЕ test64.sh (он всё вайпит).
# bbcp64use/Dev на время компиляции прячем: 64-битные DevCP*.ocf ломают dev0
# ("corrupted code file"), dev0 грузит свои 32-битные из bbcp.
set -e
USE="$HOME/sources/bbcp64use"
STASH="$USE/.dev-stash"
mkdir -p "$STASH"
[ -d "$USE/Dev" ] && mv "$USE/Dev" "$STASH/Dev"
trap 'rm -rf "$USE/Dev"; [ -d "$STASH/Dev" ] && mv "$STASH/Dev" "$USE/Dev"' EXIT
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
