# Порт BlackBox на 64 бита (bbcp) — журнал работ

Цель: перенос системы с 32 на 64 бита. Принципы от 32-битной версии, формат нативный
64-битный (НЕ <4 ГБ). Эталон формата: Hr (`bbcb2/Hr/Mod/Ocf.odc.txt`).
**Коммит c30315fc содержит всё ключевое. Читать также KB/ и AGENTS.md в bbcp.**

## ТЕКУЩЕЕ СОСТОЯНИЕ (2026-08-18, поздняя ночь)

### Dev-подсистема портирована почти целиком + фикс Dialog.Update (KB/DialogNotify64.md)
- КОРНЕВОЙ баг GUI: Dialog.Update*/Notify усекали адреса до INTEGER
  (SHORT(SYSTEM.ADR)) — после снятия MAP_32BIT это ломало нотификации.
  Портированы LONGINT: Dialog, Views (NotifyMsg), Controls, Services.AdrOf,
  StdTables/StdLinks/StdFolds/StdTabFrames (fp/fingerprint/IntMap), DevInspector.
- Headless ASSERT(100): Views.NotifyHook.Notify трапался без msgHook
  (ConsWindows его не ставит) — guard. Это чинило бут-трапы тел
  DevAnalyzer/DevBrowser (bbrun64 инитит ВСЕ модули мира).
- Портированы и в мире: DevAnalyzer, DevBrowser, DevDebug (полный порт:
  раскладки, фейк-дескрипторы Type, теги -8), DevHeapSpy (overlay Block/
  Cluster 64-бит), DevMsgSpy, DevProfiler, DevDecoder386, DevInspector,
  DevChmod__Lin (вариант __Lin — компилируется с суффиксом!), AlienTool,
  SubTool, Packer, Linker/Linker1/BootLinker/Lnk*. Dev/Code = 41 ocf.
- BB_NODIALOG: LinDialog.ShowParamMsg печатает в stdout вместо модального
  GTK-диалога (run-bb64 выставляет по умолчанию; релиз — BB_GUI_DIALOGS=1).
