#!/bin/sh
# Compile modules (args or /tmp/compile1.txt) as amd64 into bbcp64use.
# Usage: go64.sh Kernel64 Files64 ...
cd "$HOME/sources/bbcp64use"
[ $# -gt 0 ] && printf '%s\n' "$@" > /tmp/compile1.txt
echo 'DevOnce.Go64' | "$HOME/sources/bbcp/run-dev0"
