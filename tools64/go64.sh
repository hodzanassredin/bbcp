#!/bin/sh
# Compile modules (args or /tmp/compile1.txt) as amd64 into bbcp64use.
# Usage: go64.sh Kernel64 Files64 ...
# bbcp64use/Dev на время прячем: 64-битные DevCP*.ocf ломают dev0
# ("corrupted code file"). Для модулей Dev* использовать build-dev64.sh!
set -e
USE="$HOME/sources/bbcp64use"
STASH="$USE/.dev-stash-go64"
[ -d "$USE/Dev" ] && mv "$USE/Dev" "$STASH"
trap '[ -d "$STASH" ] && mv "$STASH" "$USE/Dev"' EXIT
cd "$USE"
[ $# -gt 0 ] && printf '%s\n' "$@" > /tmp/compile1.txt
echo 'DevOnce.Go64' | "$HOME/sources/bbcp/run-dev0"
