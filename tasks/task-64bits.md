# Порт BlackBox на 64 бита (bbcp) — журнал работ

Цель: перенос системы с 32 на 64 бита. Принципы от 32-битной версии, формат нативный
64-битный (НЕ <4 ГБ). Эталон формата: Hr (`bbcb2/Hr/Mod/Ocf.odc.txt`).
**Коммит c30315fc содержит всё ключевое. Читать также KB/ и AGENTS.md в bbcp.**

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
