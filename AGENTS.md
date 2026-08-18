# BBCP — BlackBox Component Pascal (64-bit port project)

BlackBox Component Builder 2.0 с портом на amd64. Исходники в `.odc` (бинарный
Oberon document); редактируемые копии — `.odc.txt` (OdcText round-trip).

## Главное правило

**Источник истины — `*.odc.txt`, все в UTF-8** (см. KB/OdcTextUtf8.md; cp1251
запрещён, не-ASCII литералы в коде — hex-константами вида `0C0X`). Правим только
их; `.odc` генерируется `tools64/sync-odc.sh` (через OdcTextU в bbcb2 — UTF-8
вариант OdcText). Перед `git checkout` .odc — учитывать, что .odc.txt мог быть
отдельно изменён.

## Структура

- `Dev/Mod/` — компилятор: CPB/CPE/CPL486/CPC486 (32-бит backend, packed в dev0),
  CPLamd64/CPCamd64/CPVamd64/Compiler64 (amd64 backend, из Code), Once (DevOnce).
- `Mod64/` — amd64-only модули (Kernel64, LinKernel64, Stores64) — держать вне
  System/Mod и Lin/Mod, чтобы 32-битный CompileSubs не падал.
- `Dev/Rsrc/` — bbrun64.c (64-битный загрузчик), Makefile64, build_boot64.sh.
- `tools64/` — скрипты цикла разработки (см. KB/Workflow64.md).
- `KB/` — база знаний: Workflow64, OcfFormat64, Findings64. Читать при старте работы.
- `tasks/task-64bits.md` — журнал порта (решения, лог проб).

## Деревья сборки

- `~/sources/bbcp` — это дерево (32-бит dev0 + исходники).
- `~/sources/bbcp64use` — изолированные 64-битные Sym/Code (+ симлинки на Mod).
  Поддерева Dev там быть НЕ ДОЛЖНО.
- `~/sources/bbcb2-2.0~a1.build332` — только эталон Hr; для сборки bbcp
  НЕ нужен (round-trip .odc делает сама BB64 через OdcTextU.Batch).

## Команды

```sh
tools64/sync-odc.sh        # .odc.txt -> .odc (только изменённые; хост — консоль BB64)
tools64/go32.sh DevCPE     # 32-бит компиляция модулей (для dev0)
tools64/go64.sh Kernel64   # amd64 компиляция модулей (в bbcp64use)
tools64/test64.sh System   # полная amd64 сборка подсистем (wipe Sym/Code)
tools64/mkworld64.sh       # скелет bbcp64use с нуля
tools64/repack-dev0.sh     # репак dev0Linux (только для packed-модулей)
echo 'DevCompiler64.CompileSubs System' | ./run-dev0   # из bbcp64use: полная сборка
cd Dev/Rsrc && make -f Makefile64                      # загрузчик bbrun64
```

Bootstrap с чистого клона: `mkworld64.sh` →
`test64.sh System Lin Std Text Form Cons Obx` — всё, bbcb2 не нужен.

## Конвенции

- Модуль `SubsystemModule` = файл `Subsystem/Mod/Module.odc`; IMPORT SubsystemModule.
- Ошибки компиляции: DevCompiler64 печатает позиции через LogMarks.
- После изменений: сверить diff с KB/OcfFormat64.md, обновить KB и tasks/task-64bits.md.
