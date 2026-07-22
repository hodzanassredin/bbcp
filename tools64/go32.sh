#!/bin/sh
# Compile modules (args or /tmp/compile1.txt) with the 32-bit compiler into bbcp.
# Usage: go32.sh DevCPE DevCPT ...
cd "$HOME/sources/bbcp"
[ $# -gt 0 ] && printf '%s\n' "$@" > /tmp/compile1.txt
echo 'DevOnce.Go32' | ./run-dev0
