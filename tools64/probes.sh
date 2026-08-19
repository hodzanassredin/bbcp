#!/bin/sh
# probes.sh — регрессионный прогон Obx-пробников в BB64-консоли.
# PASS: нет ~TRAP/SIGILL/CommandError и процесс завершился сам (не timeout).
# НЕ включены ловушки по дизайну: Probe25.Go (NIL deref), Probe7.P
# (S.GET по адресу 0 -> SEGV) — при надобности гонять вручную.
# Usage: probes.sh [Probe21 Probe23 ...]   (по умолчанию все из списка)
set -u
. "$(dirname "$0")/env64.sh"
cd "$USE"

ALL="Probe8.T Probe9.Go Probe10.T Probe11.T Probe12.T Probe13.T Probe14.T Probe15.T Probe16.T Probe17.T Probe18.T Probe19.T Probe20.Go Probe21.Go Probe22.Go Probe23.Go Probe24.Go Probe27.Go Probe28.Go Probe29.Go Probe34.Go Probe36.Go Probe40.Go Probe42.Go Probe46.Go Probe49.Go Probe52.Go Compile:ObxTestFwd2"
[ $# -gt 0 ] && ALL="$@"

# без модальных GTK-диалогов: в скриптах они висят до клика (BB_NODIALOG=1
# печатает сообщение в stdout вместо диалога — см. run-bb64)
export BB_NODIALOG=1

# Probe18 привязан к /tmp/libtprobe.so — собираем тестовую либу, если её нет
need_tprobe=0
for p in $ALL; do [ "$p" = "Probe18.T" ] && need_tprobe=1; done
if [ $need_tprobe -eq 1 ] && [ ! -f /tmp/libtprobe.so ]; then
	if command -v cc >/dev/null 2>&1; then
		cc -shared -fPIC -O2 -o /tmp/libtprobe.so "$BB/tools64/tprobe.c" \
			&& echo "built /tmp/libtprobe.so"
	else
		echo "probes: нет cc — Probe18.T будет FAIL (code file /tmp/libtprobe.so not found)" >&2
	fi
fi

# недостающие ocf проб (мир собран до git pull и т.п.) — дособираем разом
missing=""
for p in $ALL; do
	case "$p" in
	Probe*)
		b=$(echo "$p" | cut -d. -f1)	# Probe18.T -> Probe18
		[ -f "$USE/Obx/Code/$b.ocf" ] || missing="$missing Obx$b";;
	esac
done
if [ -n "$missing" ]; then
	echo "probes: дособираю$missing"
	"$BB/tools64/go64.sh" $missing || echo "probes: сборка проб не удалась" >&2
fi

pass=0; fail=0
for p in $ALL; do
	case "$p" in
	Compile:*) # компиляционная проба: PASS если модуль собрался без ошибок
		m="${p#Compile:}"; cmd="DevCompiler.CompileThis $m"; disp="$p";;
	Probe*) cmd="Obx$p"; disp="Obx$p";;
	*) cmd="$p"; disp="$p";; esac
	out=$(echo "$cmd" | BB_CONSOLE=1 BB_STANDARD_DIR="$USE" timeout -k 5 30 "$BB/Dev/Rsrc/bbrun64" --console 2>&1)
	rc=$?
	if echo "$out" | grep -qE '~TRAP|SIGILL|SIGSEGV|CommandError|Assertion|BAD |FAILURES|errors detected|installation failed|Could not load|not found in'; then
		echo "FAIL $disp (trap/error):"; echo "$out" | grep -E '~TRAP|SIGILL|CommandError|Assertion|BAD |FAILURES|err =|errors detected|installation failed|Could not load|not found in' | head -3
		fail=$((fail+1))
	elif [ $rc -eq 124 ]; then
		echo "FAIL $disp (timeout)"; fail=$((fail+1))
	else
		echo "PASS $disp"; pass=$((pass+1))
	fi
done
echo "== probes: pass=$pass fail=$fail"
[ $fail -eq 0 ]
