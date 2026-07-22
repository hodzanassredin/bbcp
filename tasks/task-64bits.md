# Порт BlackBox на 64 бита (bbcp) — журнал работ

Цель: перенос системы с 32 на 64 бита. Принципы от 32-битной версии, формат нативный
64-битный (НЕ <4 ГБ). Эталон формата: Hr (`bbcb2/Hr/Mod/Ocf.odc.txt`).
**Коммит c30315fc содержит всё ключевое. Читать также KB/ и AGENTS.md в bbcp.**

## ТЕКУЩЕЕ СОСТОЯНИЕ (на конец сессии 2026-07-23)

### Что работает
- Компилятор (dev0, 32-бит) генерирует OCF amd64 v2 (нативные 64-бит дескрипторы).
- Полная сборка: `System Std Text Form Lin` — 0 ошибок (83+ модулей).
- Загрузчик bbrun64: 119 модулей загружаются, multi-pass import resolution.
- **KERNEL OK** — тело Kernel64 исполняется корректно (rip-relative, frame, ret ок).
- Воспроизведение: `cd ~/sources/bbcp64use && ~/sources/bbcp/Dev/Rsrc/bbrun64`
  (bbrun64 собирается: `cd ~/sources/bbcp/Dev/Rsrc && gcc -m64 -std=c99 -Wall -g
  -D_GNU_SOURCE -o bbrun64 bbrun64.c -ldl`; Makefile64 устарел — EXESIZE не нужен).

### Где остановились: LinInit body падает (SIGILL)
- `Lin/Code/Init.ocf` (module LinInit): тело начинается нормально (push rbp...),
  SIGILL на 0x222. В теле на +0x10: `6a 00 push 0; e8 00 00 00 65` = call с rel32
  = 0x65000000 — это НЕПРОПАТЧЕННАЯ fixup-метаданная (typ=101 relative, next=0).
  Т.е. вызов импортированной процедуры, чья UseBlk-цепочка НЕ была применена.
- LinInit импортирует: Kernel, Services, Log, Dialog, Converters, Loop, Meta,
  LinGtk2GLib, LinGtk2Gtk, LinGui, LinConsole, Windows, StdWindows, StdInterpreter,
  LinRegistry, LinFonts, StdStdCFrames, LinDates, LinMechanisms, LinBackends,
  LinClipboard, LinLang, StdCmds, LinDialog.
- Направление: выяснить, какой это вызов (push 0 + call = вероятно HALT/Kernel.XX
  или вызов в $dll). Проверить UseBlk LinInit: все ли mProc-цепочки пропатчены.
  Возможные причины: (a) импорт из $dll (LinGtk2*) — ThisDllObj/Fixup(a);
  (b) импорт из Kernel64 (kernel.New*/term proc); (c) цепочка пропущена загрузчиком.
- Отладка: python-парсер FixBlk/UseBlk (есть наработки в логе сессии), gdb.

### Открытые задачи (порядок)
1. LinInit: починить непропатченный вызов (см. выше).
2. Cons subsystem 64-бит (ConsFonts/ConsWindows/ConsLog нужны Lin/Code/IntInit.ocf).
3. LinKernel64 (Mod64/LinKernel64.odc): 6 ошибок — минимальный, ссылается на
   Kernel64.InitHeap/Cluster/monoCluster которых нет. Нужен ПОЛНЫЙ Kernel64
   (стадия C): база = Mod64/Kernel64_full.odc (2381 строка, полный порт Kernel,
   но Module.code/data/refs: INTEGER — расширить до ADDRESS/LONGINT по новой
   раскладке ModDesc (KB/OcfFormat64.md)).
4. isGuarded/exception frames: отложено, 32-битный дизайн (fs:0), для amd64 Linux
   нужен redesign (размеры в Enter/Exit временно: guarded vadr=-48, size=48).
5. GUI: Lin/GTK модули грузятся; после LinInit — окна.
6. Убрать диагностику из DevCPT: DbgTyp, PVFP/FP249 принты, "W " дампы в OutStr
   (ОСТАВЛЕНЫ в коде — убрать после стабилизации!).
