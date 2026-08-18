#!/bin/sh
# Full amd64 rebuild of subsystems (default: System) in bbcp64use.
# Usage: test64.sh [System|System Lin Std Text Form ...]
# Если в списке есть Cons: сначала собираются остальные подсистемы,
# затем DevCommanders (нужен ConsInterp), затем Cons, затем LinIntInit
# (консольный init: импортирует ConsWindows/ConsLog/ConsFonts).
. "$(dirname "$0")/env64.sh"
# seed-проверка: dev0 грузит компилятор из bbcp/Dev/Code (32-битные .ocf, закоммичены).
# Если клон странный (нет .ocf) — скажи об этом явно, а не "code file not found" потом.
if [ ! -f "$BB/Dev/Code/Once.ocf" ] || [ ! -f "$BB/Dev/Code/Compiler64.ocf" ]; then
	echo "test64: нет 32-битного seed-компилятора ($BB/Dev/Code/*.ocf)." >&2
	echo "  Он закоммичен в репо — проверьте, что клон полный (git status)." >&2
	exit 1
fi
cd "$USE"
# sync .odc.txt -> .odc ДО вайпа: хост sync-odc — сама BB64 (OdcTextU),
# ей нужен живой мир. На свежем клоне sync — no-op (.odc закоммичены).
"$BB/tools64/sync-odc.sh"

# 32-битные .osf в bbcp ПРЯЧЕМ на время сборки: иначе компилятор находит их
# через fallback (standard dir) и НЕ пишет свежие 64-битные osf в мир
# ("symbol file unchanged"), а link-sym потом долинковывает 32-битные.
# Смесь osf разных винтажей = PVFP mismatch (err 249) у модулей, чьи импорты
# содержат приватные поля-указатели (DevBrowser/HeapSpy/MsgSpy над TextModels).
# go32.sh (32-битная пересборка DevCP* для dev0) работает ПОСЛЕ restore.
for d in "$BB"/*/Sym; do
	[ -d "$d" ] && mv "$d" "${d}32stash"
done
restore_sym() {
	for d in "$BB"/*/Sym32stash; do
		[ -d "$d" ] && mv "$d" "${d%32stash}"
	done
}
trap restore_sym EXIT
trap 'exit 1' INT TERM PIPE

rm -f */Sym/*.osf */Code/*.ocf
# ConsCompiler64 требует Dev-пайплайн — его собирает build-dev64.sh отдельно;
# из CompileSubs убираем, иначе err 249 (нет Dev osf)
rm -f "$BB/Cons/Mod/Compiler64.odc" "$USE/Cons/Mod/Compiler64.odc"
subs="${@:-System}"
case " $subs " in
	*" Cons "*)
		main=$(echo "$subs" | sed 's/\bCons\b//')
		printf 'DevCommanders\n' > /tmp/compile1.txt
		{ echo "DevCompiler64.CompileSubs @Lin $main"; echo 'DevOnce.Go64'; echo 'DevCompiler64.CompileSubs @Lin Cons'; } | "$BB/run-dev0"
		# LinIntInit импортирует Cons* — компилируем ПОСЛЕ Cons (иначе err 152)
		printf 'LinIntInit\n' > /tmp/compile1.txt
		echo 'DevOnce.Go64' | "$BB/run-dev0" 2>&1 | grep -E 'LinIntInit|err =' | head -3
		;;
	*)
		echo "DevCompiler64.CompileSubs @Lin $subs" | "$BB/run-dev0"
		;;
esac

# Kernel64 (Mod64) не входит в CompileSubs — после wipe обязателен, иначе "no kernel".
# Собираем СРАЗУ: OdcTextU (sync-хост) и build-dev64 (Batch-конвертер) — это
# консольные запуски BB64, им нужен бутующийся мир.
"$BB/tools64/go64.sh" Kernel64 2>&1 | tail -1

# OdcTextU (хост sync-odc/build-dev64)
"$BB/tools64/go64.sh" OdcTextU 2>&1 | tail -1

# Fig не входит в стандартный список подсистем, но wipe выше стирает и его ocf —
# добираем всегда, если подсистема есть в мире (нужна для FigViews.StdView в Tut-доках;
# без неё встроенные схемы рисуются серым квадратом с крестом)
if [ -d "Fig/Mod" ]; then
	"$BB/tools64/go64.sh" FigModels FigViews FigPoints FigBasic FigCmds 2>&1 | tail -1
fi


# Dev-пайплайн (для компиляции внутри BB64) — всегда добираем в конце
"$BB/tools64/build-dev64.sh" 2>&1 | grep -E '== ConsCompiler64|== DevCompiler64' | tail -2

# долинковать portable .osf из bbcp (см. link-sym.sh)
"$BB/tools64/link-sym.sh"
