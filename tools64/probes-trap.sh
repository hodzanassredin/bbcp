#!/bin/sh
# probes-trap.sh — пробники, которые ДОЛЖНЫ трапнуться (проверка runtime-checks).
# PASS: в выводе есть "~TRAP" и нет "BAD". Сейчас: Probe30 (integer overflow,
# allchecks — компилируется ConsCompiler64.CompileOpt ... "+", INTO->JNO+trap138).
set -u
. "$(dirname "$0")/env64.sh"
cd "$USE"

pass=0; fail=0
for p in Probe30.Go; do
	out=$(echo "Obx$p" | BB_CONSOLE=1 BB_STANDARD_DIR="$USE" timeout 30 "$BB/Dev/Rsrc/bbrun64" --console 2>&1)
	if echo "$out" | grep -q '~TRAP' && ! echo "$out" | grep -q 'BAD'; then
		echo "PASS Obx$p (ожидаемый трап)"; pass=$((pass+1))
	else
		echo "FAIL Obx$p:"; echo "$out" | tail -3; fail=$((fail+1))
	fi
done
echo "== probes-trap: pass=$pass fail=$fail"
[ $fail -eq 0 ]