- Quickstart починен по-настоящему: seed = 32-битные Dev/Code/*.ocf
  закоммичены (dev0 грузит компилятор оттуда); fresh-clone проверен
  end-to-end (сборка + probes 22/22). LinIntInit — отдельным проходом
  после Cons (err 152), ОбxCompileLog — через build-dev64.
- Инцидент: OdcTextU.Batch в полумёртвой консоли записал битый Kernel.odc
  → 171/231 модулей перестало собираться. Восстановление: git checkout
  нетронутых .odc + реконвертация через bbcb2 OdcTextU.Import (UTF-8).
- test64 ВАЙПИТ и внешние подсистемы (Cuda/Code) — после полной
  пересборки внешние пересобирать их build.sh (~/sources/bbext/Cuda/build.sh).
- probes 22/22, мир бутится с полным набором Dev-модулей.

## ТЕКУЩЕЕ СОСТОЯНИЕ (2026-08-18, ночь 2)

### Dev-инструменты в 64-битном мире (build-dev64.sh)
- Добавлены и работают: DevSearch, DevReferences, DevRBrowser, DevDependencies,
  DevInspector, DevLinkChk, DevCmds. Binary-only .odc (без .odc.txt) копируются
  в мир как есть и компилируются — источник появится только когда модуль
  потребует правок.
- ОТЛОЖЕНЫ (падают/не собираются, отдельная работа):
  - DevAnalyzer — ТЕЛО модуля трапится (SIGILL через битый указатель →
    Views+0x4c07); лоадер грузит ВСЕ модули мира при буте, поэтому один
    падающий init кладёт весь мир (probes 0/22). Порт: завести
    Analyzer.odc.txt и чинить (ResetOptions/LoadOptions → Dialog.Update?).
  - DevBrowser, DevHeapSpy, DevMsgSpy — err 249 inconsistent import
    (PVFP mismatch) — тянут 32-битный sym-rot DevCPM (KB/Bootstrap32-symrot.md).
  - DevDebug, DevProfiler — err 113/123, нужен порт исходников (INTEGER/
    LONGINT), .odc.txt пока нет.
- Урок: добавление модуля в мир = он попадает в boot-init ВСЕГДА; тело
  модуля обязано быть безопасным. Проверка после доборки: probes + бут.

## ТЕКУЩЕЕ СОСТОЯНИЕ (2026-08-18, ночь)

### Подсистема Cuda — биндинги внешних .so (KB/SoBindings.md)
- Подсистема Cuda (CudaRt/CudaBlas/CudaFft + тесты) сделана и ВЫНЕСЕНА из
  bbcp: сторонние подсистемы живут в отдельных репах (как bbext/Http) и
  ставятся через Paket. Локально: ~/sources/bbext/Cuda (свой build.sh
  собирает её в мир bbcp64use). Проверено на 2×RTX: все 3 теста OK.
- Правила биндингов (грабли): dll-модуль = только [ccall] без тел (обёртки
  в соседнем модуле); адрес данных dyn-массива = SYSTEM.ADR(a[0]) — VAL даёт
  хедер (+28!); untagged NEW запрещён (VAR untagged буфер); 0X вместо 0S;
  cuBLAS v2 символы с суффиксом _v2; cufftHandle = int.
- Инфраструктура: скрипты tools64 вычисляют корень репо по своему пути
  (env64.sh) — клон в любой каталог, мир переопределяется BBCP64USE.
  probes.sh понимает полные имена (CudaTest.Go), не только Obx*.
- Документы: QUICKSTART64.md (сборка из чистого клона), REPORT64.md,
  KB/PortBrief.md, KB/PortHistory.md, KB/Bootstrap-seed.md.

## ТЕКУЩЕЕ СОСТОЯНИЕ (2026-08-18, вечер)

### bbcp самодостаточен (коммит 284ff345)
- Round-trip .odc больше не требует bbcb2: модуль `OdcTextU` (bbcp
  `Odc/Mod/TextU.odc.txt`) скомпилирован в мир и гоняется в консоли BB64
  (`BB_CONSOLE=1 bbrun64 --console`). Пакетная команда `OdcTextU.Batch` читает
  /tmp/odc-batch.txt (строки `I "in.txt" "out.odc"` / `E "in.odc" "out.txt"`).
  ВАЖНО: из bbcp-версии убран импорт DevCommanders — иначе OdcTextU не грузится
  в окне, когда Dev пересобирается.
- Грабля, пойманная и вылеченная: ConsInterp САМ импортирует DevCommanders
  (канал параметров команд) → build-dev64.sh компилирует DevCommanders ПЕРВЫМ,
  до Batch-конвертации; иначе "code file for DevCommanders not found" диалог.
- test64.sh порядок: sync-odc (до вайпа) → wipe → CompileSubs → Kernel64 →
  OdcTextU → Fig → build-dev64 → link-sym. mkworld64.sh — скелет мира с нуля.
- Полный цикл с нуля проверен: exit=0, 229/230 (ObxCompileLog добирается
  в build-dev64), probes 22/22. bbcb2 остаётся только как эталон Hr.

## ТЕКУЩЕЕ СОСТОЯНИЕ (2026-08-18)

### Точечные фиксы из аудита IntPtr (KB/IntPtrAudit-64.md)
- `System/Mod/Meta`: Copy — `n: INTEGER` -> LONGINT (принимал кучевой указатель,
  усечение!), тег динамического типа читается по `-8` (было -4); PutParam —
  новый локал `pl: LONGINT`, тег по `pl - 8`; recTyp-ветка пишет дескриптор
  типа в data-слот как LONGINT (был VAL(INTEGER) — работало т.к. модули <2ГБ).
- `Lin/Mod/Files`:687 — THISARRAY(VAL(LONGINT, target)) (был INTEGER; указатель
  из libc canonicalize_file_name может быть высоким).
- `Std/Mod/Debug`:~490 проверен — `ta := a + 4` там КОРРЕКТЕН (чтение старшей
  половины 8-байтного LONGINT для hex-вывода), не баг.
- Скомпилированы Meta, LinFiles (go64.sh), probes.sh 22/22.

### Унификация .odc.txt в UTF-8 (KB/OdcTextUtf8.md)
- Причина cp1251: OdcText ходил через StdTextConv ExportText/ImportText
  (8-бит ANSI). Создан OdcTextU в bbcb2 (Odc/Mod/TextU.odc) на
  ImportUtf8/ExportUtf8; sync-odc.sh и build-dev64.sh переключены.
- 6 файлов cp1251 -> UTF-8; в System/Mod/Dialog сырой байт 0xC0 был в КОДЕ
  (char-литерал "À") -> заменён на 0C0X. Все 40 не-ASCII файлов
  переимпортированы: в .odc теперь настоящая кириллица (был mojibake).
- Round-trip проверен (Meta): diff только в косметических w/h view-тегов.

### Дальше
- TODO64-маркеры РАЗОБРАНЫ (2026-08-18, коммит 350892c3): все 5 были сделанной
  работой с ярлыком; Kernel.AllocateCluster chain-guard оставлен как инвариант.
  Дополнительно StdDebug.ShowPointer: проба IsReadable от -8 (коммит d504e444).
- Known-issues ПРОВЕРЕНЫ 2026-08-18 — всё закрыто ранее:
  INTO→JO сделан (KB/Ovflchk-JO.md, 6 мест GenAssert(ccNO, ovflTrap));
  TLS — осознанный fail-fast err 271 вместо redesign (KB/TLS-guarded-failfast.md,
  CPCamd64:2586 не актуален). Остались minor: g_object_unref на выходе GUI
  (не воспроизводится), ld.so _dl_fini (низкий приоритет).
- Расширения (Aos, Crypto, _Http, Json, Mcp, Fjson, Async, Co_ и т.д.) —
  НЕ переносим в bbcp: это отдельные пакеты, ставятся через Paket, порт каждого
  — работа в его собственном репо.
- Платформенные подсистемы (Win, Ole, Com, Ctl, Mdi, Fbsd, Nbsd, Obsd)
  ОСТАЮТСЯ: целимся в Windows/Linux/FreeBSD. Сейчас они 32-битные; порт
  на amd64 — отдельный этап per-platform (Win: PE/amd64 загрузчик + кодген
  Win64 ABI; Fbsd: elf + libc-вызовы).
- Paket оставить: это пакетный менеджер, нужен для установки расширений.

## ТЕКУЩЕЕ СОСТОЯНИЕ (2026-08-17)

### Этап 3: мёртвый код Int64-пар/FPU удалён (native Int64 — единственный путь)
- Удалено: `CPCamd64` MakeLongHi/LongAdd/LongSub/LongNeg/LongCmp (мёртвые
  lo/hi-хелперы), ветки intrealtyp в Push/Entier; `CPH.UseReals` целиком
  (+ константы force/hide); `CPT.intrealtyp` (объявление + PostSetup);
  мёртвая ветка intrealtyp в `CPVamd64` (Ndop). Зеркально почищены
  CPC486/CPV486 (486-бэкенд, чтобы хотя бы компилировался).
- LoadLong ЖИВОЙ (single-reg Int64) — не трогать. x87-ветки для REAL
  остаются (REAL-арифметика на FPU — отдельная тема).
- Экспортированный интерфейс CPT изменился → см. инцидент ниже.
- `CPH.odc.txt` и `CPV486.odc.txt` созданы (их не было — ссылки на
  intrealtyp прятались в бинарных .odc!).

### Инцидент: сломался 32-битный bootstrap (dev0) и починен
Удаление CPT.intrealtyp → dev0 не грузил свой компилятор. Починено через
чужой компилятор bbcb2 + scratch /tmp/recov2 (рецепт в
KB/Bootstrap32-symrot.md). Полный go32-прогон цепочки CP* — ok (кроме
DevCPM — pre-existing sym-rot, его ocf рабочий, не трогаем).
ПОБОЧНЫЙ ЭФФЕКТ этапа 3: 32-битная пересборка Kernel/System больше
невозможна (нативный Int64 vs 486-бэкенд без intrealtyp → err 260).
Принято: 32-bit legacy выкидываем, компилируем 32-бит только DevCP*.

### Верификация этапа 3 (всё зелёное)
- go32.sh: 12/13 модулей ok (DevCPM — rot, пропущен осознанно).
- test64.sh System Lin Std Text Form Cons Obx: failed=1 of 222
  (косметический ObxCompileLog в CompileSubs; build-dev64.sh добирает,
  ocf свежий) + FigCmds/DevCompiler64/ConsCompiler64/Kernel64 ok.
- probes.sh: **20/20 PASS**.
- Консоль: OpenBrowser Tut-2 завершается без зависания.
- GUI-проверка пользователем: ожидается.

### Открыто (следующие задачи)
- INTO→JO (ovflchk, только allchecks); CPCamd64:2586 TLS redesign;
  g_object_unref CRITICAL на выходе GUI (minor); ld.so _dl_fini (низкий).
- Sym-rot bbcp (KB/Bootstrap32-symrot.md): Kernel.osf 64-битный,
  DevMarkers/DevCPM 32-бит не пересобираются. Стратегия: self-hosting.
- Потом (отдельный этап): перенос мира в папку bbcb (самодостаточность).

## ТЕКУЩЕЕ СОСТОЯНИЕ (2026-08-08)

### Что работает
- Полная сборка `System Std Text Form Lin Cons` + Dev-пайплайн: **142 модуля,
  0 ошибок** (CompileSubs теперь не стопается на первой ошибке, печатает сводку).
- **Бут до MAIN OK**: все тела модулей проходят ("body loop finished"),
  LinRegistry.Init работает (Startup.Setup-заглушка вызывается), console-REPL
  (LinIntLoader → LinIntInit → ConsInterp) принимает команды; GUI-режим доходит
  до Loop.Start и чисто выходит (нет открытых окон — exitWithoutWindows).
- **GC Mark/MarkGlobals работают** (InHeap-охрана, ptrs 4-байт).
- Исправлены: VAL Int32→Int64 (ConvMove sysval), CPM WordPair (err 113 —
  селектор от VAL-результата не designator), LinFiles64 Read/WriteBytes
  (pointer-идиома), StdTables/StdDebug (SHORT(ADR)), StdRasters (Q0/Q1
  переписаны на индексацию RasterData), LinRegistry.odc (был текстом!),
  ConsCompiler64 снова собирается.

### Где остановились
- РЕШЕНО: GC Mark спускался в bump-heap арены → mark-бит навсегда → краш
  dispatch (WriteSChar). InHeap-охраны на входе и спуске (Findings64 п.58).
- REPL выполняет команды без параметров (Startup.Setup, Kernel.Collect).
- Краш DevMarkers.SizePref+0xa9 на команде с параметрами: результат
  Fonts.dir.Default() читается как 0x0000000f00000000 (Findings64 п.60).
  Подозрения: pvfp-рассинхрон Fonts (два отпечатка в одной сборке),
  выравнивание pointer-полей.
- GUI: ни одно окно не открывается на старте → event loop сразу выходит.
  Нужно открытие первого окна (Log?) — смотреть 32-битный LinInit/StdCmds.
- Убрать debug-принты разработчика из LinRegistry.Init ([LR] ...) когда
  SearchVar будет починен (TODO64: Meta.Lookup виснет — заглушка RETURN FALSE).

### Проверка коммита разработчика (3d9a06e7, 2026-07-24)
Вердикт: направление верное (VAL-оверлеи, SetErr, LinRegistry typed GetVal),
но дерево осталось сломанным: CPM не компилировался (err 113 → каскад 249 в
DevCompiler64), Lin/Mod/Registry.odc перезаписан текстом, ConsCompiler64
выкинут из build-dev64 (REPL: CodeFileNotFound), 32-бит Sym рассинхронирован
(Text/Std протухли → DevCompiler64 не пересобирался), тест-модули
закоммичены в System/Mod (TA6 грузился при буте). Всё разобрано, Findings64
п.45-58.

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
- РЕШЕНО: MAXMODS=128 обрезал скан (131 модуль) — ConsFonts/ConsLog/
  DevCommanders терялись → 0 pending, KERNEL OK (коммит 43f73bd5).
- РЕШЕНО: ErrLog/BufLog de-virtualization (plain-процедуры; OCF v2 без VarBlk
  не инициализирует interface-глобалы) — коммит a4237caf.
- РЕШЕНО: StdLoader.Fixup 64-бит по эталону bbrun64.c (коммит 950cbfe0).
- РЕШЕНО: LinDl 64-бит (PtrVoid=LONGINT, [ccall16]→[ccall]) — cf1a1382.
- РЕШЕНО: MAP_32BIT для модулей/кучи (INTEGER-капы интерфейсов и 32-битные
  чтения тегов в GC Mark требуют арену < 4 ГБ).
- РЕШЕНО: Dev-пайплайн компилятора собран в BB64 (DevCP* + DevCompiler64 +
  ConsCompiler64 = ConsCompiler поверх DevCompiler64) — build-dev64.sh,
  запускается автоматически в конце test64.sh. ConsCompiler64 = Compiler64.odc.txt.
- Подготовлено: ObxHello + tools64/smoke-console.sh (compile+run в консоли),
  bbrun64 --console (консольный LinIntLoader вместо GUI LinLoader).
- GTK-аудит готов (KB/Gtk64-Audit.md): алиасы, GdkEvent×8, xmm/double×31,
  varargs, колбэки. Идёт миграция типов [ccall16]→[ccall] + алиасы (агент).
- ТЕКУЩИЙ блокер: таблица методов LinKernel.Platform сдвинута на слот
  (слот k = метод k+1, первый = 0, последний = мусор) — краш при вызове
  платформенного метода в LinPackedFiles init. В работе (агент).
- Дальше по плану: (1) method table → MAIN OK; (2) smoke-console (HelloWorld);
  (3) exceptions/callbacks (SysV Enter, isGuarded); (4) GTK 64-бит → LinGui.

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

## 2026-07-24 (сеанс 2): бут дошёл до цикла тел модулей
- LinFiles.ReadBytes/WriteBytes: `SYSTEM.ADR(x) + beg` компилировался в 32-битный
  add + cdq (Int64-сложение в бэкенде) → стековый адрес усекался и знакорасширялся
  (rdi=0xffffffffffffc7a8). Фикс: `SYSTEM.ADR(x[beg])` — без арифметики.
- Порядок инициализации в bbrun64 был неправильный: LinIntLoader вызывался как
  инфра ДО тел остальных модулей; InitModule-рекурсия останавливается на первом
  init-модуле → Dialog тело шло раньше Librarian → Librarian.lib=NIL → краш в
  LoadModStringTab. Фикс: цикл тел по loadOrder, лоадер последним;
  LinInit/LinIntInit исключены из статического скана (грузятся StdLoader'ом).
- Раскладка dyn array приведена к консенсусу (KB/ArrayHeader64.md):
  4-полевой Block (tag,last,actual,first), len[0] по x+0x18, headSize=4n+24.
  Были рассинхронизированы: Kernel64.NewArr (заглушка nofelem*8),
  System Kernel (8n+24), LenDesc (+8), SetDim (x+12), DeRef.
  LenDesc: VarPar (стек) +8, Ind (heap) +16 — ветки РАЗНЫЕ, единый INC ломает.
- Kernel64.NewBlock: +8 под тег (было переполнение на 8 байт).
- Kernel64.NewArr: полноценный (elsize по коду типа, last/first, headSize).
- GenCaseJump (CPLamd64): REX.X (42H) вместо REX.B (41H) → jmp [rbx+r8*8]
  вместо [r11+rax*8] → прыжок на стек в Kernel64.NewArr (CASE eltyp).
- sigaltstack: EPERM + мусорный ss_size. ДВЕ причины: (1) компилятор
  выравнивает поля RECORD максимум на 4 → LONGINT-поля после 4-байтных встают
  по +12 вместо +16 → ВСЕ libc-структуры со смешанными полями требуют явных
  pad-полей (stack_t, sigaction_t исправлены; полный аудит — агент-7,
  KB/LibcLayout64-Audit.md); (2) InstallSignals зовётся дважды (тело LinKernel +
  LinGui.Init даже в консоли) → второй вызов EPERM (alt stack активен) →
  сделан идемпотентным (запрос состояния, ss_sp = sigStack → ok).
- Assign Con→Int64 в DevCPCamd64 корректен (два movl: lo+hi dword) — НЕ баг.
- GenCaseJump: REX.X вместо REX.B — любой CASE с таблицей прыгал по
  [rbx+r8*8] вместо [r11+rax*8].
- go64.sh НЕ делает sync-odc (правки .txt не попадают в .odc!) — порядок:
  sync-odc.sh → go64.sh. Модуль называется ПОЛНЫМ именем (LinFiles, не Files).
- bbcp64use/System/Mod — пофайловые симлинки: новый модуль надо линковать руками.
- DevOnce.Go64 компилирует без sys-опций → [untagged] и др. дают err 225
  (pos врёт). Для микро-тестов использовать модули без sys-флагов.
- LinGui.Init грузит GTK и зовёт gtk_init_check даже в консоли; при argc=0/argv=NIL
  (bootInfo=NIL) gtk_init_check падал и Msg() открывал МОДАЛЬНЫЙ gtk_dialog_run
  (процесс вис в poll на X). Фикс: bbrun64 заполняет Kernel.bootInfo
  (modList/argc/argv; раскладка CP: argv@12).
- Агент-7 (аудит libc-раскладок): siginfo_t — АКТИВНЫЙ баг (si_addr по +12 вместо
  +16, HandleTrap читал мусор), tmDesc, _pad 28, si_band: long — исправлено;
  GTK-записи (GtkSelectionData, GdkEvent×17, GObject-иерархия и др.) съезжают —
  отдельный список в KB/LibcLayout64-Audit.md для GUI-этапа.
- StdInterpreter краш: prologue-заполнение локалов (InitOutPar/InitPtrs2/
  AllocAndInitAll) использовало MakeReg(DI/SP, Int32) → lea/mov 32-бит →
  стековый адрес усекался (rep stos по rdi=0xffff9de8). Фикс: форма Pointer.
- Kernel.NewRec/NewArr: НЕ трогать сигнатуры INTEGER (арена < 2ГБ, err 220/777
  от бэкенда при LONGINT-парамах). Реальный баг был SHORT(S.ADR) = 16 бит.
- Files.dir: корень = dirname(/proc/self/exe), поэтому bbrun64 требует
  BB_STANDARD_DIR=<корень проекта> (иначе динамическая загрузка ищет
  Code/ под Dev/Rsrc). bbrun64 сам инжектит bootInfo (argc/argv).
- Kernel.processor должен быть 12 (amd64), иначе StdLoader: syntax error.
- Инструмент: tools64/crash.sh — краш → Module+offset+регистры+стек+дизасм.
- SysV Enter (этап exceptions/callbacks): [ccall]-процедуры, вызываемые ИЗ C
  (HandleTrap, GTK-колбэки), раньше читали аргументы со стека — а C кладёт их
  в регистры. В Enter* (CPCamd64) для sysflag=ccall: pop r11; push r9..rdi;
  push r11 → тело видит cdecl-раскладку, эпилог (leave; ret 0) менять не нужно.
  CP→CP вызовы ccall (SysVPreCall кладёт аргументы и в регистры, и в стек)
  остаются совместимы. Ограничение: >6 аргументов и xmm не покрыты (KB).
- tools64/subs64.sh — инкрементальная пересборка подсистемы без вайпа.
- SysV xmm: SysVPreCall теперь классифицирует слоты аргументов: Real64 →
  movsd xmm0-7, int → rdi..r9, остаток → стек (в порядке слотов). Закрывает
  пункт аудита про gdouble (cairo_*, gtk_adjustment_new и др.). Real32/movss
  и >8 float-аргументов не покрыты.

## Сессия 2026-08-08 (день): краш SizePref РАЗОБРАН, GC починен до конца

Цепочка SizePref (Findings64 п.60-64):
1. watchpoint-форензика от краша вверх: a.font=0xf00000000 ← ViewRef.attr=
   StdModel ← wr.attr ← r.attr ← run.attr ← piece.attr = Stores.CopyOf,
   вернувший валидный Attributes, потом GC его СОБРАЛ и слот переиспользовали
   (tag-watch: Kernel.Insert=free → Kernel.NewRec=reuse как StdModel).
2. Причина сбора: ДВА аллокатора (Kernel64 bump vs CP Kernel кластеры) —
   NEW шёл в bump (bbrun64: kernel="Kernel64"), Mark не видел детей
   bump-объектов. Фикс: bbrun64 перерешивает NewRec/NewArr на CP "Kernel"
   для всех модулей, загруженных после него.
3. Следом вскрылись 3 бага GC: [code] Next шаг (size+19 без clamp) против
   NewBlock (size+23, min 24) против free-size=total-4 → обвал цепочки
   блоков в CheckCandidates (краш Next, tag=0). Согласовано: +23, min 32,
   free-size=total-8, sliver-absorb. ВАЖНО: живая Next — [code] с байтами,
   CP-Next — комментарий!
4. ExecFinalizer: S.GET(ar.a, fin) = двойное разыменование (байты метода
   вместо адреса) → S.GET(S.VAL(LONGINT, ar), fin).
После фиксов: Compile бежит (прогресс 'c'), Kernel.Collect проходит.
НОВЫЙ блокер (Findings64 п.66): ASLR-зависимый краш — вне gdb периодически
SIGSEGV→рекурсивный трап в динамическом модуле; core: отложенный fault
fistpl(%rsp)→fwait, rsp высокий (0x6007_xxxxxxxx). Под gdb/setarch -R чисто.

== 2026-08-09: КОРЕНЬ ВСЕХ КРАШЕЙ НАЙДЕН И ПОЧИНЕН ==
1. Диагностическая цепочка: ThisFinObj SEGV (blk=0) → watch-форензика:
   free-блок [0x60003378, +560) накрывает живой FList-узел → зануление из
   NewBlock Erase. В Kernel добавлены инварианты: FinChainHit + ASSERT
   30/31/32 (Insert), 21 (NewBlock), 101 (ThisFinObj) — поймали момент
   коррупции: Insert(blk=0x60000038, size=0x60000038) — size=blk!
2. Разбор кодгена NewBlock: Insert(b+tsize, a) — b+tsize считается на x87
   (fildll/fiaddl), push-последовательность: push a; fild; fiadd;
   sub rsp,8; fistpll [rsp]; push [rsp] — ДУБЛИКАТ слота: callee видит
   size = b+tsize вместо a (+ утечка 8 байт на вызов).
3. Причина x87: узел LONGINT+int типизируется intrealtyp (form=Real64) →
   CPVamd64 Ndop → FloatDOp (по дизайну компилятора). Доказано DBG-TRACE
   assert'ами 91/92/95/107/108 (потом удалены).
4. ФИКС (CPCamd64.Param): ветки Pointer и Int64 (SysV):
   `IF ap.mode # Stk THEN GenPush(ap) END` — FPU-значение уже на машстеке.
5. Полная пересборка (0 failed of 125) → Compile Hello.cp =
   0ErrorsDetected, краша нет, Kernel.Collect чисто.
ОТКРЫТО: (a) вызов ObxHello.Do через StdInterpreter → wild pc → SIGILL
   HandleTrap+0xef (финальный HALT) — вероятно ещё один вид рассинхрона
   параметров (Meta/CallHook); (b) SIGFPE-каскад в HandleTrap (FPU cw=0x33E,
   IM не замаскирован) — следствие любого трапа; (c) GUI-окна.

== 2026-08-09 (2): трап-машинерия на LONGINT ==
1. SIGFPE-каскад разобран: LinKernel.HandleTrap SHORT(gregs[REG_RSP]) —
   стек 0x7FFF... не влезает в INTEGER → fistpl FPE_FLTINV (IM в cw=0x33E
   не замаскирован) → рекурсия. Фикс: pc/sp/fp/val → LONGINT в обоих
   ядрах + интерфейс GetTrapInfo + TrapTitle/SigToErr; StdDebug на
   LONGINT-адреса.
2. Побочно найдено: Kernel.ADDRESS не был экспортирован (osf → отдельный
   тип → err 113 у вызовов); Kernel.IsReadable была INTEGER-обёрткой.
3. Новое ограничение кодгена: SYSTEM.GET(LONGINT-выражение, x) → err 220
   (intrealtyp→FPU→Stk, CPCamd64.Mem не Con/Reg). Обход temp-переменной.
4. Трап-репорт чистый. Дальше: GUI event loop (краш в GTK-нити),
   StdInterpreter-вызов команд, открытие первого окна.

== 2026-08-09 (3): GUI — первое окно не открывается (В РАБОТЕ) ==
Симптом: gtk_window_new вызывается 1 раз, show_all/realize — ни разу,
"body loop finished" (exitWithoutWindows), молчаливый выход.
Детали цепочки и план — Findings64 п.74. Кандидаты обрыва:
ConnectSignals (LinBackends, не читан), Dialog.Call(StdConfig.Setup)
возвращает res_#0 молча (ошибка в ShowMsg без окон), либо SetupWorkspace.
Следующий шаг: [LR]-принты configCmd/res_ в Lin/Mod/Init.odc.txt,
go64.sh LinInit, GUI-прогон bbrun64; затем gdb-брейки на
StdWindows.Init / SetupWorkspace / NewBackend / Backend.Open.
После GUI: краш ObxHello.Do (wild pc в GTK-нити) — вероятно та же болезнь.
Отложено осознанно: SYSTEM.GET(LONGINT-выражение) err 220 — фикс кодгена
(Findings64 п.72). Не забыть вычистить bbrun64_clean/bbrun64_g из
старого коммита 5260e5be.

== 2026-08-09 (4): GC sliver-absorb a=16 — КОРЕНЬ крашей при больших компиляциях ==
Компиляция IMPORT LinLibc → первый GC → SIGSEGV в CheckCandidates/[code]Next.
Полный разбор: Findings64 п.75. Фикс: GetOldFreeBlock пропускает блоки с
остатком 16; NewBlock ASSERT 22; absorb-ветка удалена.
Попутно выяснено (важно для отладки): Console.WriteStr БЕЗОПАСЕН и в GUI
(LinConsole.Init ставит Console при загрузке — LinInit его импортирует);
ADР-err-113 в LinInit был из-за краша/проблем при импорте Libc.osf, а не из-за
ADR (Probe5: a := SYSTEM.ADR(b) компилируется нормально).

== 2026-08-09 (5): анализ процесса + стратегия верификации ==
См. KB/Verification64.md. Выводы: краши — запаздывающие проявления
нарушенных инвариантов (куча/кодеген); инварианты не были записаны
исполняемо. Решения: Kernel.ValidateHeap (тайлинг, free-list, дескрипторы),
единая формула stride + boot self-tests, ASSERT-уровни в проде,
peephole-проверка form/REXW в кодегене, [code] -> CP где можно.
Систему НЕ переписываем — архитектура здоровая, добавляем
верификационный слой. Текущая охота: use-after-free DevCPT (Findings64
п.76 продолжение): live-объект не помечен; версии — ptroffs дескриптора
не покрывает поле или guard отрезал путь.

== 2026-08-09 (6): серия фиксов GC/кодегена + текущая точка ==
СДЕЛАНО (всё закоммитить!): sliver a=16 (GetOldFreeBlock), Mark guard
(дескриптор обязан быть в модульной памяти — вход и down-шаг),
baseStack=0 (тело Kernel: IF baseStack=0 THEN GETREG), CPLamd64 REXW
(Int32-глобал грузился r64 — мусор в индексах), GETREG/PUTREG Int64
(split/join пар: новые CPCamd64.PtrToLong*/LongToPtr*, CPVamd64
getrfn/putrfn). Подробности: Findings64 п.75-81. Стратегия верификации:
KB/Verification64.md (инварианты, ValidateHeap, boot self-tests).
ТЕКУЩАЯ ТОЧКА (Findings64 п.82-83): 
1) in-BB компиляция не пишет .ocf (нет syscalls) → CommandError
   CodeFileNotFound на запуске свежего модуля; копать OutCode→RegisterObj
   vs Files.Register (LinFiles 64-бит).
