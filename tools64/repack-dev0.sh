#!/bin/sh
# Relink and repack dev0Linux (32-bit dev host) with current .ocf files.
# Compiler pipeline modules are NOT packed on purpose: they load from Dev/Code,
# so compiler edits only need a 32-bit recompile (see go32.sh), no repack.
set -e
cd "$(dirname "$0")/.."

./run-dev0 <<'DATA'
DevLinker1.LinkElfExe Linux dev0Linux := Kernel$+ Utf LinKernel Files LinEnv LinFiles LinPackedFiles StdLoader LinIntLoader
DATA

./run-BlackBoxInterp <<'DATA'
DevPacker.PackThis dev0Linux := Lin/Code/IntInit.ocf Lin/Code/Console.ocf System/Code/Console.ocf Std/Code/Registry.ocf Lin/Code/Registry.ocf Lin/Code/Lang.ocf System/Code/Dialog.ocf Cons/Code/Fonts.ocf System/Code/Fonts.ocf Cons/Code/Windows.ocf System/Code/Windows.ocf System/Code/Ports.ocf System/Code/Services.ocf System/Code/Stores.ocf System/Code/Strings.ocf System/Code/Math.ocf System/Code/Sequencers.ocf System/Code/Models.ocf System/Code/Views.ocf System/Code/Log.ocf System/Code/Converters.ocf System/Code/Meta.ocf System/Code/Controllers.ocf System/Code/Properties.ocf System/Code/Containers.ocf System/Code/Mechanisms.ocf System/Code/Documents.ocf System/Code/Dates.ocf System/Code/Printers.ocf System/Code/Printing.ocf Lin/Code/Dates.ocf Lin/Code/IntDialog.ocf Std/Code/Interpreter.ocf Std/Code/Dialog.ocf System/Code/Librarian.ocf Std/Code/Log.ocf Text/Code/Models.ocf Text/Code/Mappers.ocf Text/Code/Rulers.ocf Text/Code/Views.ocf Text/Code/Setters.ocf Text/Code/Controllers.ocf Cons/Code/Log.ocf Cons/Code/Interp.ocf Dev/Code/Commanders.ocf System/Code/Controls.ocf Std/Code/CFrames.ocf Dev/Code/Markers.ocf Dev/Code/Selectors.ocf Std/Code/TextConv.ocf Std/Code/Api.ocf Std/Code/Cmds.ocf Std/Code/Links.ocf
DATA

chmod +x dev0Linux
echo "dev0Linux repacked (compiler modules load from Code)"
