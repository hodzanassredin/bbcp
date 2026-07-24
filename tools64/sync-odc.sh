#!/bin/sh
# Import all *.odc.txt that are newer than their .odc (or missing .odc)
# back into .odc via the bbcb2 OdcText round-trip host.
BBCP="$HOME/sources/bbcp"
BB2="$HOME/sources/bbcb2-2.0~a1.build332"
cmds=""
for txt in "$BBCP"/Dev/Mod/*.odc.txt "$BBCP"/Mod64/*.odc.txt "$BBCP"/System/Mod/*.odc.txt "$BBCP"/Lin/Mod/*.odc.txt "$BBCP"/Std/Mod/*.odc.txt "$BBCP"/Text/Mod/*.odc.txt "$BBCP"/Form/Mod/*.odc.txt "$BBCP"/Cons/Mod/*.odc.txt "$BBCP"/Obx/Mod/*.odc.txt; do
	[ -e "$txt" ] || continue
	odc="${txt%.txt}"
	if [ ! -e "$odc" ] || [ "$txt" -nt "$odc" ]; then
		cmds="$cmds
OdcText.Import \"$txt\" \"$odc\""
		echo "sync: $txt"
	fi
done
if [ -n "$cmds" ]; then
	echo "$cmds" | "$BB2/run-BlackBoxInterp" 2>&1 | tail -2
else
	echo "nothing to sync"
fi