2) GC use-after-free DevCPT.Struc: скан стека слот читает, но не
   маркирует; подозрение на FPU-кодировку `~strictStackSweep OR p MOD 16
   = 0` (константа fcomps не проверена) — см. п.83.
3) GTK-нити (pango) шумят сигналами в HandleTrap (п.84).
LinInit.odc.txt содержит НЕКОМПИЛИРУЮЩИЕСЯ debug-принты P/PR/PLn через
Libc.write+SYSTEM.ADR (err 113!) — перед продолжением GUI-ветки
ПЕРЕПИСАТЬ их на Console.WriteStr (Console жив и в GUI — LinConsole.Init;
Probe7: Strings+Console компилируются). err 113 с SYSTEM.ADR(b) в
аргументе Libc.write — отдельная загадка (Probe5: чистый ADR ок; файлы
с ADR в LinFiles ок) — вероятно связь с п.82/состоянием Libc.osf.
НЕ ЗАБЫТЬ: коммит (go64/test64/build-dev64 всё зелёное), вычистить
Probe*.cp из bbcp64use, Obx/Mod/Probe7.odc* leftover.

== 2026-08-15: КОРНЕВОЙ баг GC (MarkLocals) + GUI дошёл до StdConfig.Setup ==
СДЕЛАНО (всё в KB/Findings64 п.86-95):
- AllocModMem: единый mmap-регион на 4 блока модуля (иначе RIP-disp32
  не влезал → SIGFPE в StdLoader.Fixup) — п.86.
