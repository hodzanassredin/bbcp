# Порт BlackBox на 64 бита (bbcp) — журнал работ

Цель: перенос системы с 32 на 64 бита. Принципы от 32-битной версии, формат нативный
64-битный (НЕ <4 ГБ). Эталон формата: Hr (`bbcb2/Hr/Mod/Ocf.odc.txt`).
**Коммит c30315fc содержит всё ключевое. Читать также KB/ и AGENTS.md в bbcp.**

## ТЕКУЩЕЕ СОСТОЯНИЕ (на конец сессии 2026-07-24, вечер)

### Что работает
- Компилятор (dev0, 32-бит) генерирует OCF amd64 v2 (нативные 64-бит дескрипторы).
- Полная сборка: `System Std Text Form Lin Cons` — 0 ошибок (131 ocf;
  ConsCompiler отключён — нужен весь Dev; DevCommanders собирается фазой в test64.sh).
- **System Kernel портирован** (агент + ревью): ADDRESS=LONGINT, раскладки
  Module/Block/Cluster, pad-поля Module/Type/ObjDesc под OCF v2 (компилятор
  выравнивает поля max на 4!), typed-pointer идиомы вместо S.GET/PUT по
  LONGINT-локалам, Erase на CP. Kernel64_full — справочно (коммит dd86ead8).
- **SysV FFI, LinLibc 64-бит** — решены (см. ниже хронологию).
- **bbrun64 доходит до инфра-инита**: KERNEL OK, тела Utf/LinKernel/Files/
  LinEnv/LinFiles проходят. Фиксы backend по пути: REX.R для r11 (cmp [mem],r11),
  stackArray sp 64-бит (pop rsp усекал стек), open-array база Pointer,
  value Comp-параметры 8-выровнены, modList-инжект в System Kernel,
  init-инфра первой (порядок dev0-link), LinLoader/LinIntLoader+LinFiles.
- Инструменты: tools64/ocf.py (refs/disasm), errpos.sh, c64.sh, gdb/ хелперы,
  bbrun64 _Static_assert ABI + modlist sanity.

### Где остановились: краш в Kernel.Assert (log dispatch) при init LinPackedFiles
- Тело LinPackedFiles падает на ASSERT (cond=false, причина не выяснена),
  путь падения сам падает: `log.String` — диспетч через [itable-8], глобал
  log содержит мусор. OCF v2 НЕ имеет VarBlk — компиляторная инициализация
  глобалов (interface-таблицы ErrLog) не применяется. Надо: явная инициализация
  interface-глобалов (TDinit/VarBlk-эквивалент) или обход interface-диспетча.
- Дальше по плану: (1) log/assert → MAIN OK; (2) StdLoader.Fixup 64-бит
  (ленивая загрузка внутри BB64); (3) Dev/ConsCompiler → HelloWorld из консоли;
  (4) exceptions/callbacks (SysV Enter, isGuarded); (5) GTK 64-бит → LinGui.

## ПРЕДЫДУЩЕЕ СОСТОЯНИЕ (утро 2026-07-24)

### Что работало тогда
- Компилятор (dev0, 32-бит) генерирует OCF amd64 v2 (нативные 64-бит дескрипторы).
- Полная сборка: `System Std Text Form Lin` — 0 ошибок. LinKernel64 ИСКЛЮЧЁН
  (CompileSubs стоп на первом ошибочном модуле; симлинк bbcp64use/Lin/Mod/
  Kernel64.odc переименован в .disabled до стадии C).
- **SysV FFI (задача 1) РЕШЁН**: ccall по SysV ABI (rdi..r9, динамический
  align 16 через r12, хвост за 6-ю на стеке, AL=0, Int64-параметр = 1 слот,
  Int64-результат из rax в пару). Детали KB/FFI-SysV.md.
- **LinLibc 64-бит (задача 2) РЕШЁН**: PtrVoid/long/size_t/off_t/time_t и пр.
  = LONGINT; раскладки stack_t/stat_t/stat64_t/timespec/ucontext/sigjmp_buf;
  stat/stat64 вместо __xstat (на x86-64 glibc __xstat не экспортируется).
  Потребители починены: LinKernel, LinFiles, LinFiles64, LinDates,
  System Kernel, Services (точечные SHORT для legacy-модулей).
- **bbrun64 доходит до LinLoader**: LinConsole.Init (fdopen) OK; LinKernel.Init
  ПОЛНОСТЬЮ (sysconf, mmap, calloc, sigaltstack — 64-битный stack_t, sigaction,
  setlocale, SetPlatform + InitHeap). 119+ модулей, crash-handler работает
  (даёт модуль+offset, псевдо-bt).

### Где остановились: System Kernel vs OCF v2 — СТАДИЯ C
- ~~LinLoader~~ исправлен: InstallStackAlloc был 32-битным (`sub esp, eax`
  усекал rsp при фреймах > 2048; LinLoader.Load имеет 4×256 CHAR локалов).
  Переписан сырыми байтами (64-бит sub rsp, слоты 8, probe 4088).
