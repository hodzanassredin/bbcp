#!/bin/sh
# subs64.sh Sub1 [Sub2 ...] — инкрементальная 64-битная пересборка подсистем
# БЕЗ полного вайпа (в отличие от test64.sh). Dev-пайплайн НЕ трогает.
set -e
. "$(dirname "$0")/env64.sh"
"$BB/tools64/sync-odc.sh" >/dev/null 2>&1
STASH="$USE/.dev-stash-subs64"
[ -d "$USE/Dev" ] && mv "$USE/Dev" "$STASH"
trap '[ -d "$STASH" ] && mv "$STASH" "$USE/Dev"' EXIT
cd "$USE"
echo "DevCompiler64.CompileSubs $*" | "$BB/run-dev0"