- LinKernel.ThisDllObj: StubFor-трамполины вместо SHORT(dlsym) — п.87.
- bbrun64: невыбранному лоадеру opts|=init (иначе GUI уходил в
  консольный REPL и тихо Quit(0)) — п.88.
- bbcp64use: Rsrc-симлинки ("cannot open menu file" закрыт) — п.89.
- КОРЕНЬ всех use-after-free: MarkLocals сканировал стек с FP≡4(mod8),
  все pointer-слоты читались со сдвигом 4 → якоря терялись. Фикс:
  выравнивание sp на 8 после GETREG — п.90. Консоль чистая, P10 OK.
ТЕКУЩАЯ ТОЧКА: GUI доходит до StdConfig.Setup (чтение Menus.odc через
Views.OldView) → SEGV в TextModels.Find+0xfc8 (v.len при v=NIL).
pre Find нарушен: m=4832 > t.len=4291; rd.pos/rd.state неконсистентны
(dword -1 рядом с pos=1 в reader). Гипотеза: 32/64 путаница в чтении
Stores/LinFiles64/StdReader. Детали — п.93. Пробник ObxProbe11 не
скомпилировался (err 83 pos 887,910) — поправить и воспроизвести
крэш в консоли.
ДАЛЕЕ: (1) починить Probe11 → репродукция в консоли; (2) аудит
Stores-чтения (ReadInt/версии/rd-era); (3) трап-репортер рекурсивно
падает (мусорный sp) — маскирует трапы; (4) первое окно GUI;
(5) in-BB компиляция не пишет .ocf (п.82); (6) GTK-нити/HandleTrap
(п.84). НЕ ЗАБЫТЬ: коммит сессии.

== 2026-08-15 (2): серия корневых фиксов — меню читаются, GUI рисует ==
1. MarkLocals: шаг 4 (не 8) — указатели на стеке бывают ≡4 (mod 8)
   (упакованные поля записей). КОРЕНЬ use-after-free всей недели.
   Доказано gdb-сканом стека в фатальном collect (KB п.96).
2. Views.Overwritten: -4*(mno+1) → -8*(mno+1) (KB п.97).
3. HandleTrap только на fault-сигналы (SIGCONT от glib-потоков убит)
   (KB п.98).
4. Try-машинерия INTEGER→ADDRESS: Kernel.TryHandler/Try, ExecFinalizer/
   TrapCleanup/Report, Dialog.Exec, Services (SHORT убран), TabViews.
   ExecNotifier, CPB StPar1 THISRECORD Int64 (KB п.99). Урок: err 115
   позиции вводят в заблуждение — инструментировать CheckParameters.
5. КОРЕНЬ "errors detected in menu file": CPLamd64.GenConOp ripTrail=4
   вместо 1 для byte-форм (cmp bool-глобала с imm8) → чтения bool/byte
   глобалов съезжали на -3 → StdMenuTool.noerr читался как FALSE.
   Фикс + полная пересборка мира (KB п.100).
6. КОРЕНЬ SEGV в pango_layout_get_text: SysVPostCall не снимал слоты
   аргументов (mov rsp,r12; pop r12 оставлял их на стеке) → при
   ВЛОЖЕННОМ ccall (ccall-результат как аргумент) слоты внутреннего
   вызова сдвигали аргументы внешнего: pixel_extents получал
   (line, мусор, NIL) вместо (line, NIL, &rect) → pango писал
   logical_rect в чужой объект → портил g_class layout'а. Фикс:
   SysVPostCall(nslots) + add rsp, nslots*8 (KB будет п.103).
После всего: мир пересобран, GUI доходит до отрисовки текста.
Открытые: трап-репортер рекурсия; in-BB компиляция (п.82);
ObxCompileLog/ObxTaAdr (err 249/220); Gtk64-Audit остатки (ccall16
миграция, REAL-аргументы, callbacks).

== 2026-08-15 (3): СРЕДА ЗАПУЩЕНА В 64 БИТАХ ===
7. SysVPostCall(nslots) — снятие слотов аргументов ccall (KB п.103).
8. LinKernel.StubFor: RETURN начала стаба, не start+11 (KB п.104).
9. C→BB callbacks: SysV Enter/Exit — сохранение rbx/r12-r15 и
   балансировка стека add rsp,96+jmp r11 (KB п.105). Меню работают,
   окно BlackBox + Log открываются, трапов нет. Скриншот проверен.
Всё закоммичено. Дальше: трап-репортер (рекурсия, мусорный sp),
in-BB компиляция (п.82, ConsCompiler64 → "0ErrorsDetected" но без
.ocf — CommandError CodeFileNotFound при запуске свежих модулей),
ObxCompileLog (err 249), ObxTaAdr (err 220 GET LONGINT),
GdkEvent-офсеты сверить с KB/GdkEvent-offsets.txt, REAL-аргументы ccall.

== 2026-08-16/17: Help→Contents и Help→About РАБОТАЮТ ===
10. КОРЕНЬ трапа ASSERT(bar=NIL) при Help→Contents: CPCamd64.Param
    пушил Int64-КОНСТАНТУ value-параметра двумя qword (наследие i386)
    → сдвиг всех последующих параметров; Services.DoLater(resetBar,-1)
    получал мусор. Фикс: mov rax,imm64; push rax (KB п.108).
    Probe21/22 подтвердили, мир пересобран (224 модуля, failed=0;
    известные err 249 ObxCompileLog / err 220 ObxTaAdr остаются).
11. КОРЕНЬ SEGV при Help→About: THISARRAY как value-параметр open
    array — conv-узел (intrealtyp) вокруг adr оставлял значение на
    машстеке (Stk), ActualPar делал второй Push → 6 слотов вместо 5 →
    out.ptr = len → Utf8ToString писал по адресу 3. Фикс: страж
    `ap.mode # Stk` в CPVamd64.ActualPar thisarrfn-ветке (KB п.109).
    Probe23 (Plain vs ThisArr) зелёный; About открывается с PNG-лого.
    Пересобраны Meta/Services/LinFiles/LinRastersPng.
12. Инфра: Docu-симлинки в bbcp64use (Help не находил Docu/Help.odc);
    bbrun64 пересобран unstripped (gdb-хелперы требуют modlist);
    отладка [DL]/[IT]/[IMM]/[BAR] вычищена из Services/StdDocuments;
    отладка [TA]/[ADR]/[EX]/[CV]/[ST1] вычищена из CPVamd64/CPB.