- Бут доходит до LinIntLoader → Kernel.ThisLoadedMod → краш в scasb:
  **System/Mod/Kernel.odc имеет 32-битную раскладку Module/Type/Directory**
  (name@112), а bbrun64 строит дескрипторы по OCF v2 (name@152, указатели 8).
  "Указатель" = ASCII имени модуля.
- **Решение (path B)**: правим System Kernel напрямую (список правок как для
  Kernel64_full из анализа), а не заменяем на Kernel64_full — так модули
  продолжают линковаться на "Kernel" без remap/fingerprint-проблем.
  Kernel64_full портируется справочно (может пригодиться для bump-замены).
- **Int64-арифметика РАБОТАЕТ** (задача 9): сняты err(260) в CPVamd64 —
  арифметика идёт через x87 FPU (FILD/FADD/FCOMP, было в backend, Finding #1).
- **Cons subsystem собран** (Fonts/Windows/Log/Interp) + DevCommanders 64-бит
  (use64/Dev/Mod — только Commanders.odc, dev0 его не исполняет).
  ConsCompiler НЕ собирается: ему нужен весь Dev-компилятор внутри BB64
  (стадия self-hosting, позже). bbrun64 сканирует теперь Cons и Dev.

### Открытые задачи (порядок)
1. ~~SysV FFI~~ — СДЕЛАНО (KB/FFI-SysV.md).
2. ~~LinLibc INTEGER -> LONGINT~~ — СДЕЛАНО.
3. Cons subsystem 64-бит (ConsFonts/ConsWindows/ConsLog нужны Lin/Code/IntInit.ocf).
4. LinKernel64 + ПОЛНЫЙ Kernel64 (стадия C): база Mod64/Kernel64_full.odc
   (2381 строка; Module.code/data/refs: INTEGER -> ADDRESS/LONGINT по KB/OcfFormat64.md).
5. isGuarded/exception frames + callbacks C->BB (SysV Enter): 32-битный дизайн
   (fs:0), нужен amd64 redesign. Signal handlers пока сломаны.
6. GUI: Lin/GTK (теперь FFI есть; нужны GTK-структуры 64-бит + xmm для gdouble).
7. Убрать диагностику из DevCPT: DbgTyp, PVFP/FP249 принты, "W " дампы в OutStr.
8. Kernel64.Init: читать bootInfo ДО тела (как 32-бит bbrun.c); вернуть
   argc/argv в LinKernel.Setup (сейчас заглушка argc:=0, argv:=NIL).
9. **Int64-арифметика в backend ОТСУТСТВУЕТ** (бомба): Ndop form=Int64 →
   DevCPM.err(260) + fallback компилирует ТОЛЬКО левый операнд (молча неверный
   код!); в Mem-контексте (S.GET/PUT) — HALT компилятора. Нужны add/adc,
   sub/sbb, cmp на паре lo/hi (или Int64 в одиночном r64). Findings64 п.18.
10. SYSTEM.ADR/TYP остаются int32typ нарочно (int64typ ломает codegen);
    adr-item = Pointer form (64-битная загрузка); усечение в INTEGER = legacy.

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
7. SysV FFI (ccall) — регистры rdi..r9, align 16, Int64-слоты (2026-07-24).
8. LinLibc 64-бит типы + раскладки записей; stat вместо __xstat (2026-07-24).
9. Pointer→Int64 VAL-конверсия (PtrToLong, mov+shr 32) (2026-07-24).
10. baseStack/platform.tag 64-бит (System Kernel + LinKernel) (2026-07-24).

## Типичные грабли (для будущих сессий)
- .odc.txt частично не в git → после git checkout .odc — проверять .txt (дубликаты!).
- CP: объявления до использования; ORD(BOOLEAN) нет; SHORTCHAR≠CHAR; msg- read-only.
- test64 всегда с ПОЛНЫМ списком подсистем (иначе 32-бит osf fallback → 249).
- Компиляция модулей НЕ по зависимостям если osf провайдера нет в use64.
- CompileSubs СТОП на первом модуле с ошибками → проблемный модуль (LinKernel64)
  выносить из bbcp64use/Lin/Mod иначе не соберутся последующие.
- Int64-арифметика в исходниках = err(260) с молча неверным кодом; в S.GET-контексте
  падает компилятор (ASSERT в CPCamd64.Mem). Проверять grep'ом LONGINT-арифметику.
- Log-вывод dev0 теряется при TRAP — диагностику в компиляторе через HALT(конст);
  trap number виден в репорте. HALT принимает только константу.
- Микро-репродукции: модуль SystemTestT1 (OdcText.Import + CompileThis) —
  секунды на итерацию отладки codegen. Удалять после!
