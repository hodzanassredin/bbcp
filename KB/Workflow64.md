# Workflow 64-bit port (bbcp)

## Деревья

- `~/sources/bbcp` — основное дерево. 32-битный мир (dev0) + исходники компилятора.
  Здесь правим код и собираем 32-битные .ocf для dev0.
- `~/sources/bbcp64use` — изолированное дерево для 64-битных артефактов.
  `<Sub>/Mod` = симлинки на bbcp, `<Sub>/{Sym,Code}` = свои (64-битные).
  Поддерева Dev там быть НЕ ДОЛЖНО (dev0 подхватит 64-битный DevCPT и умрёт).
- `~/sources/bbcb2-2.0~a1.build332` — чужой рабочий BlackBox; используется только
  как хост для OdcText.Import/Export (.odc <-> .odc.txt) и как источник эталона Hr.
- `bbcp/Mod64/` — amd64-only исходники (Kernel64, LinKernel64, Stores64),
  чтобы 32-битный CompileSubs по System/Lin не спотыкался.

## dev0 (32-битный хост)

- `dev0Linux` — packed 32-bit BlackBox. Packed: базовые модули (System/Text/Std/UI).
  НЕ packed: весь компилятор (DevCompiler, DevCPM/CPT/CPB/CPP/CPS/CPE/CPV486/CPH/
  CPL486/CPC486, CPLamd64/CPCamd64/CPVamd64, DevCompiler64, DevOnce) — грузится из
  `Dev/Code`, поэтому правки компилятора НЕ требуют repack.
- `run-dev0` — запуск с BB_USE_DIR=cwd. Для 64-битных компиляций запускать из bbcp64use.
- `blackboxInterpLinux` — нужен для repack (нельзя писать в запущенный бинарь, ETXTBSY).

## Правило источника истины

- Редактируем ТОЛЬКО `*.odc.txt`. `.odc` — артефакт, генерируется `tools64/sync-odc.sh`.
- .odc.txt может не быть в git — после `git checkout` .odc в .txt остаются старые
  правки (ловушка: дубликаты процедур). Перед откатом чистить и .txt.

## Быстрый цикл

```sh
# правим Dev/Mod/X.odc.txt ...
tools64/sync-odc.sh          # .txt -> .odc для изменённых
tools64/go32.sh DevX         # пересобрать модуль(и) 32-битным компилятором (в bbcp)
tools64/go64.sh Kernel64     # скомпилировать модуль(и) как amd64 (в bbcp64use)
tools64/test64.sh System     # полная пересборка подсистем amd64 (wipe + CompileSubs)
tools64/repack-dev0.sh       # ТОЛЬКО если изменились packed-модули (не компилятор)
```

go32/go64 читают имена модулей из аргументов или /tmp/compile1.txt (DevOnce).

## Компиляция amd64

`DevCompiler64` (Dev/Mod/Compiler64.odc) — кросс-компилятор: DevCPV := DevCPVamd64,
target processor=12. LogMarks печатает позиции ошибок в консоль.

## Сборка bbrun64 (загрузчик)

`Dev/Rsrc/Makefile64`: gcc -DEXESIZE=<size of bbrun64> — EXESIZE должен совпадать
с размером бинаря (self-hosting boot). bb64.img = bbrun64 + .ocf модули (build_boot64.sh).

## Типичные грабли

- "object DevCPX.Y not found" при старте dev0 — интерфейс модуля изменился, а packed
  или старый .ocf теневой. Не менять экспортируемые интерфейсы CPT/CPM без нужды.
- "recursive import not allowed" — файл X.odc содержит MODULE Y, Y импортирует X;
  или два файла с одним MODULE (Kernel64_odc/_gui/_orig/_full!).
- Имя файла = имя модуля минус подсистемный префикс (Lin/Mod/Kernel64.odc = LinKernel64).
- В CP: объявления до использования; ORD(BOOLEAN) нет; SHORTCHAR ≠ CHAR.
- .odc редактировать только через OdcText round-trip (bbcb2), виджеты StdHeaders/
  StdLinks/StdFolds в шапках сохранять.

## Добавлено 2026-07-23

- `tools64/cycle64.sh [DevMod ...]` — полный цикл: sync-odc + go32 для указанных
  модулей компилятора + test64 (System Std Text Form Lin) + сборка и запуск
  bbrun64.
- bbrun64: crash-handler (SIGSEGV/SIGILL): модуль+offset для rip, псевдо-bt
  по стеку (mincore-защита), CheckSentinels при загрузке (слоты 11223344).
- Отладка крашей: НЕ верить objdump вокруг trap-энкодингов (8d f0/e7) —
  смотреть `x/Nxb`; эталонный diff: тот же микро-модуль через go32.
- Ассерт-инвариант в CPVamd64.Variables: Pointer/ProcTyp обязаны иметь size=8
  (ловит 32-битные раскладки на компиляции).

## Обновление (2026-07-24, вечер)

- bbcp64use/Dev ТЕПЕРЬ содержит 64-битный Dev-пайплайн (нужен для компиляции
  внутри BB64). Правило выше («Dev там быть не должно») ОТМЕНЕНО для Code/Sym,
  но из-за этого dev0 из bbcp64use падает с "corrupted code file for DevCP*" —
  поэтому build-dev64.sh прячет Dev на время компиляции (stash/restore).
- tools64/ocf.py — парсер ocf: refs/dis/bytes/hdr. ВАЖНО: refs = смещения КОНЦА
  процедур (OutRefName пишет pc после тела); owner() это учитывает. См.
  KB/MethodTableNumbering.md.
- tools64/desc.py — статический дамп дескрипторов типов из ocf: маркер, n слотов,
  резолв метод-таблиц через fixup-группы (без загрузки).
- tools64/errpos.sh Sub Mod pos — позиция ошибки → строка исходника.
- tools64/c64.sh Mod [off] — один модуль: sync+compile+disasm.
- tools64/build-dev64.sh — Dev-пайплайн (Markers,CPM..CPVamd64,Selectors,
  Commanders,Compiler64,ConsCompiler64) в bbcp64use. Запускать ПОСЛЕ test64.sh
  (test64 всё вайпит, включая Dev).
- tools64/smoke-console.sh — smoke: ConsCompiler64.Compile + ObxHello.Do.
- tools64/gdb/ — findmod/a2m/stackscan. ВАЖНО: ASLR — адреса только внутри
  одного прогона; брейки через ThisModule, но вычислять ПОСЛЕ загрузки
  (break по строке в main, потом source/findmod).
- bbrun64: --console / BB_CONSOLE=1 — консоль (LinIntLoader) вместо GUI.
- ConsCompiler64 = ConsCompiler поверх DevCompiler64 (Cons/Mod/Compiler64.odc.txt).
- Строки в .ocf — UTF-16LE (strings их не видит; искать как u'..'.encode('utf-16-le')).
- trap-инструкции `8d f0 XX` / `8d e7` — objdump десинхронизируется и съедает
  следующий байт (напр. REX 48!). Верить сырым байтам + refs для границ процедур.
