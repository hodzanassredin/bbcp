#!/bin/sh
# smoke-console.sh — прогон консольной BB64: компиляция и запуск HelloWorld.
# Требует рабочего бута (MAIN OK) и собранного Dev-пайплайна (build-dev64.sh).
# Использование: tools64/smoke-console.sh
set -e
. "$(dirname "$0")/env64.sh"

# 1. HelloWorld как текст для ConsCompiler64.Compile (компилирует внутри BB64)
cat > "$USE/Hello.cp" <<'SRC'
MODULE ObxHello;
	IMPORT StdLog;
	PROCEDURE Do*;
	BEGIN
		StdLog.String("Hello, World! (64-bit BlackBox)"); StdLog.Ln
	END Do;
END ObxHello.
SRC

# 2. команды REPL: компилируем и запускаем
cd "$USE"
{
	echo 'ConsCompiler64.Compile("", "Hello.cp")'
	echo 'ObxHello.Do'
} | BB_CONSOLE=1 BB_STANDARD_DIR="$USE" timeout 60 "$BB/Dev/Rsrc/bbrun64" --console 2>&1 | tail -30
