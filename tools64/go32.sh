#!/bin/sh
# Compile modules (args or /tmp/compile1.txt) with the 32-bit compiler into bbcp.
# Usage: go32.sh DevCPE DevCPT ...
# ВНИМАНИЕ: компилирует из .odc — сначала sync-odc (иначе соберёт СТАРЫЙ источник!)
. "$(dirname "$0")/env64.sh"
cd "$BB"
tools64/sync-odc.sh || { echo "go32: sync-odc FAILED — соберётся СТАРЫЙ источник! Импортируйте через bbcb2 OdcTextU.Import" >&2; exit 1; }
[ $# -gt 0 ] && printf '%s\n' "$@" > /tmp/compile1.txt
echo 'DevOnce.Go32' | ./run-dev0
