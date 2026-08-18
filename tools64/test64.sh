#!/bin/sh
# Full amd64 rebuild of subsystems (default: System) in bbcp64use.
# Usage: test64.sh [System|System Lin Std Text Form ...]
# Если в списке есть Cons: сначала собираются остальные подсистемы,
# затем DevCommanders (нужен ConsInterp), затем Cons.
. "$(dirname "$0")/env64.sh"
cd "$USE"
# sync .odc.txt -> .odc ДО вайпа: хост sync-odc — сама BB64 (OdcTextU),
# ей нужен живой мир. На свежем клоне sync — no-op (.odc закоммичены).
"$BB/tools64/sync-odc.sh"
rm -f */Sym/*.osf */Code/*.ocf
# ConsCompiler64 требует Dev-пайплайн — его собирает build-dev64.sh отдельно;
# из CompileSubs убираем, иначе err 249 (нет Dev osf)
rm -f "$BB/Cons/Mod/Compiler64.odc" "$USE/Cons/Mod/Compiler64.odc"
subs="${@:-System}"
case " $subs " in
	*" Cons "*)
		main=$(echo "$subs" | sed 's/\bCons\b//')
		printf 'DevCommanders\n' > /tmp/compile1.txt
		{ echo "DevCompiler64.CompileSubs $main"; echo 'DevOnce.Go64'; echo 'DevCompiler64.CompileSubs Cons'; } | "$BB/run-dev0"
		;;
	*)
		echo "DevCompiler64.CompileSubs $subs" | "$BB/run-dev0"
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

# Cuda — то же: добираем, если подсистема есть (биндинги libcudart, см. KB/CudaSubsystem.md)
if [ -d "Cuda/Mod" ]; then
	"$BB/tools64/go64.sh" CudaRt CudaUtil CudaTest 2>&1 | tail -1
fi

# Dev-пайплайн (для компиляции внутри BB64) — всегда добираем в конце
"$BB/tools64/build-dev64.sh" 2>&1 | grep -E '== ConsCompiler64|== DevCompiler64' | tail -2

# долинковать portable .osf из bbcp (см. link-sym.sh)
"$BB/tools64/link-sym.sh"