7. Kernel64.Init: modList := NIL — лоадер инжектит modlist ПОСЛЕ тела ядра (ок),
   но полный Kernel64 должен читать bootInfo ДО (как 32-бит bbrun.c).

## Диагноз (почему прошлая попытка провалилась)
Компилятор эмитировал 32-битные дескрипторы (4-байтные слоты) против 64-битных
CP-записей. Плюс calling convention полностью 32-битная (add esp, ParOff=8,
слоты 4, inc/dec как 40-4F, ripBased с неверным immLen). Лечить в эмиттере.

## Установленные факты о формате (OCF amd64 v2)
Полная спека: **KB/OcfFormat64.md**. Кратко:
- ObjFile = HeaderBlk MetaBlk DescBlk CodeBlk FixBlk UseBlk. VarBlk не хранится.
- FixBlk сразу после CodeBlk: 6 групп (newRec,newArr,meta,desc,code,data),
  каждая: пары RNum(head) RNum(offset), терминатор 0.
- Цепочки: head>0 → code; head<0: |head|<ms → meta, иначе desc (|head|-ms).
  Слот 4 байта метаданных (typ*1000000H+next24); указательные слоты 8 байт
  (+4 sentinel 11223344H), лоадер пишет все 8.
- Fixup типы: absolute=100 (8-байтная запись), relative=101 (disp32=target-ladr-4),
  copy=102 (8 байт из adr+offset), table/tableend=103/104 (case, 8-байтные записи,
  next=link+8), ripBased=106+immLen (disp32 = target-(ladr+4+immLen)).
- ModDesc == Kernel64.Module (офсеты в KB/OcfFormat64.md); name@152.
- Type desc: methods (по 8) с маркером -1(8); size@0 mod@8 id@16 base@24(16×8)
  fields@152 ptroffs@160.
- Export: num(4) + записи 24 байта (fprint/offs/id/pad/ostruct).
- Код: E8 rel32 прямые CALL; RIP-relative данные (disp32 → арена лоадера);
  case: mov r11,imm64 + jmp [r11+idx*8]; imm64/moffs64 8-байтные слоты.

## Тулчейн и деревья
- dev0Linux (коммит c30315fc): packed 32-bit BB БЕЗ компилятора (грузится из Code).
  Перепаковка: tools64/repack-dev0.sh (link + pack, pack ИЗ-ПОД blackboxInterpLinux
  — ETXTBSY!). blackboxInterpLinux НЕ в git — пересобирается тем же скриптом.
- bbcp64use (НЕ в git): изолированные 64-бит Sym/Code + симлинки Mod.
  Поддерева Dev там быть НЕ ДОЛЖНО. Пересоздаётся скриптами.
- bbcp/Mod64/: amd64-only исходники (в git).
- Скрипты tools64/: sync-odc.sh (.txt→.odc через bbcb2), go32.sh/go64.sh (DevOnce),
  test64.sh (wipe+CompileSubs), repack-dev0.sh.
- Правило: источник истины = *.odc.txt (коммитим с -f, gitignore их игнорит).

## Решённые проблемы (хронология)
1. Формат desc 32-бит → OCF v2 (8-байтные слоты). Коммит c30315fc.
2. Packed-модули dev0 затеняли правки CPE/CPT → репак без компилятора.
3. Смешение 32/64 osf → "not consistently imported" → bbcp64use + полный список
   подсистем при компиляции (Controls→StdCFrames, StdDialog→TextModels).
4. Коллизии MODULE-имён (Kernel64×4, LinKernel64 затёр Kernel64) → Mod64/.
5. add esp/inc/dec/ripBased/frame/calling convention — исправлены (KERNEL OK).
6. C Directory alignment bug в bbrun64 (packed struct).

## Типичные грабли (для будущих сессий)
- .odc.txt частично не в git → после git checkout .odc — проверять .txt (дубликаты!).
- CP: объявления до использования; ORD(BOOLEAN) нет; SHORTCHAR≠CHAR; msg- read-only.
- test64 всегда с ПОЛНЫМ списком подсистем (иначе 32-бит osf fallback → 249).
- Компиляция модулей НЕ по зависимостям если osf провайдера нет в use64.
