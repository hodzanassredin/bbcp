#!/bin/sh
# probes.sh — регрессионный прогон Obx-пробников в BB64-консоли.
# PASS: нет ~TRAP/SIGILL/CommandError и процесс завершился сам (не timeout).
# НЕ включены ловушки по дизайну: Probe25.Go (NIL deref), Probe7.P
# (S.GET по адресу 0 -> SEGV) — при надобности гонять вручную.
# Usage: probes.sh [Probe21 Probe23 ...]   (по умолчанию все из списка)
set -u
BB="$HOME/sources/bbcp"
USE="$HOME/sources/bbcp64use"
cd "$USE"

ALL="Probe8.T Probe9.Go Probe10.T Probe11.T Probe12.T Probe13.T Probe14.T Probe15.T Probe16.T Probe17.T Probe18.T Probe19.T Probe20.Go Probe21.Go Probe22.Go Probe23.Go Probe24.Go Probe27.Go Probe28.Go Probe29.Go"
[ $# -gt 0 ] && ALL="$@"

pass=0; fail=0
for p in $ALL; do
	out=$(echo "Obx$p" | BB_CONSOLE=1 BB_STANDARD_DIR="$USE" timeout 30 "$BB/Dev/Rsrc/bbrun64" --console 2>&1)
	rc=$?
	if echo "$out" | grep -qE '~TRAP|SIGILL|SIGSEGV|CommandError|Assertion|BAD '; then
		echo "FAIL Obx$p (trap/error):"; echo "$out" | grep -E '~TRAP|SIGILL|CommandError|Assertion|BAD ' | head -3
		fail=$((fail+1))
	elif [ $rc -eq 124 ]; then
		echo "FAIL Obx$p (timeout)"; fail=$((fail+1))
	else
		echo "PASS Obx$p"; pass=$((pass+1))
	fi
done
echo "== probes: pass=$pass fail=$fail"
[ $fail -eq 0 ]
