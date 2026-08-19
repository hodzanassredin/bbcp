# BBCP — BlackBox Component Pascal (64-bit port project)

BlackBox Component Builder 2.0 с портом на amd64. Исходники в `.odc` (бинарный
Oberon document); редактируемые копии — `.odc.txt` (OdcText round-trip).

## Главное правило

**Источник истины — `*.odc.txt`, все в UTF-8** (см. KB/OdcTextUtf8.md; cp1251
запрещён, не-ASCII литералы в коде — hex-константами вида `0C0X`). Правим только
их; `.odc` генерируется `tools64/sync-odc.sh` (через OdcTextU.Batch в консольной
BB64 — UTF-8 вариант OdcText). Перед `git checkout` .odc — учитывать, что
.odc.txt мог быть отдельно изменён.

## Структура

- `Dev/Mod/` — компилятор: CPB/CPE/CPL486/CPC486 (32-бит backend, packed в dev0),
  CPLamd64/CPCamd64/CPVamd64/Compiler64 (amd64 backend, из Code), Once (DevOnce).
- `Mod64/` — amd64-only модули (Kernel64, LinKernel64, Stores64) — держать вне
  System/Mod и Lin/Mod, чтобы 32-битный CompileSubs не падал.
- `Dev/Rsrc/` — bbrun64.c (64-битный загрузчик), Makefile64, build_boot64.sh.
- `tools64/` — скрипты цикла разработки (см. KB/Workflow64.md).
- `Paket/`, `Crypto/` — batteries included: менеджер пакетов и криптография
  (64-битный порт). Это VENDORED копии: upstream — github.com/bbext/Paket и
  bbext/Crypto64 (там же живёт фид blackbox.oberon.org). Правки сначала в
  bbext, в bbcp переносим rsync'ом Mod/Docu (+Rsrc у Paket) и коммитим.
  Crypto/Mod/AllTests.odc — launcher-документ, не модуль (не компилируется).
- `KB/` — база знаний: Workflow64, OcfFormat64, Findings64. Читать при старте работы.
- `tasks/task-64bits.md` — журнал порта (решения, лог проб).

## Деревья сборки

- `bbcp` — это дерево (32-бит dev0 + исходники). Путь произвольный:
  скрипты находят корень репо по собственному расположению (`tools64/env64.sh`).
- `bbcp64use` — изолированные 64-битные Sym/Code (+ симлинки на Mod).
  По умолчанию `../bbcp64use` рядом с репо; переопределяется `$BBCP64USE`.
  Поддерева Dev там быть НЕ ДОЛЖНО (его пересоздаёт build-dev64.sh).
- `~/sources/bbcb2-2.0~a1.build332` — исторический эталон (там осталась копия
  Hr — прототипа 64-битного компилятора); для сборки bbcp НЕ нужен
  (round-trip .odc делает сама BB64 через OdcTextU.Batch).
  В bbcp Hr удалён (2026-08-18) — сверка завершена.

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

## Документы и embedded views

- В `.odc.txt` сохранять все теги `<odc-view .../>`. В `Docu/Compile-List.odc`
  нельзя удалять ведущий `DevCommanders.StdView` и завершающий
  `DevCommanders.StdEndView` — без StdEndView Paket не компилирует пакет.
- Commander без параметров: StdView + команда + StdEndView; с параметрами:
  один StdView + команда в двойных кавычках, StdEndView не нужен.

## Пакеты (Paket)

- Подсистема-пакет: `Docu/Quick-Start.odc` (строка `Depends: ...` вверху —
  зависимости для Paket), `Docu/Compile-List.odc`, `Docu/Coder-List.odc`.
- Coder-List — пакетно-относительные пути `.odc` (`Cuda/Mod/Rt.odc`),
  НЕ локальные `.odc.txt` (урок bbext/Cuda ec9d441).
- Репозитории пакетов: github.com/bbext/* (Paket, Cuda). Правки там:
  export→edit→import через OdcText (KB/PaketUpstreamNilGuards.md);
  пуш по SSH, после пуша веб-хук раскатывает версию на сервер.

## Skills

- `.agents/skills/` — справочники по CP и подсистемам (cp-language, system-core,
  system-mvc, text-system, dev-tools и др.; индекс — `.agents/skills/README.md`).
- Внимание: примеры команд в skills от классического 32-битного воркфлоу
  (`./run-BlackBoxInterp`, `DevCompiler.CompileThis`). В bbcp команды — через
  `tools64/` и `run-dev0`/`bbrun64`, см. KB/Workflow64.md.
