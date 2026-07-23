#!/bin/sh
# Full amd64 rebuild of subsystems (default: System) in bbcp64use.
# Usage: test64.sh [System|System Lin Std Text Form ...]
# Если в списке есть Cons: сначала собираются остальные подсистемы,
# затем DevCommanders (нужен ConsInterp), затем Cons.
cd "$HOME/sources/bbcp64use"
rm -f */Sym/*.osf */Code/*.ocf
# ConsCompiler64 требует Dev-пайплайн — его собирает build-dev64.sh отдельно;
# из CompileSubs убираем, иначе err 249 (нет Dev osf)
rm -f "$HOME/sources/bbcp/Cons/Mod/Compiler64.odc" "$HOME/sources/bbcp64use/Cons/Mod/Compiler64.odc"
subs="${@:-System}"
case " $subs " in
	*" Cons "*)
		main=$(echo "$subs" | sed 's/\bCons\b//')
		printf 'DevCommanders\n' > /tmp/compile1.txt
		{ echo "DevCompiler64.CompileSubs $main"; echo 'DevOnce.Go64'; echo 'DevCompiler64.CompileSubs Cons'; } | "$HOME/sources/bbcp/run-dev0"
		;;
	*)
		echo "DevCompiler64.CompileSubs $subs" | "$HOME/sources/bbcp/run-dev0"
		;;
esac