13. Методология: KB/Verification64.md п.6 — инвариант соглашения о
    вызове (caller pushes == callee ret N), probe-регрессия,
    ASSERT(ap.mode # Stk) как постусловие Push, план упрощения Int64
    (один 64-бит регистр вместо пары lo/hi), вывод i386-ветви.
ОТКРЫТО: создатель conv-узла вокруг THISARRAY-adr не найден (KB 6.6);
free(): invalid pointer при выходе; StdDebug падает при печати трапа;
About не подставляет Version/Build; in-BB компиляция не пишет .ocf
(п.82); ObxCompileLog err 249; ObxTaAdr err 220; smoke console.

== 2026-08-17 (2): in-BB компиляция работает, err 220 убран ===
14. КОРЕНЬ падения компилятора внутри BB64 (SIGILL HALT(100) в
    DevCPM.Mark): CPLamd64.GenBitOp не выставлял ripTrail=1 для
    bt m32,imm8 → rip-фиксап с immLen=0 вместо 1 → чтение глобала по
    target+1 → `trap IN options` читал мусор → ложный HALT (KB п.113).
15. КОРЕНЬ ObxTaAdr err 220: CPVamd64.Mem не принимал Stk/Ind от expr
    (адрес-выражение a+4 в SYSTEM.GET) — фикс: материализация через
    LongToPtr/Load (KB п.114). Probe26 зелёный, код верен.
16. п.82 ЗАКРЫТ: .ocf пишется (побочный эффект п.108/109); Probe2.T
    выполняется в BB64-консоли. Probe24: LONGINT-арифметика верна.
17. Симлинки: Docu (ранее) + Sym (tools64/link-sym.sh, вызов из
    test64.sh — иначе wipe). Механизм dev0: BB_USE_DIR=cwd(=bbcp64use),
    fallback чтения в BB_CUSTOM_DIR/standardDir=bbcp — поэтому мир
    собирался по 32-битным portable osf и не писал 64-битные.
18. ObxCompileLog портирован на DevCPVamd64; in-BB компиляция даёт
    err 249 (inconsistent import, fp TextModels.Attributes^ /
    Properties.Property^) — смешение 32/64 osf; known issue,
    не блокер (ConsCompiler64/DevCompiler64 покрывают функциональность).
ОТКРЫТО: free(): invalid pointer при выходе GUI; ld.so _dl_fini assert
при выходе из консоли ПОСЛЕ трапа; StdDebug падает при печати трапа;
About Version/Build; ObxCompileLog err 249; conv-узел вокруг
THISARRAY-adr (создатель не найден); verify-callconv.py; Int64 в
одном регистре (KB Verification64 п.6.4).

== 2026-08-17 (3): GUI-верификация пройдена ===
19. Живой GUI (MCP-клики): Help→Contents ок, Guided Tour ок, About ок,
    Obx→Trap! → StdDebug-окно трапа работает, система выживает,
    рекурсии нет. Выход: free(): invalid pointer УШЁЛ (п.117
    подтверждён). Остаток: GLib-GObject-CRITICAL g_object_unref на
    выходе (нефатально, minor); фреймы Module.??? в трап-окне для
    неэкспортированных процедур (косметика). KB п.119.
ОТКРЫТО: g_object_unref на выходе (minor); ld.so _dl_fini assert при
выходе из консоли ПОСЛЕ трапа (низкий приоритет); ObxCompileLog
err 249; conv-узел вокруг THISARRAY-adr (создатель не найден, закрыт
стражем); verify-callconv.py; ASSERT-постусловия в кодегене; Int64 в
одном регистре (KB Verification64 п.6.4).

== 2026-08-17 (4): Int64-архитектура разгадана, LONGINT верифицирован ===
20. РАЗГАДКА: Int64-арифметика идёт через x87 FPU — DevCPH.UseReals
    перетипирует Int64-узлы в intrealtyp (клон real64typ) после CPB
    (KB п.120). Закрыта загадка conv-узла из п.108: его создаёт
    CPH.Convert(n, int64typ). CPH.odc без txt-экспорта — урок:
    grep по *.odc.txt не полон, для модулей без txt использовать
    odcey text.
21. Probe27/Probe28: LONGINT полностью верифицирован против Python
    (арифметика, DIV/MOD floor, ASH конст/перем, ABS/MIN/MAX/ODD,
    границы ±2^62, MAX/MIN LONGINT). Регрессия probes.sh: 19/19 PASS.
22. Ограничения (задокументированы, KB п.121): SYSTEM.LSH/ROT на
    LONGINT → err 260 (нужен целочисленный сдвиг Int64); переполнение
    Int64 → SIGFPE-трап вместо wrap (fldcw 0x33E размаскирует
    invalid-op); TODO64 на CPLamd64:804 (GenDiv Int64) — moot, GenDiv
    видит только <=Int32, комментарий можно поправить при чистке.
23. Инвентаризация TODO64-маркеров: Std/Debug(370,405 — SHORT, куча
    <4ГБ, безопасно пока MAP_32BIT), Std/Rasters(33,326 — закрыты),
    Lin/Registry:210 (Meta.Lookup виснет — stub RETURN FALSE),
    CPCamd64:2586 (TLS redesign), Compiler64:647 (по дизайну),
    CPM:475 (регистровая диагностика -777/-778/-779), CPLamd64:804
    (moot, п.120).
ОТКРЫТО: SYSTEM.LSH/ROT на LONGINT (err 260); g_object_unref на
выходе GUI (minor); Lin/Registry:210 Meta.Lookup hang; ld.so _dl_fini
после трапа в консоли (низкий); ObxCompileLog err 249; verify-
callconv.py; ASSERT-постусловия в кодегене; CPCamd64:2586 TLS.

== 2026-08-17 (5): нативный Int64 (этап 2) сдан; ОТКРЫТА regress-зависалка ===
24. Этап 2 закрыт коммитом 5a19d12f: single-reg Int64, UseReals off,
    мир 222 модуля (failed=1 known FP249), probes 20/20, GUI грузится,
    About/Contents/меню работают. Подробности KB п.122.
25. ОТКРЫТО (блокер): зависание OpenBrowser('Docu/Tut-2') — куча
    раздувается до ~1300 кластеров 256KB -> квадратичный GC
    (Kernel.InHeap). Разбор и план: KB/HangTut2-GC-clusters.md.
    Консольная репродукция: echo "StdCmds.OpenBrowser('Docu/Tut-2','x')"
    | BB_CONSOLE=1 BB_STANDARD_DIR=~/sources/bbcp64use bbrun64 --console.
26. Workflow-улучшения: bbcp64use/*/Mod — симлинки (было протухшие
    копии — ловушка!); test64.sh добирает Kernel64; gdb-gui.sh —
    GUI под gdb через FIFO (ptrace_scope=1); Probe31.cp (Allocated/Used).
ОТКРЫТО: зависалка Tut-2 (п.25); g_object_unref на выходе (minor);
Registry:210 Meta.Lookup; ObxCompileLog FP249; INTO->JO (ovflchk);
мёртвый код пары lo/hi + intrealtyp — удалить (этап 3); CPCamd64:2586
TLS redesign.

== 2026-08-17 (6): зависалка Tut-2 РЕШЕНА (sliver-shadowing) ===
27. ЗАКРЫТ блокер п.25: корень — наша же 64-битная поправка в
    Kernel.GetOldFreeBlock (sliver-правило `b.size - s = 16` skip)
    ломала инвариант «бакет = точный класс размера»: отвергнутый
    sliver-блок в низком бакете навсегда затенял большие блоки
    бакета 7 → каждый NewBlock мимо → GC на каждый промах → новый
    кластер 256KB → 1300 кластеров → квадратичный InHeap = вис.
    Фикс: внешний цикл по бакетам (i<N) при промахе. Доказано
    fail-fast'ом: дамп free[] на 301-м кластере (bucket2=40,
    bucket3=56, bucket7=41464). Полный разбор: KB/HangTut2-GC-clusters.md.
28. Уроки: (а) fail-fast инварианты > ловля виса gdb (Дейкстра):
    трап в точке нарушения дал дамп и корень за один прогон;
    (б) логирование из аллокатора ТОЛЬКО неаллоцирующими средствами
    (blog.string), BString/BInt растят blog.buf → NewBlock →
    рекурсия (Гейзенбаг в диагностике); (в) timeout всегда с -k.
29. В Kernel оставлен постоянный инвариант: цепочка > 300 кластеров
    → LDump free[] + HALT(77). Проверки: консольный OpenBrowser
    (Tut-2) завершается (allocated 6.3MB), Probe32 (3000 NEW ×
    2100B) — 50 кластеров, reuse идеален, probes.sh 20/20 PASS.
ОТКРЫТО: GUI-проверка Tut-2 пользователем; коммит фикса; этап 3
(мёртвый код lo/hi + intrealtyp); g_object_unref (minor);
Registry:210 Meta.Lookup; ObxCompileLog FP249; INTO->JO (ovflchk);
CPCamd64:2586 TLS; трап-репортёр зацикливается на битом fp-стеке
(cycle-guard в LogThisStack); GrowBuf округление (Kernel:610,
DIV прецеденс — len без округления вверх).

== 2026-08-17 (7): GUI-проверка пройдена, Fig добран ===
30. GUI: Tut-2 открывается без виса (подтверждено пользователем),
    фикс sliver-shadowing запушен b14e1102.
31. ЗАКРЫТО: серые X-боксы вместо схем в Tut-2 — подсистема Fig не
    была собрана в мире (FigViews.StdView — встроенные, не ресурсы).
    Создан bbcp64use/Fig (симлинки), собраны FigModels/FigViews/
    FigPoints/FigBasic/FigCmds; test64.sh теперь добирает Fig сам
    (wipe стирает ВСЕ подсистемы мира!). KB/FigViews-missing-X-box.md.
    GUI-проверка пользователем: схемы рисуются.
ОТКРЫТО: этап 3 (мёртвый код lo/hi + intrealtyp); g_object_unref
(minor); Registry:210 Meta.Lookup; ObxCompileLog FP249; INTO->JO
(ovflchk); CPCamd64:2586 TLS; cycle-guard трап-репортёра;
GrowBuf округление (Kernel:610).

== 2026-08-17 (8): мелкие TODO64/баги ===
32. ЗАКРЫТО Registry:210 — Meta.Lookup больше не виснет (Probe33:
    Meta.Lookup("Kernel") мгновенно; вис был тем же GC-штормом).
    Стуб RETURN FALSE снят, отладочные [SV]/[LR] принты убраны.
33. ЗАКРЫТО GrowBuf (Kernel:610): `(pos+by) + (logInc-1) DIV logInc
    * logInc` — DIV биндил не то, буфер рос впритык на каждый
    BAppend. Скобки расставлены.
34. ЗАКРЫТО зацикливание трап-репортёра: LogThisStack walker при
    sentry=NIL ре-инитил depth=-1 каждый шаг (все фреймы "0:") и
    крутился вечно. Локальный guard<256 + сообщение о truncation.
35. ЗАКРЫТО ObxCompileLog FP249: не смешение osf, а ПОРЯДОК сборки —
    CompileSubs строил его со стабом/старыми DevCP* sym. Теперь
    компилируется в build-dev64.sh после свежего Dev-пайплайна
    ("== ObxCompileLog ok"). Примечание: CompileSubs в test64.sh
    по-прежнему печатает failed=1 (косметика), финальный ocf верный.
Проверки: probes.sh 20/20 PASS после каждого шага.

== 2026-08-17 (9): lazy InitModule — детерминированная загрузка ===
36. ЗАКРЫТО "GUI не стартует / окно без меню / LinInit fileNotFound".
    Корень: LinRegistry.SearchVar шла по всему modList через Meta.Lookup
    → ленивый Kernel.InitModule каскадом исполнял ~80 тел в ОБРАТНОМ
    порядке посреди тела LinRegistry: GTK до gtk_init (CRITICAL-спам,
    отравленное состояние — нет меню), тело LinLoader стреляло
    преждевременно → LoadMod("LinInit") res=1 (мир не готов) →
    FatalError-диалог. appStartupProcedure нигде не определена —
    каскад был бесполезен. Фикс: SearchVar сканирует только
    инициализированные модули (16 IN m.opts); bbrun64.c помечает оба
    лоадера init ДО цикла тел (пометка в цикле запаздывает — LinLoader
    в loadOrder после LinRegistry), тело выбранного — явно в хвосте
    main. KB/LazyInitModule.md. Загрузка чистая: 0 CRITICAL,
    body loop finished, окно с меню (подтверждено пользователем).
37. [LL]-диагностика из LinLoader убрана (включая закоммиченный
    ранее "[LL] LoadMod res=" принт).
ОТКРЫТО: GUI-проверка About/Help→Contents/Tut-2 после фикса;
коммит+пуш; INTO->JO (ovflchk); CPCamd64:2586 TLS;
g_object_unref (minor).

== 2026-08-17 (10): INTO→JNO (ovflchk) ===
38. ЗАКРЫТО: INTO (0CEH) невалиден в amd64. CPLamd64: 6 мест
    GenByte(0CEH) → GenAssert(ccNO, ovflTrap=138) — JNO +3; 8D F0 8A
    → SIGILL → SigToErr даёт err=138 (как FPE_INTOVF в 32 бит).
    Пересобраны: dev0-генератор DevCPLamd64 (go32) и мир (build-dev64).
39. Инфра: DevCompiler64.CompileTextOpt (парсинг опций в ParseOpt),
    ConsCompiler64.CompileOpt(path,name,opt) — компиляция с allchecks
    in-world. Пробник ObxProbe30 (ожидаемый трап) + probes-trap.sh.
    Проверки: Probe30.ocf содержит 71 03 8D F0 8A, 0xCE нет;
    probes.sh 20/20, probes-trap.sh 1/1.
ОТКРЫТО: CPCamd64:2586 TLS; g_object_unref (minor); TODO64 в
Std/Debug (ref-курсоры LONGINT, SHORT-куча) и Dev/CPM:475.

== 2026-08-17 (11): TLS/FS:[0] — fail-fast вместо redesign ===
40. ЗАКРЫТО (как wontfix-failfast): guarded/interface процедуры (isGuarded)
    генерировали SEH-фреймы через FS:[0] — а там TLS glibc (self-pointer
    TCB). Потребителя цепочки на Linux нет: Kernel.InterfaceTrapHandler —
    assert-stub ("Running Windows/COM on Linux?"). Ни один модуль мира не
    использует TO INTERFACE/[guarded] — путь мёртв. Вместо redesign:
    CPVamd64.Parameters даёт err 271 ("guarded/interface procedures not
    supported on amd64 (FS:[0] is glibc TLS)", Dev/Rsrc/Errors.odc).
    Если когда-нибудь понадобятся интерфейсы — переделывать на глобальную
    переменную цепочки (см. LinKernel.currentTryContext), не на FS.
ОТКРЫТО: g_object_unref (minor); TODO64 в Std/Debug (ref-курсоры
LONGINT, SHORT-куча) и Dev/CPM:475; чистка [LI]-принтов LinInit.

== 2026-08-17 (12): TODO64 — ref-курсоры LONGINT, CPM -777 ===
41. ЗАКРЫТО GetRefProc/GetRefVar: курсор ref INTEGER→LONGINT (Kernel:
    RefCh/RefNum/RefName/GetRefProc/GetRefVar/CheckRefVarReadable/
    SourcePos/GetRefFrameDo; Std/Debug: 3 места, SHORT() убраны).
    Std/Debug ShowPointer: adr INTEGER→LONGINT (SYSTEM.GET 8 байт,
    SHORT(SYSTEM.ADR) убран). Адреса кода/кучи и так <4ГБ (MAP_32BIT),
    но усечение убрано по-честному. probes 20/20, trap 1/1.
42. ЗАКРЫТО CPM:475: подавление -777/-778/-779 снято — in-world
    компиляция 7 крупных модулей без единой диагностики. dev0-side
    DevCPM не пересобирается (sym-rot, PVFP mismatch) — там подавление
    осталось, безвредно. KB/Bootstrap32-symrot.md.
== 2026-08-17 (13): чистка [LI]-принтов LinInit (213816ac) ===
43. Убраны debug-процедуры P/PR, их вызовы и импорты Console/Strings из
    Lin/Mod/Init.odc.txt. GUI после чистки проверен: окно с меню, Log.
44. Сверка старых ОТКРЫТО с кодом: GrowBuf-округление (Kernel:610) и
    cycle-guard трап-репортёра (Kernel LogThisStack) УЖЕ сделаны ранее;
    этап 3 (мёртвый код lo/hi + intrealtyp) сдан коммитом 281611ed —
    единственная ссылка на intrealtyp осталась внутри (* *) в
    CPVamd64:1538. Пункты закрыты, просто не были отмечены.
ОТКРЫТО: g_object_unref на выходе (3 сессии чисто, ждём
воспроизведения под G_DEBUG=fatal-criticals); SYSTEM.LSH/ROT на
LONGINT (err 260 — реальная дыра языка); ObxCompileLog FP249 (known,
sym-rot); полный цикл GUI-верификации пользователем.

== 2026-08-17 (14): SYSTEM.LSH/ROT на LONGINT — уже работает, закрыто пробником ===
45. ЗАКРЫТО: err 260 для LSH/ROT на LONGINT из п.22 устарел — после этапа 2
    (single-reg Int64) путь работает: CPB принимает Int64 (intSet включает),
    CPVamd64 -> CPCamd64.Shift -> CPLamd64.GenShiftOp с REXW. Пробник
    ObxProbe34 (12 проверок: конст/переменный сдвиг, оба знака, логический
    сдвиг знакового бита, ROT через границу, INTEGER не сломан) — OK.
46. Фикс точности ranchk: CPCamd64.Shift для переменного сдвига проверял
    счётчик в -31..31 — для Int64 поправлено на -63..63. Пересобраны
    dev0-side (go32 DevCPCamd64) и мир (build-dev64.sh).
47. Знание (CPS.Number): hex-литералы — суффикс H = 32 бита (<=8 цифр),
    L = 64 бита (<=16 значащих цифр; 16 цифр и старшая > 7 -> отрицательный).
    Литерал обязан начинаться с ЦИФРЫ: 0C000000000000000L, не C00...L
    (иначе сканер читает идентификатор -> undeclared identifier).
    Копия в KB/CPS-hex-literals.md.
48. probes.sh: добавлен Probe34.Go (21/21 PASS, probes-trap 1/1).
== 2026-08-17 (15): полный цикл GUI-верификации ПРОЙДЕН ===
49. Пользователь прокликал полный цикл на мире, пересобранном новым
    компилятором: меню, About, Help -> Contents, Compound Documents, Tut-2
    со схемами. Окно закрыто штатно, лог чист (0 CRITICAL, 4-я чистая
    сессия подряд). Цель "запустить систему в 64 бита" достигнута.
ОТКРЫТО (minor): g_object_unref на выходе (не воспроизводится 4 сессии,
рецепт ловли: G_DEBUG=fatal-criticals + трап-репортёр со стеком);
ObxCompileLog FP249 на dev0-side (known sym-rot, KB/Bootstrap32-symrot.md).

== 2026-08-17 (16): снятие MAP_32BIT с GC-кучи (heap > 4 ГБ) ===
50. Пользователь: "переписать нормально, без костылей" → полный аудит кучи
    (explore-агент) + правки по каталогу B1-B5 (детали KB/HeapAbove4GB.md):
    B1 NewRec/NewArr/Allocated/Used/Root -> LONGINT (EAX обнулял верх RAX);
    B2 Mark: free-блок по инварианту tag = ADR(last) вместо InHeap(усечённый
    тег); B3 [code] Next переписан на RCX/RAX; B4 LONGINT-сортировка кластеров
    в MakeFreeMulticluster + dealloc-check в Sweep; B5 LastBlock(LONGINT).
    LinKernel AllocateClusterMem: MAP_32BIT убран. Счётчики allocated/used/
    ttotal: LONGINT. StdDebug/StdMenus подогнаны под LONGINT.
51. ЛОВУШКА диагностики: err 111 сообщал pos в MakeFreeMulticluster, реальная
    ошибка — LONG(allocated) в ПРЕДЫДУЩЕЙ процедуре MakeFreeMonocluster
    (allocated стал LONGINT, LONG(Int64) неприменим). Позиция ошибки = позиция
    сканера при детекции (конец процедуры), не конструкции. Метод: бисекция —
    если pos не сдвинулся после удаления строки, ошибка раньше неё.
52. ИЗМЕНЕНИЕ FINGERPRINT Kernel.osf (NewRec/NewArr/Allocated/Used/Root):
    обязательна полная пересборка мира test64.sh + build-dev64.sh после
    компиляции Kernel, иначе мир неконсистентен.
53. ВНИМАНИЕ: исходник Kernel теперь 64-бит-only (Mark читает тег 8-байтно).
    32-битный Kernel.ocf из него НЕ пересобирать; dev0 ходит на старом ocf.
54. Пробник ObxProbe35: 80x64МБ = 5 ГБ, touch страниц, полный GC на живой
    куче > 4 ГБ, проверка данных, половинное освобождение, ре-аллокация.
ОТКРЫТО: коммит этапа; git add -f для *.odc.txt (gitignore!): Std/Mod/
Menus.odc.txt, Mod64/DevCompiler.odc.txt, Obx/Mod/Probe35.odc.txt —
untracked, без -f не попадут в коммит. Подтверждение Dev->Compile в GUI
от пользователя (фасад DevCompiler собран, окно истекло по таймауту).
55. Найден и убит 4-й латентный баг кодгена (KB/HeapAbove4GB.md): CPLamd64.
    MakeConst не инициализировал Item.scale — после NIL-коерсии (баг №3)
    GenConst стал эмитить scale как hi32 imm64, и в NIL уходил мусор стека
    (0xF1B390C000000000) → бут падал в Kernel.NewBlock. Фикс:
    x.scale := ASH(val, -31). Проверка: movabs $0 в ocf, бут до конца.
56. probes.sh 22/22. Probe36: ложное ожидание ptr==ADR(b[0]) — dyn array ptr
    указывает на поле last заголовка Block, данные по +headSize=28 (4*nofdim+24);
    так было и в 32-битном Kernel. Ожидание исправлено на a = p + 28.
57. Probe35: 80x64МБ, адреса 0x7AE8... (куча реально >4ГБ), данные пережили
    полный GC, выжившие — второй GC, ре-аллокация и полное освобождение ок.
    Первый фейл — арифметика пробника: used округляется кластерами ~2x
    (64МБ+заголовок -> 128МБ), чек сравнивал с n*chunk. Чек переведён на
    измеренный uAlloc.
58. GUI-регрессия после снятия MAP_32BIT: GTK user_data резался INTEGER'ом
    (LinBackends: 7 ccall-обработчиков + ConnectSignals; Files64: THISARRAY
    по VAL(INTEGER, canonicalize_file_name)). Фикс INTEGER->LONGINT.
    Мир: build-dev64.sh заново (Dev был собран старым кодгеном).
59. Kernel.Insert: снят ложный дебаг-ASSERT(size<64MB) — free[7] catch-all
    легально держит гигантские свободные блоки. HALT 31 на File->Open.
    probes.sh 22/22 после правки.
60. Инфра-ловушки (KB/HeapAbove4GB.md): TaskStop не убивает bbrun64-ребёнка
    (pkill -9 -f Rsrc/bbrun64, но НЕ из задачи, чей cmdline содержит паттерн
    — pkill убьёт саму задачу); go64.sh оставляет мир без Dev если убит
    (.dev-stash-go64); после правки кодгена обязателен build-dev64.sh заново.

== 2026-08-18: аудит INTEGER-указателей ==
61. Полный аудит VAL(INTEGER, ptr)/INTEGER-адресов по всем подсистемам
    (explore-агент) -> KB/IntPtrAudit-64.md. Скоуп: [base] чиним сейчас,
    [ext] (Aos/Crypto/_Http/Comm/Json/Mcp/Fjson/Sdl2/Ogl/W3c) — отдельный
    этап, [ref] Hr — только сверка, не чинить.
62. Корневые typedef'ы [base], от которых веер: Libc.PtrVoid (+long/size_t/
    off_t — LP64 ABI!), Dl.HANDLE, Gtk2GLib.gpointer, Net.PtrVoid — все
    INTEGER. Смена = fingerprint-шок -> полная пересборка мира.
63. Точечные [base]: Files64 MOVE from/to, Services.AdrOf/SafeRecAction,
    Meta.Item.adr, DevDebug/HeapSpy/Decoder386/MsgSpy (Dev-инструменты).
64. TODO64-маркеры в коде: Kernel:776,828 (diag-логи AllocateCluster —
    оставить до конца этапа), Std/Rasters:33,326 (сделано), Compiler64:663.
65. GUI-смоук пройден: меню, File->Open, Dev->Compile изнутри BB64,
    командер ObxTestBig.Go. TestBig v2: alloc accounting точный
    (allocated == expected до байта), GC на 5 ГБ, слабина 1-2 кластера на
    консервативный MarkLocals (KB/HeapAbove4GB.md).

== 2026-08-18 (вечер): порт Comm ==
66. Comm в 64-битном мире: CommStreams/CommTCP/CommV24 + __Lin варианты +
    ObxStreams*. Главная находка — LinNet был НЕ портирован (32-битные
    PtrVoid/time_t/size_t; timeval 8 байт вместо 16 = stack smash в select).
    Порт по образцу LinLibc (LONGINT). Детали: KB/Comm64.md.
67. test64.sh: CompileSubs @Lin (фильтр __вариантов); sync-odc.sh: общий glob
    */Mod (Comm и новые подсистемы больше не теряются); mkworld64.sh: +Comm.
68. Hr удалён из bbcp (сверка завершена; копия остаётся в bbcb2).
69. ObxProbe40.Go: TCP loopback (listener/connect/accept/send/recv/адреса) OK.
    probes 23/23. Cuda пересобрана после wipe.
70. Побочно: починен mojibake в Mod64/DevCompiler.odc (8-битный импорт
    вместо OdcTextU) + детектор двойного кодирования в KB/OdcTextUtf8.md.
71. bbrun64 требовал GLIBC_2.38 (__isoc23_strtoull — редирект хедеров
    glibc>=2.38 при -D_GNU_SOURCE; -std=c99 не спасает). strtoull заменён
    своим parse_ull -> бинарь теперь требует только <=2.34. Ниже 2.34 —
    локальная пересборка (QUICKSTART64.md п.2, KB/GlibcCompat.md).
    Из git выкинуты протухшие отладочные бинарники bbrun64_*.
72. ОТКРЫТАЯ ЗАДАЧА: регрессия фронтенда DevCompiler64 — forward reference
    типа в поле записи (A = POINTER TO RECORD d: B END; B объявлен позже)
    даёт "multiply defined identifier"; стоковый 32-битный DevCompiler тот же
    код принимает (проверено на ObxTestFwd). Всплыло на Paket/Mod/Http.odc
    (Widget.d: Downloading). Искать в DevCPT обработку forward-типов.
73. Ревизия закоммиченных бинарей: выкинуты ранние эксперименты из c9db8909
    (bbrun64_clean/gui/test.c форки, sizes64, check_packed, testmain,
    test64.c/.img, bb64.img). Оставлены осознанно: Dev/Code/*.ocf (seed),
    dev0* (бутстрапы всех платформ), bbrun64/exeLinux64.img (свежие),
    exe*BSD.img (плейсхолдеры под будущие порты).
74. ИСПРАВЛЕНА регрессия фронтенда (п.72): ложный err 1 "multiply defined
    identifier" на полях записей при компиляции 64-битным бинарём. Корень:
    DevCPT.InsertThisField не инициализировала OUT-параметр old — чтение
    мусора со стека (32-бит везло на NIL). Фикс: old := NIL. Детали и уроки:
    KB/CompilerFwdRef64.md. probes.sh: компиляционные пробы Compile:<Модуль>,
    добавлена Compile:ObxTestFwd2. probes 24/24.
75. HALT(77) ложно срабатывал на легитимных кучах >300 кластеров (CheckMaxMemory
    у dia: 301 кластер на 2.4 ГБ 8-МБ блоков). Guard в Kernel.AllocateCluster
    заменён: cycle-detection (черепаха-заяц) + порог 100000 как backstop
    против sliver-шторма. ObxProbe42 (320x8МБ) — регрессия. probes 25/25.
76. probes.sh: BB_NODIALOG=1 (модальные диалоги блокировали скрипт на машине
    dia), автосборка недостающих ocf проб через go64 (Probe40 not found на
    свежем клоне), libtprobe.so для Probe18 теперь собирается из
    tools64/tprobe.c (источника в репо не было — жил только в моём /tmp).
77. Убран DbgTyp("W ") из OutStr (CPT) — отладочный дамп записей в лог при
    каждой компиляции (остаток июльской охоты на PVFP; в 32-битном CPT его
    нет). Ветка OLD/NEW при реальном PVFP mismatch оставлена.
78. КОРНЕВОЙ фикс FFI: DevCPVamd64.GTypeSize alignLimit 4->8 (i386-наследие) —
    untagged-записи получали 4-выравнивание указателей; glibc addrinfo пишет
    ai_addr по @24, CP читал по @20 -> SEGV в getaddrinfo-пути (Paket HTTP).
    Детали+методика: KB/RecordAlign64.md. Побочно: bbrun64 bootInfo писал
    argv по старому смещению @12 -> BootInfo переставлен (modList/argv/argc)
    в инвариантную к правилу раскладку. Probe41 (HTTP GET 26 КБ OK),
    Probe43 (getaddrinfo), Probe44 (SHORT-узкое копирование), Probe45
    (localhost по имени). Seed пересобран (go32 CPVamd64+CPT), мир целиком.
79. П.78 переигран: дефолт alignLimit ОСТАВЛЕН 4 (pack-4 — конвенция OCF v2;
    дефолт 8 сломал все метаданные: Directory.obj после INTEGER невыразим
    инвариантно, атрибуты не комбинируются; симптомы — "command Install not
    found" + вис консоли). C-ABI записи помечаются [align8]: LinNet.addrinfo,
    sockaddr_storage. LinLibc уже был на явных pads (sigaction_t.pad0 и т.п.) —
    они rule-инвариантны. BootInfo переставлен rule-инвариантно (bbrun64.c
    обновлён). Конвенция FFI: KB/RecordAlign64.md.
80. Refs-ридеры 10X: скип 4->8 байт (слот дескриптора amd64). Ломало
    PC->proc в трапах ("Module.???"). Probe47. Kernel.HandleTrap: репорт
    трапа теперь печатается в stdout и в GUI-режиме (раньше — только окно).
    ОТКРЫТО: консольный frame-walker спамит ~IsReadable и падает на HALT-
    трапах (reentrant SEGV вне isReadable-контекста) — GUI не затронут.
81. ОТКРЫТО: PaketHttp TRAP 23 (precondition, Strings) при chunked-загрузке
    списка пакетов. Ответ сервера Transfer-Encoding: chunked. В консоли не
    воспроизводится (Services actions не качаются между командами).
82. PaketHttp TRAP локализован (KB/EntierStackBug.md): кодген теряет 8-байтный
    x87-темп при ENTIER в аргументах вызова (alloc fistpl-слот, потом push
    результата БЕЗ снятия темпа) -> ранее пушнутые параметры сдвинуты на слот
    -> IntToString получила s=NIL -> NIL deref. Бьёт только вызовы, где до
    FPU-аргумента уже есть пушнутые параметры. Фиксить в DevCPCamd64 (эмиттер
    ENTIER-пути). Заодно: трап-репорт теперь печатается в stdout и в GUI,
    имена процедур в стеке чинятся refs-фиксом (п.80).
83. Отчёт для пересказа "зачем меняли выравнивание": KB/WhyAlignment.md.
84. ИСПРАВЛЕН корневой кодген-баг из п.81/82 (KB/EntierStackBug.md). Корень
    НЕ в эмиттере ENTIER, а в DevCPCamd64.LoadLong: ветка узких форм
    (Int32/Set/Int16/...) читала x.mode=Stk через movsxd [rsp] БЕЗ снятия
    слота (в отличие от Load/LoadW/LoadL — там Stk идёт через Pop). Цепочка:
    SHORT(ENTIER(expr)) -> ConvMove кладёт Int32 на Stk (DecStack+fistpl,
    by design) -> конверсия к формалу Int64 (LONGINT-параметр) -> LoadLong
    movsxd + последующий push -> сирота-слот сдвигает ВСЕ ранее пушнутые
    аргументы (IntToString получала s=NIL -> NIL deref в Paket). Фикс:
    `IF x.mode = Stk THEN IncStack(x.form) END` после movsxd/movsx.
    Аудит остальных читателей Stk (Load/LoadR/LoadW/LoadL/Entier/Copy/Param)
    — чисто, все снимают слот. Инвариант: любой путь, читающий x.mode=Stk,
    обязан освободить слот (Pop или IncStack ПОСЛЕ чтения).
    Проверка: Probe49 (P(111, SHORT(ENTIER(r)), 333); при баге b=2 вместо
    333), дизасм PaketHttp: movslq;add $8,%rsp;push — слот снимается.
    probes 27/27, Probe41 (HTTP GET 26КБ с blackbox.oberon.org) OK.
85. Воркфлоу-фиксы по итогам пересборки:
    - sync-odc.sh: Cons/Mod/Compiler64.odc.txt исключён (test64 целенаправленно
      удаляет его .odc — иначе "вечный pending" ронял sync на мёртвой консоли
      и тянул за собой go64 Kernel64 после wipe).
    - go64.sh: прячет 32-битные */Sym bbcp на время компиляции (как test64) —
      иначе PVFP mismatch err 249 (PaketFiles/PaketDocTools над TextModels);
      прячет только Dev/Code, а НЕ весь Dev — Dev/Sym нужен для импортов
      DevCommanders/DevCompiler (иначе err 152); whitelist + Paket*, Cuda*.
    - Paket с нуля в мире: нужен Comm (CommStreams, CommTCP, CommTCP__Lin) —
      PaketHttp импортирует CommStreams; порядок: Comm*, затем PaketHttp,
      PaketModel, PaketFeed, PaketFiles, PaketReader, PaketView,
      PaketController, PaketDocTools, PaketObxHttp.
    - Грабля: Grep по каталогу молча пропускает *.odc.txt (.gitignore) —
      include_ignored=true.
87. Paket Update РАБОТАЕТ (после п.84+86): список скачивается (100%),
    chunked-парсинг живой. Остаточный TRAP 0 при установке Cuda — это
    UPSTREAM-особенность Paket, не 64-битная регрессия: наша Cuda/Docu/
    Quick-Start.odc содержит "Depends: System Lin Std", а таких пакетов
    нет в репозитории -> FindPackageBy=NIL -> AddToList дерефит p.data
    (TRAP 203) либо ASSERT(downloading # NIL) без кода (TRAP 0,
    AssertTrap=0 по умолчанию в CPB). Прогрессия: NIL-guard в
    PaketFiles.SetDependencies (пропуск NIL-зависимостей) и
    PaketController.InstallPackage (deps.package # NIL), ASSERT получил
    код 21. ЗАКРЫТО 2026-08-19: патчи ушли в upstream bbext/Paket,
    коммит 00f477d (Mod/Files.odc, Mod/Controller.odc, комментарии на
    английском); веб-хук раскатывает новую версию на сервер, после чего
    self-update принесёт исправленный Paket. Локальные патчённые копии в
    bbcp64use/Paket/Mod после этого можно удалить. Воркфлоу правки
    Paket .odc (export->edit->import) — KB/PaketUpstreamNilGuards.md.
    ОТКРЫТО: стек-
    ходилка в репорте этого трапа стартовала с битого FP (0x000061DE...)
    -> cycle guard, origin-фрейм не виден; разобрать раскладку фреймов на
    пути Services-action (см. также консольный frame-walker).
86. ИСПРАВЛЕН второй корневой кодген-баг (KB/Const64ShortcutBug.md): Int64-
    константы с нулевыми младшими 32 битами (0x1000000000000000 = hexLimit в
    StringToLInt) обнулялись shortcut'ами эмиттера — XOR r,r в GenMove смотрел
    только offset (младшее слово), игнорируя scale (старшее). TRAP 139 (idiv
    по 0) при парсинге hex-LONGINT -> падала chunked-загрузка Paket (размер
    чанка — hex). Починен весь класс shortcut'ов в CPLamd64: GenMove (+a1-кэш),
    GenComp, GenAnd/Or/Xor, GenMul — везде проверяется полное 64-битное значение
    (offset И scale). Probe52. probes 28/28, Probe41 OK. Инвариант: любая
    оптимизация над Con-итемом проверяет оба слова. Латентное: GenTest imm32
    без fits-проверки для Int64 Con. Диагностика: ObxProbe51 (offset→proc
    через GetRefProc).
88. Crypto64 (2026-08-19): порт bbext/Crypto на amd64 завершён, все тесты
    зелёные (хэши, HMAC, BigNumbers, шифры, DH, RSA, X25519). Репа
    ~/sources/bbext/Crypto64 (коммит ed93f49; GitHub bbext/Crypto64 — создать
    вручную). Ключевое: [code]-процедуры x86-32 молча компилируются, но на
    amd64 это мусор — переписаны на чистый CP; `100000000L` в BigNumbers НЕ
    трогать (L = hex в BB 2.0 = 2^32 = база A2); StdLog в консоли буферизован
    (крах = потеря вывода, бисектить через Console); sig=15 = SIGTERM таймаута
    (зависание); command error в консоли обрывает stdin. Подробности:
    KB/Crypto64Port.md. ClickHouse#56681 ЗАКРЫТО: сервер починен (openssl
    ECDHE-RSA-AES128-GCM-SHA256+x25519 успешен), и наш TLSStream тоже
    подключается (ObxProbe68: GET / -> HTTP/1.0 302 Found). Пуш: 5c078e4 +
    bd0df79 (Docu .odc).
89. Batteries included (2026-08-19): Paket и Crypto включены в bbcp как
    VENDORED копии (bbcp/Paket, bbcp/Crypto). Upstream: bbext/Paket и
    bbext/Crypto64 (там фид для Paket). Решение — копия, не submodule: клон
    собирается без submodule-действий, папка обязана зваться Crypto (имена
    модулей), а репа — Crypto64. test64.sh теперь добирает Comm* + Paket
    (9 модулей) + Crypto (53 модуля, упорядоченный список, AllTests —
    launcher, не компилируется); mkworld64.sh: +Crypto Paket в скелете.
    В bbcp64use Paket/Crypto перелинкованы на bbcp. Smoke: MD5/X25519 ok.
    Sync bbext->bbcp: rsync Mod/Docu (+Paket/Rsrc), коммит. ВНИМАНИЕ:
    Paket self-update в мире пишет через симлинк Mod -> bbcp working tree
    (изменения видны в git diff — ревьюить и коммитить или откатывать).
90. Paket speed garbage (TRAP-окно у репортёра): корень — Math.Exponent
    возвращал 0 (x87 FSTPD -12[FP] не писал локал на amd64) -> весь
    RealToStringForm мусорил. Переписан переносимо (IEEE-754 биты), SMath
    аналогично. Коммит d82b5623. Пробы 70-77. Репортёру: git pull + go64.sh
    Math SMath (или полный test64) — пересборки мира не нужно, интерфейс
    не менялся.
91. Frame walker / трап-репорты (коммит 9a425b19, KB/FrameWalker64.md):
    Below был x86-32 [code] (ломал стек) -> чистый CP; baseStack=0 (SetPlatform
    вызывался до GETREG(SP)) -> InActivationStack всегда FALSE; ASSERT
    (trap.top#-1) = двигатель бесконечной рекурсии трапов -> fallback;
    MarkLocals на сигнальном стеке сканировал сотни ГБ -> SEGV-каскад;
    Step walker'а теперь с проверками (IsReadable + монотонный FP); sigStack
    1M; DevDebug.ShowArray с гардами; ~IsReadable-спам убран. Консольный
    репорт: фрейм упавшей процедуры + чистый exit(1). ОСТАТОК: HALT в
    листовой процедуре даёт только фрейм 0 (нет fp-связки у трамплина);
    GC-во-время-репорта может дать вторичный "137" (не фатально).
92. Frame walker часть 2 (8c2d8e7f): sentry="Initialized" пропускался при
    preset modList (walker уходил в свои фреймы); baseStack теперь снимается
    в LinKernel.Platform.Start (уровень главного цикла, не глубокий Setup);
    DevDebug.Trap пропускается при BB_CONSOLE=1 (падал на консольном
    StdLog.buf и каскадил; заодно ушёл вторичный 137 из CheckCandidates).
    Консоль: полная цепочка module.proc[@pos], один ~TRAP, exit(1).
