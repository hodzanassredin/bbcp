#!/bin/sh
# Full amd64 rebuild of subsystems (default: System) in bbcp64use.
# Usage: test64.sh [System|System Lin Std Text Form ...]
cd "$HOME/sources/bbcp64use"
rm -f */Sym/*.osf */Code/*.ocf
subs="${@:-System}"
echo "DevCompiler64.CompileSubs $subs" | "$HOME/sources/bbcp/run-dev0"
