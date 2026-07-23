# Порт BlackBox на 64 бита (bbcp) — журнал работ

Цель: перенос системы с 32 на 64 бита. Принципы от 32-битной версии, формат нативный
64-битный (НЕ <4 ГБ). Эталон формата: Hr (`bbcb2/Hr/Mod/Ocf.odc.txt`).
**Коммит c30315fc содержит всё ключевое. Читать также KB/ и AGENTS.md в bbcp.**

## ТЕКУЩЕЕ СОСТОЯНИЕ (на конец сессии 2026-07-23, вечер)

### Что работает
- Компилятор (dev0, 32-бит) генерирует OCF amd64 v2 (нативные 64-бит дескрипторы).
- Полная сборка: `System Std Text Form Lin` — 0 ошибок (кроме LinKernel64, см. ниже).
- Загрузчик bbrun64: 119+ модулей, multi-pass import resolution, **crash-handler**
  (SIGSEGV/SIGILL → модуль+offset, псевдо-bt), CheckSentinels.
- **KERNEL OK** + **тела модулей исполняются в порядке загрузки** (bbrun64 зовёт
  body каждого модуля как Kernel.InitModule): доходит до LinConsole включительно.
- Kernel64: bump-allocator (16 МБ статическая куча), NewRec/NewArr работают
  (LinClipboard.Install делает NEW).

### Где остановились: SysV FFI (ccall → libc/GTK) — КЛЮЧЕВОЙ БЛОК
- `LinConsole.Init`: `Libc.fdopen(0,"rb")` → HALT(100) (ASSERT input # NULL).
- Причина: amd64 backend зовёт ccall по 32-битной cdecl (аргументы на стеке),
  а SysV ABI требует rdi/rsi/rdx/rcx/r8/r9. ВСЕ $dll-вызовы сломаны.
- Плюс: caller cleanup 4-байтными слотами (add rsp,12 при 16 pushed);
  LinLibc-типы (PtrFILE, long, size_t...) = INTEGER → усечение указателей до 4.
- План и детали: **KB/FFI-SysV.md**. Исправленные баги сессии: KB/Findings64.md
  (11 штук: processor=12, inc/dec 40-4F, LenDesc, Pop Int64, align 8, ...).

### Открытые задачи (порядок)
1. **SysV FFI в компиляторе** (CPCamd64.Call ccall): регистры rdi..r9, стек 8,
   align 16; CCallParSize только хвост; variadic AL=0. Callbacks из C — тоже SysV.
2. LinLibc: INTEGER → LONGINT для указателей/long/size_t (+ потребители, GTK-структуры).
3. Cons subsystem 64-бит (ConsFonts/ConsWindows/ConsLog нужны Lin/Code/IntInit.ocf).
4. LinKernel64 (Mod64/LinKernel64.odc): ошибки компиляции — нужен ПОЛНЫЙ Kernel64
   (стадия C): база = Mod64/Kernel64_full.odc (2381 строка; Module.code/data/refs:
   INTEGER — расширить до ADDRESS/LONGINT по ModDesc (KB/OcfFormat64.md)).
5. isGuarded/exception frames: 32-битный дизайн (fs:0), нужен amd64 redesign.
6. GUI: Lin/GTK после FFI.
7. Убрать диагностику из DevCPT: DbgTyp, PVFP/FP249 принты, "W " дампы в OutStr.
8. Kernel64.Init: читать bootInfo ДО тела (как 32-бит bbrun.c), не инжект после.

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
