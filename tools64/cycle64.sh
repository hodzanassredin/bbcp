#!/bin/sh
# Full 64-bit dev cycle: sync .txt->.odc, rebuild changed compiler modules (32-bit),
# rebuild the whole 64-bit world, build bbrun64, run it.
# Usage: cycle64.sh [DevModule ...]   (compiler modules to rebuild 32-bit first)
set -e
cd "$HOME/sources/bbcp"
tools64/sync-odc.sh
for m in "$@"; do
	tools64/go32.sh "$m" | tail -1
done
if [ $# -gt 0 ]; then
	# const/interface changes may require DevCompiler64 rebuild; cheap enough to skip by default
	:
fi
tools64/test64.sh System Std Text Form Lin 2>&1 | grep -E 'err =|errors detected|TRAP' || true
echo "ocf: $(ls ~/sources/bbcp64use/*/Code/*.ocf | wc -l)"
cd "$HOME/sources/bbcp/Dev/Rsrc"
gcc -m64 -std=c99 -Wall -g -D_GNU_SOURCE -o bbrun64 bbrun64.c -ldl
cd "$HOME/sources/bbcp64use"
"$HOME/sources/bbcp/Dev/Rsrc/bbrun64"
