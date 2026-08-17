# Findings: диагноз и история проблем (64-bit port)

## Корневой диагноз

Прошлая попытка порта failed потому что компилятор (DevCPE+CPLamd64, processor=12)
эмитировал дескрипторы в 32-битной раскладке (4-байтные слоты указателей с
fixup-метаданными), а Kernel64 объявляет 64-битные CP-записи. Загрузчик не мог это
починить → хаки (сканирование кода, goto skip_exports_64_mod, RegisterModule через
отдельный Module вместо dad). Лечится в эмиттере, не в лоадере.

Пользователь: 32-битные принципы сохранить, обратная совместимость не нужна,
<4 ГБ не ограничивать.

## Решённые проблемы

1. **PointerSize=4 const в DevCPM** — раскладка типов 32-битная. Решение:
   CPT.PtrSz()/ProcSz() (не экспортированы, по processor=12 → 8); CPVamd64: 8.
   DevCPM НЕ трогаем (packed в dev0; VAR ломает packed-совместимость).
2. **Packed-модули dev0 затеняют Code** — правки CPE/CPT не действовали. Решение:
   repack dev0Linux без модулей компилятора (tools64/repack-dev0.sh).
3. **Смешение 32/64 osf в одних Sym/** — "not consistently imported". Решение:
   bbcp64use (изолированные Sym/Code). bbcp64use/Dev НЕ создавать.
4. **Коллизии MODULE-имён** — Kernel64×4 файла, LinKernel64 затирал Kernel64.
   Решение: bbcp/Mod64/ + аккуратные симлинки в use64.
5. **ETXTBSY при repack** — pack выполнять из-под blackboxInterpLinux, не dev0.
6. **Bugs codegen**: imm64 4-байтный слот, moffs64, case-таблица abs32 —
   исправлено в CPLamd64 (8-байтные слоты; case: mov r11,imm64 + jmp [r11+idx*8]).
7. **CP-синтаксис**: forward-decl нет (объявлять до использования), ORD(BOOLEAN) —
   нельзя, SHORTCHAR vs CHAR несовместимы, поля с "-" read-only.

## Открытая проблема: fingerprint instability — РЕШЕНА (2026-07-22)

Симптом: "X is not consistently imported" (error 249) при чистой сборке System.
Причина: **32-битный osf fallback**. При компиляции 64-бит в bbcp64use, если osf
подсистемы (Std, Text) не собрана 64-бит, читается 32-битный osf из bbcp;
встроенные в него fingerprint типов (pvfp = size/align/fld.adr/hidden ptrs)
32-битной раскладки конфликтуют с 64-битными копиями в свежих osf.
Controls → StdCFrames (Std); StdDialog → TextModels/TextViews (Text).
Решение: всегда компилировать ПОЛНЫЙ список подсистем:
`tools64/test64.sh "System Std Text Form"` (83 модуля, 0 ошибок).
Диагностика: DbgTyp/OLD/NEW в DevCPT (убрать после стабилизации).
Урок: pvfp рекорда включает typ.size, typ.align, typ.n и адреса полей →
любое смешение 32/64 osf в одном дереве фатально.

## Calling convention amd64 v2 (реализовано, KERNEL OK)
- ParOff=16 ([rbp]=saved rbp, [rbp+8]=ret, params @rbp+16); слоты параметров 8 байт;
  VarPar record = 16 ([tag][adr]); DynArr = [adr8][len4...] (ArrDOffs=8).
- Enter/Exit: imVar slot 8 (BX), isCallback 16 (DI,SI — у всех XProc), guarded 48
  (ОТЛОЖЕНО: exception frame fs:0 32-битный, нужен amd64 redesign TLS).
- ret N = padr - 16. Push Int64 = один qword. heap tag at obj-8.
- RIP-relative disp32: immLen = typ-106 (trailing bytes после disp: lea/mov/call=0,
  imm8=1, imm16=2, imm32=4) — CPLamd64.ripTrail.

## Что подтверждено работать

- Формат OCF v2 эмитируется правильно (Kernel64.ocf: ModDesc 8-байтные слоты,
  sentinel 11223344, name@152 — hex-проверка 2026-07-22).
- Быстрый цикл правок: sync-odc + go32/go64 (DevOnce) — секунды на модуль.

## Сессия 2026-07-23: исправленные баги (компилятор/лоадер)

1. **TRAP при компиляции Kernel64 (CheckForm form=13)**: item (Stk, form=Pointer,
   typ=Real64) — отложенная int→float конверсия адреса (ADR в real-выражении).
   x87 не имеет FIop m64: грузим через FILD. Фикс: GenFLoad/GenFStore: формы
   {Int64, Pointer, ProcTyp} → FILD/FISTP qword; CPCamd64.FloatDOp: LoadR для тех
   же форм; IncStack/DecStack 8 байт для них же.
2. **modList-инжект лоадера**: Variables() кладёт ПОСЛЕДНЮЮ var на offset 0
   (первую — наверх). varBase+0 ≠ modList! Решение: modList объявлена ПОСЛЕДНЕЙ
   в Kernel64 (комментарий в источнике). Иначе инжект затирал heapPos.
3. **Pop Int64 = два 8-байтных pop** (32-битная пара) → дисбаланс стека. Фикс:
   один pop r64 + mov rh,r + shr rh,32 (пара reg/index сохранена).
4. **Локалы 8-байтных типов на 4-границе**: первый pointer-local в rbp-4
   затирал младшие 4 байта saved rbp (сигнатура rbp=0x7fff00000000!). Фикс:
   Variables: NegAlign(adr, Base(typ, 8)).
5. **DevCPVamd64.processor = 10 (!!)** → DevCPT.processor=10 → PtrSz()=4 для
   ИМПОРТИРУЕМЫХ указателей (m: Kernel.Module size=4!). Фикс: processor=12.
   Плюс: built-in типы (niltyp, sysptrtyp, punktyp, anyptrtyp) создаются при
   загрузке DevCPT с processor=0 → size=4. Фикс: Compiler64.Module чинит их
   size:=8 после DevCPT.Init (и присваивает processor ДО Init).
   Плюс: sysflags ([ccall] и др.) требуют sys386 в options — CPT.Import: p=12→10.
   Плюс: self-import старого osf другой платформы при Export — done:=FALSE
   вместо err(151) (иначе 32-битный fallback-osf bbcp/System/Sym душил сборку).
6. **[code]-процедуры (CProc)**: вместо inline-байт эмитился RET (заглушка
   прошлой сессии) → Math.* роняли стек. Фикс: эмитить байты (x87-код
   режимонезависим; единственный FP-относительный — FSTPDe, под вопросом).
7. **Static link offset -4 → -8** (CPCamd64.Call, LevelBase уже был -8).
8. **Машинный стек всегда 8-байтными слотами** (DecStack/IncStack): push/pop
   на x86-64 всегда 8 байт; FISTP dword+pop rax иначе дисбалансил.
9. **DynArr VarPar дескриптор [adr8][len4]**: LenDesc читал len по +4
   (32-бит) → bounds-check против старших 32 бит адреса. Фикс: typ.n*4+8.
   ВАЖНО: базовая загрузка adr ВСЕГДА была 8-байтной — objdump десинхронился
   на trap-энкодинге (8d e7/8d f0), съедая REXW 48. УРОК: не верить objdump
   вокруг HALT-энкодингов, смотреть сырые байты!
10. **inc/dec регистров однобайтные (40-4F)** = REX-префиксы в x86-64!
    `dec eax` (0x48) съедался следующей инструкцией → `n-1` не вычиталось
    (FOR i := 0 TO n-1 работал на одну итерацию дольше → OOB → inxTrap в
    StdInflate). Фикс: GenSub как GenAdd: FF /0,/1 + REXW для 64-битных форм.
11. **crush-хендлер в bbrun64** (SIGSEGV/SIGILL → модуль+offset, stack refs,
    mincore-защита скана) + CheckSentinels (непропатченные слоты 11223344).

## ГЛАВНЫЙ ОТКРЫТЫЙ БАГ: SysV FFI — РЕШЁН, см. KB/FFI-SysV.md

## Сессия 2026-07-24: SysV FFI + LinLibc 64-bit (бут до LinLoader)

12. **SysV FFI реализован** (CPCamd64/CPVamd64): регистры rdi..r9, динамическое
    выравнивание через r12, хвост за 6-ю на стеке, AL=0, Int64-параметр = 1 слот,
    Int64-результат из rax в пару. Детали KB/FFI-SysV.md.
13. **LinLibc 64-битные типы** (Lin/Mod/Libc.odc): PtrVoid/long/size_t/ssize_t/
    off_t/time_t/clock_t/ino_t/nlink_t/blkcnt_t/blksize_t/rlim_t = LONGINT
    (int/pid_t/uid_t/gid_t/mode_t/clockid_t = INTEGER). Раскладки x86-64:
    stack_t {ss_sp@0, ss_flags@8, ss_size@16} = 24; stat_t/stat64_t = 144
    (dev,ino,nlink,mode,uid,gid,pad0,rdev,size,blksize,blocks,atim,mtim,ctim,
    reserved[3]); timespec {sec@0, nsec@8}; tm_gmtoff -> long; sigjmp_buf =
    25 LONGINT (200 байт); ucontext/gregs: __NGREG=23, greg_t=LONGINT,
    REG_EBP/ESP/EIP = 10/15/16 (x86-64 RBP/RSP/RIP, имена сохранены);
    _libc_fpstate = 512 байт opaque. CP auto-alignment полей совпал с C.
14. **__xstat/__xstat64 на x86-64 glibc НЕ экспортируются** -> stat/stat64
    (LinFiles/LinFiles64: `Libc.stat(name, buf)`, `Libc.stat64(...)`).
15. **SYSTEM.GET/PUT/BIT/MOVE с Int64-адресом**: DevCPB требовал {Int32, Pointer}
    -> err 111. Добавлен Int64 при DevCPT.processor = 12 (2 места).
16. **S.ADR/S.TYP остаются int32typ НАРОЧНО**: попытка int64typ ломает codegen
    (Int64 Ndop -> err 260, см. п.18; err 113 в legacy-модулях). Вместо этого
    в CPVamd64 adr/typfn константный item получил form Pointer (64-битная
    загрузка адреса, полный указатель в регистре). Присваивание в INTEGER
    усекает (legacy-поведение, лечится SHORT() точечно).
17. **Pointer -> Int64 конверсия (VAL)**: шла через LoadLong (пара) и
    дублировала lo в hi (tag=0xda18d498da18d498). Новый CPCamd64.PtrToLong:
    `mov rh, r (REXW); shr rh, 32` (как Pop Int64), вызывается из ConvMove
    (sysval и общий случай) для Pointer/ProcTyp -> Int64.
18. **Int64-АРИФМЕТИКИ В BACKEND НЕТ (бомба)**: Ndop form=Int64 -> err(260) +
    fallback = только левый операнд (молча неверный код); в Mem-контексте
    (S.GET/PUT) -> HALT компилятора. LinKernel `S.GET(baseStack+16, argc)`
    заменён заглушкой argc:=0 (до задачи 8, bootInfo).
19. **CompileSubs СТОП на первом модуле с ошибками** (DevCompiler64.CompileSubs
    RETURN при error) -> LinKernel64 (6 известных ошибок, стадия C) обрезал
    все последующие Lin-модули. Симлинк bbcp64use/Lin/Mod/Kernel64.odc
    переименован в .disabled до стадии C.
20. **baseStack/stack 64-бит**: System Kernel baseStack: LONGINT +
    Platform.Setup(baseStack: LONGINT) (интерфейс!), LinKernel соответственно.
    Иначе SP (0x7fff...) усекался до 0xffff.... `hi := SHORT(baseStack)` в
    LinKernel.InActivationStack (legacy, до задачи 5).
21. **platform.tag в LinKernel**: `platform: RECORD tag: LONGINT; p: Platform END`
    + `platform.tag := S.VAL(LONGINT, S.TYP(Platform))` — Kernel.SetPlatform
    зовёт методы platform.p, тег читается из [obj-8] как 8 байт.
22. Потребители Libc починены: LinKernel/LinFiles/LinFiles64 (OpenFile/
    NewFileRef VAR ref: Libc.PtrFILE; Register: ref вместо res-as-FILE*;
    Libc_errno addr: LONGINT; num/f.len/info.length <- SHORT), LinDates
    (SHORT(-tm_gmtoff DIV 60)), System Kernel (~20 SHORT(S.ADR/S.TYP)),
    Services (SHORT(SYSTEM.ADR/TYP)).
23. **InstallStackAlloc 32-битный**: `sub esp, eax` усекал rsp до 32 бит при
    фреймах > stackAllocLimit (2048) -> краш в LinLoader.Load (4x256 CHAR).
    Переписан сырыми байтами: 64-битные sub rsp, слоты 8, probe по 4088,
    копия ret/saved-rax из [rsp+rcx-8], shr ecx,2 (caller ждёт 32-бит words).
    УРОК: весь сгенерированный хелпер-код (не только обычный codegen) надо
    ревизовать на 32-битные операнды.
24. **System Kernel дескрипторы НЕ совпадают с OCF v2**: System/Mod/Kernel.odc
    Module/Type/Directory — 32-битная раскладка (term@32, code/data/refs
    INTEGER@60..., name@112...), а bbrun64 строит дескрипторы по OCF v2
    (term@48, code@80..., name@152, все указатели 8 байт). ThisLoadedMod
    читает "указатель" = ASCII имени модуля -> краш в scasb при LinIntLoader.
    Лечится только стадией C (Kernel64_full с правильной раскладкой,
    KB/OcfFormat64.md), НЕ точечными правками System Kernel.
25. CompileSubs СТОП на первом ошибочном модуле (RETURN при error) — поэтому
    LinKernel64 (6 ошибок) выведен из bbcp64use/Lin/Mod (Kernel64.odc.disabled),
    а заглушка bbcp/Lin/Mod/Kernel64.odc (старая, 841 байт) удалена из дерева
    use64 fallback'ом... внимание: sync-odc создаёт её заново из tracked
    Lin/Mod/Kernel64.odc.txt — следить.
26. **Структура ядра в use64**: bbcp64use/System/Mod/Kernel64.odc — симлинк на
    Mod64/Kernel64.odc (bump-ядро, 94 строки). bbrun64 мапит "$$"-импорты на
    "Kernel64" (строка kernel в bbrun64.c). Стадия C = заменить bump-ядро на
    Mod64/Kernel64_full.odc (2381 строка, MODULE Kernel64) — НО это порт
    WINDOWS-ядра: `IMPORT S := SYSTEM, COM` — надо выпиливать COM (Win COM
    interop) или заменять на Lin-эквивалент. LinKernel64 (Mod64) ссылается на
    Kernel64.Cluster/InitHeap — появятся в full-ядре.
27. **Boot-архитектура**: bbrun64 грузит ВСЕ .ocf из */Code подсистем,
    разрезолвляет импорты multi-pass, инжектит modlist в Kernel64.modList
    (modList = последняя var, offset 0), зовёт тела модулей. System Kernel
    имеет СВОЙ modList и свою раскладку Module — отсюда краш ThisLoadedMod
    (п.24). Рантайм-аллокатор уже Kernel64 (NewRec/NewArr через $$).
28. **Int64-арифметика = x87 FPU** (уже было в backend, Finding #1): Ndop
    plus/minus/times/div и сравнения для Int64 идут через FILD/FADD/FCOMP
    (точно для 64-бит int, мантисса x87 = 64 бита). err(260) в CPVamd64
    просто запирал вход. Ограничения: FMUL/FDDIV теряют точность за 2^63;
    x87 DIV округляет к нулю, а CP DIV к -inf (расхождение на отрицательных).
    Запасной путь: CPCamd64.LongAdd/LongSub/LongNeg/LongCmp на паре lo/hi
    (add/adc, sub/sbb) — срабатывает, если item с form=Int64 дойдёт до IntDOp
    (на практике операнды конвертируются в FPU раньше).
29. **Hr — эталонный amd64 backend**: /home/hodza/sources/bbcb2-*/Hr/Mod/
    (HrC=codegen, HrL=эмиттер). Полный нативный 64-битный codegen: всё в
    одиночных r64 (fInt64), LGenAdd/GenAddC/LGenSub/LGenMul/idiv/cqo.
    ADDRESS = fInt64. Когда нужен эталон арифметики/конвенций — смотреть туда,
    а не в 486-бекенд.

## Уроки процесса
- Ассерт-инварианты окупаются: BADPTR (Pointer/ProcTyp size=8) поймал
  processor=10 и builtin-types=4 НА КОМПИЛЯЦИИ, а не в рантайме.
- objdump ДЕСИНХРОНИЗИРУЕТСЯ на trap-энкодингах (8d f0 XX / 8d e7) —
  доверять только сырым байтам (x/Nxb).
- 32-битный эталон: компилировать тот же микро-модуль 32-битным бэкендом
  (go32) и diff дизасма — мгновенно показывает потерянные байты (dec!).
- Log-вывод dev0 теряется при TRAP — диагностику в компиляторе делать
  через HALT(код), trap number виден в репорте; HALT требует КОНСТАНТУ.
- Микро-репродукции (модуль SystemTestT1 через OdcText.Import + CompileThis)
  — самый быстрый способ изолировать codegen-баг (секунды на итерацию).

## Сессия 2026-07-24 (ночь): System Kernel порт + бут до LinPackedFiles
30. **Компилятор выравнивает поля записей max на 4** (CPVamd64.TypeSize),
    SHORTINT=2 байта. OCF v2 формат (CPE.OutModDesc) требует name@152 в
    Module — в Kernel.odc.txt добавлены явные pad-поля (pad0/pad1 в Module,
    tpad0/tpad1 в Type, opad в ObjDesc). Инвариант: bbrun64.c _Static_assert.
31. **Trap-инструкции = `8d f0 XX` / `8d e7` (2 байта)** — objdump их не знает
    и СЪЕДАЕТ следующий байт (напр. REX 48 нормальной инструкции!). Дизасму
    верить только через сырые байты + ocf.py refs для границ процедур.
32. **Open-array ABI**: слот = adr(8)+len(8). CPCamd64.Load грузил базу как
    Int32 → мусор в старших 4 байтах → краш в циклах копирования строк.
    Фикс: `IF x.typ.comp = DynArr THEN f := Pointer END`.
33. **Value Comp-параметр**: слот был (s+3)DIV4*4 — съезжали последующие
    параметры при s не кратном 8 (Files.Type=ARRAY 16 OF CHAR в Append).
    Фикс: 8-выравнивание в обоих AdjustStack + empty-string путь (s-8+push8).
34. **REX для r11**: `mov r11,imm64; op [mem],r11` — REX должен быть W+R(4C),
    НЕ W+B (49) и НЕ W+R+B вслепую (4D ломает базу rax→r8!). Паттерн:
    `IF dst.reg >= 8 THEN 4DH ELSE 4CH END`.
35. **bbrun64**: kernel="Kernel64" (bump), инжект modList нужен и в bump
    (varBase+0), и в System Kernel (через ThisObject "modList" по export dir).
    Тела модулей: сначала инфра в порядке dev0-link (Utf, LinKernel, Files,
    LinEnv, LinFiles, LinPackedFiles, StdLoader, LinLoader, LinIntLoader).
    LinLoader/LinIntLoader: IMPORT LinFiles (тело ставит Files.dir).
36. **ConsCompiler не собирается** (нужен весь Dev в BB64) — отключён
    (Cons/Mod/Compiler.odc.disabled). ConsInterp требует DevCommanders —
    test64.sh собирает его между Lin и Cons.
37. Диагностика компилятора: ASSERT→DevCPM.err(220) в CPCamd64.Mem даёт
    позицию в исходнике; LogWStr/LogWNum живут в dev0-логе (stdout);
    строки в ocf — UTF-16 (strings не видит); "corrupted code file for
    DevCPCamd64" = 64-битный ocf попал в bbcp64use/Dev (убить Dev/Code|Sym).
38. Открыто: Kernel.log (ErrLog interface) — диспетч через [itable-8]:
    при ASSERT в LinPackedFiles краш в log.String. VarBlk в OCF v2 НЕТ —
    компиляторная инициализация глобалов (interface-таблицы) не применяется.
    Надо: явная инициализация или разобрать interface-init (TDinit).
39. Открыто: StdLoader.Fixup 32-битный (SHORT-заглушки) — ленивая загрузка
    модулей внутри BB64 сломана. Эталон: bbrun64.c Fixup (6 групп, 8-байт).

## Сессия 2026-07-24 (ночь, продолжение): StdLoader, MAP_32BIT, LinDl, LinGui
40. **StdLoader.Fixup портирован** по bbrun64.c: 8-байтные слоты (4 метаданных
    + 4 sentinel 11223344H), типы absolute=100/relative=101/copy=102/
    table=103/tableend=104/ripBased=106..114 (immLen=typ-106). ModSpec и
    Kernel.AllocModMem — INTEGER-капы (<4 ГБ). KB/StdLoader64.md.
41. **MAP_32BIT обязателен** для AllocateModMem/AllocateClusterMem: адреса
    уходят в INTEGER-интерфейсы и GC Mark читает теги 32-битно. Без него
    mmap>4ГБ + SHORT = разрушение. Libc.MAP_32BIT* = {6} (0x40).
42. **LinDl/LinGui 64-бит**: PtrVoid/HANDLE=LONGINT, [ccall16]→[ccall] (SysV);
    GTK-хэндлы и dlsym-адреса LONGINT. [ccall16] — старая конвенция с багами
    (mov esp/pop esp усечение) — мигрировать везде на [ccall].
43. **Dev-пайплайн в BB64**: DevCP* + DevCompiler64 + ConsCompiler64 собираются
    build-dev64.sh (rm bbcp64use/Dev + пересборка; dev0 не видит 64-битных
    DevCP* иначе "corrupted code file"). test64.sh зовёт его в конце.
    ConsCompiler64 = ConsCompiler поверх DevCompiler64.
44. GTK-аудит: KB/Gtk64-Audit.md — алиасы, GdkEvent×8, 31 double-функция,
    varargs (только строки, AL=0 хватает), колбэки (ждут SysV Enter),
    минимальный путь до окна A→B→C→D.

## Сессия 2026-08-08: бут до MAIN OK, GC, первая компиляция внутри BB64

45. **S.ADR = Int64 (processor=12)** — п.16 ПЕРЕПИСАН: ADR возвращает int64typ
    (стек >4ГБ!), TYP остаётся Int32 (дескрипторы в арене <4ГБ). Fallout:
    `x: INTEGER; x := S.ADR(...)` → err 113 по всему legacy-коду. Лечение:
    LONGINT-поля/локали или SHORT() с комментом TODO64 (куча <4ГБ → SHORT
    безопасен для heap-адресов, НЕ для стека).
46. **VAL(LONGINT, int32-значение) молча ломалось**: ConvMove sysval-ветка
    (CPCamd64 ~949) делала PtrToLong только для Pointer/ProcTyp; Int32/Set
    проваливались дальше и hi-dword пары брался из stale item.index →
    `platform.tag := S.VAL(LONGINT, S.TYP(Platform))` писал lo в оба dword
    (0x428a4498428a4498) → краш в SetPlatform на методе. Фикс: Int32/Set →
    LoadLong (sign-extend в пару).
47. **Kernel.Module.ptrs = ARRAY OF INTEGER** (4-байтные offsets, CPE.FindPtrs
    = Out4). Было LONGINT → MarkGlobals читал пары записей как одно число
    (0x22c_42da5484) → краш в Mark. Любая смена публичной раскладки Kernel =
    новый fingerprint → полная пересборка (test64).
48. **MarkGlobals: глобалы могут указывать в АРЕНУ МОДУЛЕЙ** (modList и др.;
    bbrun64 грузит модули в mmap-арену БЕЗ heap-тегов, в отличие от 32-бит
    AllocateModMem). Mark по такому указателю = чтение мусора как тега.
    Фикс: Kernel.InHeap(p) — проверка по кластерам (root) перед Mark.
49. **CompileSubs продолжает после ошибок** (DevCompiler64.CompileSubs:
    счётчик failed/total + "== CompileSubs FAILED: X" вместо RETURN). Иначе
    один сломанный модуль (StdDebug) обрезал сборку Lin → бут без LinFiles.
50. **BB_USE_DIR = cwd у run-BlackBoxInterp/run-dev0**: запуск из bbcp или
    bbcp64use подхватывает чужие Sym → "illegal foot print"/"corrupted code
    file" и МОЛЧА не пишет .odc. sync-odc.sh и build-dev64.sh теперь сами
    делают cd в хост-каталог; вывод ошибок не глушим.
51. **32-бит мир bbcp тоже надо пересобирать согласованно**: разработчик
    пересобрал System/Sym и TextModels.osf, но не остальной Text/Std →
    DevCompiler64 не компилировался ("inconsistent import"). Цепочка:
    TextModels→Rulers→Mappers→Setters→Views→Controllers→StdLog, затем
    `echo 'DevCompiler.CompileThis DevCompiler64' | ./run-dev0`.
52. **ConsCompiler64 в списке build-dev64.sh** — без него REPL падает с
    "command error: code file for ConsCompiler64 not found" (GUI-диалог даже
    в console-режиме: LinGui.Init грузит GTK всегда).
53. **errpos.sh**: ODC line-end = один 0DX → CRLF в .txt нормализуем
    (`\r\n`→1 char); cp1251 fallback для комментариев разработчика.
54. **Тест-модули (TestT*, TA6x, SystemTestT1, TestK) НЕ коммитить в
    System/Mod** — CompileSubs их сканирует, bbrun64 ГРУЗИТ при буте.
    bbcp64use/*/Mod — пофайловые симлинки; build-dev64.sh копирует .txt →
    там появляются реальные файлы-копии, чистить при удалении в bbcp.
55. **Std/Mod/StdCFrames.odc = MODULE StdStdCFrames — НЕ дубликат**: его
    импортирует LinInit. Удалять нельзя.
56. **StdRasters: Q0/Q1-блиттеры переписаны** с ADDRESS-арифметики
    (GET/PUT по вычисленному Int64-адресу = err 220, backend так не умеет)
    на индексацию RasterData (IN src/VAR dst: RasterData) — портативно 32/64.
    Идиома для буферов: ADR(x[i]) + SYSTEM.VAL(PtrType, al) (LinFiles).
57. **GUI-бут доходит до event loop**: LinInit отрабатывает, Loop.Start
    крутится, Dialog.RequestExit(exitWithoutWindows) → чистый exit(0), т.к.
    ни одно окно не открылось. Открытие первого окна — следующий шаг.
58. РЕШЕНО: краш WriteSChar — GC Mark СПУСКАЛСЯ в bump-heap Kernel64
    (арена модулей): объекты арены получали mark-бит (INC(this.tag)), а
    Sweep ходит только по кластерам root → mark оставался навсегда →
    dispatch по тегу desc|1 → SIGSEGV. Фикс: InHeap-проверка и на входе
    Mark, и в точке спуска (son) — вход НЕ покрывает спуск (INC в outer
    LOOP). Поймано watchpoint'ом: чистая запись тега в Kernel64.NewRec,
    затем +1 от Mark. Ограничение: ссылки bump→cluster не маркируются
    (bump-объекты бессмертны; риск задокументирован).
59. bbrun64: BB_ARENA_BASE=0x... — MAP_FIXED_NOREPLACE, детерминированная
    арена под gdb (ASLR/MAP_32BIT иначе плавает даже под gdb). BB_TRAP=1 —
    int3 после загрузки модулей. Поздние bp через
    `break fprintf if strcmp((char*)$rdi, "init %s (main loader, %s mode)...\n")==0`.
60. Открытый баг (следующий): краш DevMarkers.SizePref+0xa9 при REPL-
    команде с параметрами (Call1 строит TextModel): сохранённый результат
    Fonts.dir.Default() читается как 0x0000000f_00000000 (hi dword = 0xF).
    Default() доказанно возвращает валидный rax — слот [rbp-0x18] портится
    или читается не тот; heap-layout недетерминирован (GTK-треды) —
    watchpoint-форензика затруднена. Подозрения: (a) pvfp-рассинхрон Font
    (в одной сборке два отпечатка Fonts — см. "PVFP mismatch" в логе
    test64; раскладки совпадают 144=144, но fp разные), (b) 4-vs-8
    выравнивание pointer-полей после 4-байтных.
61. REPL РАБОТАЕТ для команд без параметров и без StdLog-вывода:
    'Startup.Setup' и 'Kernel.Collect' выполняются (Console.WriteStr идёт
    в stdout). Падает только путь TextModels/Views (Call1 param text,
    ShowStdLog).
62. **Два аллокатора = GC слепнет (РЕШЕНО, 2026-08-08)**. bbrun64 резолвил
    `newRecAdr/newArrAdr` один раз по "Kernel64" (`strcpy(kernel,"Kernel64")`)
    и прошивал во ВСЕ модули → весь NEW шёл в Kernel64 bump-heap (16 МБ
    статика в арене), а generic NEW (Kernel.NewObj → Stores.CopyOf и т.п.) —
    в CP Kernel кластеры. InHeap-охрана Mark (п.58) НЕ спускалась из
    bump-объектов в кластерные дети → GC забирал живой Attributes, слот
    переиспользовался (StdModel) → цепочка piece.attr→Reader.attr→Writer.attr
    →ViewRef.attr→краш DevMarkers.SizePref (a.font=0xf00000000, dispatch по
    мусору). Форензика: watchpoint-цепочка от краша вверх (c.ref.attr ←
    WriteView r.attr:=wr.attr ← w.SetAttr(r.attr) ← rd.attr:=u.attr ←
    piece.attr ← CopyOf), на каждом шаге адрес объекта брался из краша
    предыдущего прогона (BB_ARENA_BASE детерминизм). Лечение: bbrun64.c
    ReadModule перерешивает NewRec/NewArr для КАЖДОГО модуля: `ThisModule(
    "Kernel") ?: ThisModule("Kernel64")` — всё, загруженное после Kernel
    (включая все динамические), идёт в кластерную кучу. Остаточный риск:
    bump-объекты модулей #1..#11 (до Kernel) бессмертны, их дети в кластерах
    не маркируются (см. п.58).
63. **Kernel GC: рассинхрон шага блоков (РЕШЕНО)**. NewBlock: tsize=
    (size+23)DIV16*16, min 24; [code] Next: (size+19)DIV16*16 без минимума;
    Insert/free-size = total-4. Три формулы взаимно несовместимы: min 24
    ломает 16-выравнивание (блоки ≡8 mod 16, иначе strictStackSweep отвергает
    candidates), Next занижал шаг → Sweep/CheckCandidates обваливали цепочку
    блоков (краш Next: deref tag=0). Согласовано: Next=(size+23)DIV16*16 с
    clamp 32 (в [code]-процедуре, байты подправлены: +0x17, CMP/JAE/MOV 0x20);
    NewBlock min 32; free-size-семантика total-8 (Insert, OldBlock,
    GetOldFreeBlock, LastBlock, MakeFreeMono/Multicluster, InitHeap, NewBlock
    остаток + sliver-absorb `IF a>=32 THEN Insert ELSIF a>0 THEN INC(tsize,a)`).
    УРОК: **CP-версии процедур в Kernel — КОММЕНТАРИИ**, живые — [code] с
    байтами! Правка CP-Next ушла в комментарий; [code]-аудит Kernel: FINIT,
    ALLOC/ADDREF/RELEASE/CALLREL, PUSH/CALL/RETI/RETR, Next — остальные ок.
64. **ExecFinalizer: двойное разыменование (РЕШЕНО)**. `ar := S.VAL(AdrRef,
    tag-8); S.GET(ar.a, fin)` читало M[M[tag-8]] (байты метода) вместо
    M[tag-8] (адрес FINALIZE) → call по байтам пролога. Правильно:
    `S.GET(S.VAL(LONGINT, ar), fin)`. AdrRef-идиома = ОДНО разыменование
    (ar.a); остальные места (MarkLocals, trap-frames) корректны.
65. refs/ocf.py: резолвить процедуры ТОЛЬКО по ocf из bbcp64use (свежим);
    в bbcp они протухшие → имена процедур смещаются. Динамические модули
    (DevCPT/компиляторная цепочка, ConsCompiler64) грузятся CP-лоадером
    (Std/Mod/Loader Fixup — копия bbrun64-логики) по СЛУЧАЙНЫМ адресам
    (LinKernel.AllocateModMem = mmap(0,MAP_32BIT)) → под gdb с
    BB_ARENA_BASE их адреса другие, чем в ASLR-прогонах.
66. **Открытый баг: ASLR-зависимый краш (текущий)**. После п.62-64 команда
    компиляции бежит (прогресс 'c'), Kernel.Collect проходит, но ВНЕ gdb
    (ASLR on) периодически: SIGSEGV → LinKernel.HandleTrap → рекурсия на том
    же PC (в динамическом модуле) → exit(2) / core. Под gdb/setarch -R —
    чисто. Данные core (15:14): rip=fwait в модуле ~0x436c13da; sigsegv
    пришёл на fwait → отложенный fault от `fistpl (%rsp)`; si_addr=rsp=
    0x60072f7b8944; rsp/rbp/rsi/rbx = 0x6007_2f7b_xxxx (ВЫСОКИЙ стек, в gdb-
    прогонах BB бежит на main-стеке 0x7fffffff..!). Странность: регион
    читается из core (замаплен, данные похожи на стек: ret-адреса, rbp-цепь).
    GTK-нити (4 LWP) припаркованы в poll/cond — не гонка. Гипотезы:
    (a) BB-стек (sigStack? loop stack) аллоцируется mmap БЕЗ MAP_32BIT →
    улетает высоко с ASLR, а трап-машинерия (SHORT(sp/fp/pc) в HandleTrap,
    MarkLocals) ломается; (b) jmp_buf/setjmp-раскладка при siglongjmp после
    первого трапа портит rsp. Компилятор делает 64-битные сравнения через
    x87 (fildll/fcompp/fnstsw/sahf, fistpl+fwait) — fault всплывает на fwait
    далеко от источника.
67. **КОРЕНЬ ВСЕХ КРАШЕЙ: двойной push FPU-значения-параметра (РЕШЕНО)**.
    Int64-арифметика в этом компиляторе идёт через x87 ПО ДИЗАЙНУ: узел
    `LONGINT+int` типизируется intrealtyp (form=Real64!) → Ndop видит
    f IN realSet → FloatDOp (fildll/fiaddl). Значение-параметр, вычисленное
    на FPU, материализуется Push* как DecStack(-8)+FISTP [rsp] (ap.mode=Stk —
    УЖЕ на машстеке), а CPCamd64.Param (ветки `ap.typ.form = Pointer` и
    `ap.form = Int64` в SysV-блоке) делал ещё `GenPush(ap)` = `push [rsp]` —
    ДУБЛИКАТ: скретч-слот оставался ВНУТРИ области параметров, следующий
    параметр читал мусор (size=blk!) + утечка 8 байт на вызов.
    Пример: Insert(b+tsize, a) получал size=b+tsize → гигантский free-блок
    накрывал живые FList-узлы → Erase занулял узел в цепочке finalizers →
    ThisFinObj SEGV. Фикс: `IF ap.mode # Stk THEN GenPush(ap) END` в обеих
    ветках. ДИАГНОСТИКА: ловушки-инварианты Kernel ASSERT 30/31/32 (Insert)
    поймали момент коррупции; DBG-TRACE assert'ы 91..118 в компиляторе
    показали путь Ndop→FloatDOp (потом удалены). УРОКИ: (а) refs в ocf.py —
    КОНЦЫ процедур, брейк ставить на конец предыдущей; (б) fprintf(rsi=fmt,
    rdx=arg1), strcmp в условиях gdb флаки — использовать dword-сравнения;
    (в) комментарий в CP не должен содержать "*)" (напр. "Push*)" = ошибка
    компиляции "statement starts with incorrect symbol"; (г) программа на
    SIGILL 2-байтным опкодом = ASSERT/рантайм-ловушка бэкенда (GenAssert).
68. **Проверка п.67**: полная пересборка System Std Text Form Lin Cons
    (0 failed of 125) → `ConsCompiler64.Compile("", "Hello.cp")` =
    "0ErrorsDetected", краша нет. Kernel.Collect — чисто. Осталось: вызов
    команды `ObxHello.Do` через StdInterpreter → wild pc (~TRAP sig=18) →
    SIGILL в Kernel.HandleTrap+0xef (финальный HALT трап-обработчика) →
    рекурсия → abort. Подозрение: ещё один случай рассинхрона параметров
    (вызов через Meta/CallHook, var-параметры или proc-переменные).
69. SIGFPE-каскад (п.66): FPU control word компилятора = 0x33E — IM-бит=0
    (invalid operation НЕ замаскирован) → fistp вне диапазона/NaN даёт
    SIGFPE(FPE_FLTINV, code=7); HandleTrap (LinKernel+0x1589: fadds/fistpl/
    fwait) ловит её же рекурсивно (~0xC80 на кадр) до переполнения стека.
    Не путать с корнем п.67: каскад — следствие любого трапа, дошедшего до
    HandleTrap с грязным FPU-словом.
70. **Трап-глобалы и адреса в Kernel → LONGINT (РЕШЕНО)**. Kernel глобалы
    pc/sp/fp/val были INTEGER; LinKernel.HandleTrap делал
    `sp := SHORT(gregs[REG_RSP])` — стек 0x7FFF... не влезает в INTEGER →
    fistpl out-of-range → SIGFPE(FPE_FLTINV, IM в cw=0x33E не замаскирован) →
    рекурсия HandleTrap до переполнения стека (каскад ~TRAP sig=8).
    Изменено: Kernel err-: INTEGER, pc-/sp-/fp-/val-: LONGINT;
    Platform.GetTrapInfo val: LONGINT (интерфейс + реализация LinKernel);
    TrapTitle val: LONGINT; SigToErr pc/val: LONGINT (S.GET через temp);
    убраны все SHORT() вокруг gregs/sigStack/argv.
    КАСКАДНО: StdDebug переписан на LONGINT-адреса (WriteHex/OutAdr/
    ShowVar/ShowRecord/ShowArray/ShowProcVar/ShowPointer/ShowStack/
    GetTrapMsg/WriteGuid).
71. **Подводные камни интерфейсных правок**: (а) позиции ошибок компилятора
    считаются по .odc (каждый <odc-view> = 1 позиция!), по .odc.txt мапить
    через замену view-тегов на 1 char; (б) Kernel.ADDRESS был НЕ
    экспортирован — в osf уходил отдельным типом → err 113 "incompatible
    assignment" при вызовах из других модулей (лечится экспортом);
    (в) Kernel.IsReadable-обёртка была (from, to: INTEGER) — переведена на
    ADDRESS; (г) bisect через ASSERT(FALSE, n) в компиляторе — быстрый способ
    определить путь диспетчеризации (trap n показывает номер).
72. **Ограничение кодгена: SYSTEM.GET/PUT не принимает LONGINT-выражение
    адреса** (err 220): `S.GET(a + 1, x)` с a: LONGINT падает в CPCamd64.Mem
    (x.mode не Con/Reg — Int64-plus идёт intrealtyp→FPU→Stk). Обход:
    temp-переменная `t := a + 1; S.GET(t, x)` (применено в StdDebug).
    Правильный фикс — материализация FPU-адреса в Pointer-регистр в
    CPVamd64.Mem/CPCamd64.Mem — ОТЛОЖЕНО (связано с п.67).
73. После п.70-72: пересборка 0 failed of 125; Compile=0ErrorsDetected;
    трап-репорт печатается чисто (без FPE-каскада). Осталось: ObxHello.Do →
    ~TRAP sig=15/18 в нити GTK event loop (pc в нативной lib 0x76AC...) →
    рекурсивный SIGILL на финальном HALT HandleTrap — это GUI-фронт.
74. **GUI: первое окно не открывается (2026-08-09, в работе).** Симптом:
    gtk_window_new(TOPLEVEL) вызывается РОВНО один раз (gdb, /tmp/gui3.gdb),
    но gtk_widget_show_all / gtk_widget_realize НЕ вызываются →
    "body loop finished" (exitWithoutWindows), процесс выходит молча.
    Архитектура (Lin/Mod/Backends.odc, читать через `odcey text -skip-embedded-view`):
    BackendDirectory.NewBackend (~стр.521) делает gtk_window_new +
    drawing area + fixed + ConnectSignals; Backend.Open (~стр.504) делает
    gtk_widget_show_all(wb.wnd). Значит обрыв между NewBackend и Open
    (кандидат: ConnectSignals — не читан) либо Open вообще не вызывается.
    Config-цепочка бутa: Lin/Mod/Init.odc Init (~стр.78-108):
    SearchVar("appConfigProcedure") ничего не находит (переменной нет в
    дереве) → configCmd := "StdConfig.Setup" → Dialog.Call("StdConfig.Setup")
    → StdConfig.Setup вызывает StdWindows.Init, StdDocuments.Install,
    StdMenus.Install, StdTiles.On и SetupWorkspace (Std/Mod/Config.odc,
    SetupWorkspace ~стр.76 — grids/dividers/windows; читать через odcey).
    Startup.Setup — no-op stub, это норма. НЕ выяснено: доходит ли до
    StdConfig.Setup/SetupWorkspace; Dialog.Call может вернуть res_#0 и
    ошибка уходит в Dialog.ShowMsg (а окна ещё нет — молчание!). План:
    (1) [LR]-принты configCmd/res_ в LinInit после каждого Dialog.Call
    (log.String из LinKernel, как в LinRegistry); (2) если Dialog.Call
    не проходит — копать Dialog.Call/StdInterpreter (пересекается с
    крашем ObxHello.Do); (3) если проходит — gdb-брейки по cad-адресам
    из "+"-строк загрузчика (StdWindows cad=0x428cd000, refs из
    bbcp64use/Std/Code/{Config,Windows}.ocf, Lin/Code/Backends.ocf) —
    найти обрыв до show_all. gdb: strcmp в условиях флаки — dword-
    сравнения *(unsigned int*)$rsi == 0x... ; refs в ocf.py — КОНЦЫ
    процедур, брейк на конец предыдущей.
75. **GC: sliver-absorb a=16 ломал цепочку блоков (2026-08-09, РЕШЕНО).**
    Симптом: компиляция модуля с `IMPORT Libc := LinLibc` (большой sym) →
    первый же GC → SIGSEGV addr=0 в CheckCandidates (инлайн [code] Next:
    `MOV ECX,[ECX]` по tag=0). gdb-реконструкция хода от кластера
    (base+24, stride в точности по 32-битной семантике asm: AND CL,0FCH =
    & 0xFFFFFFFC, ADD/SUB 32-бит) — 1914 блоков, точное попадание в crash:
    последний блок (ARRAY OF SHORTCHAR — строка имён из Libc.osf)
    заканчивался на 0x6003ffe8, дальше 16 байт нулей до sweep-end.
    МЕХАНИЗМ: free-тоталы ≡ 0 (mod 16) (MakeFreeMulticluster/Sweep дают
    (size-24)DIV16*16; Insert/Sweep хранят size=total-8), tsize ≡ 0 →
    остаток a = total-tsize ∈ {0,16,32,...}. Ветка absorb
    `ELSIF a > 0 THEN INC(tsize,a)` (минимум Insert=32, FreeDesc=24)
    срабатывала РОВНО на a=16: блок физически занимал stride+16, но
    [code] Next вычисляет stride из tag/last — поглощённые 16 байт
    НЕВИДИМЫ → sweep проваливается в sliver → tag=0 → краш. В 32-бит
    absorb-случая не существовало (min Insert=16, a≡0 mod 16 → a=0 или
    a≥16-Insert); регрессия введена нашим минимумом 32 (FreeDesc=24).
    ФИКС (System/Mod/Kernel.odc.txt): GetOldFreeBlock пропускает free-блок,
    если b.size - s = 16 (`WHILE (b.size < s) OR (b.size - s = 16)`);
    в NewBlock ASSERT((a=0)OR(a>=32), 22) + удалена мёртвая ветка absorb.
    Побочный эффект: free-блок с остатком 16 пропускается → чуть больше
    фрагментации, GC сольёт с соседями. НЕ трогать: Insert(16) невозможен —
    FreeDesc.next лежит по offset 16, запись накрыл бы tag следующего блока.
    Техника: реконструкция GC-хода в gdb python по post-mortem памяти —
    рабочая, т.к. Mark восстанавливает tag (mark-бит маскируется 0xFC,
    array-бит стабилен); блоки ≡ 8 (mod 16) (кластер+24).
76. **GC: Mark спускался в free-блоки и мусорные "дескрипторы" (2026-08-09).**
    После фикса п.75: первый GC при большой компиляции → SIGSEGV в Mark
    (DSW-traversal): MarkGlobals/MarkLocals вызывают Mark на блоках, чей tag
    НЕ дескриптор: free-блок (tag = ADR(size), т.е. указатель в кучу) или
    протухший глобал/SYSTEM.PTR в освобождённую память. Доказано gdb:
    actual = this+8 = 0x6003f9c0, offset = 0x42AA28A0 (мусор из
    "дескриптора" в куче), ap = actual+offset = 0xA2AE2260 → crash.
    ФИКС (System/Mod/Kernel.odc.txt, Mark): и на входе, и на down-шаге
    проверяется дескриптор: dt := tag - tag MOD 4; спуск только если
    (dt > 0) & ~InHeap(dt) — дескриптор обязан лежать в модульной памяти,
    не в куче. В 32-бит той же дыры не было видно: чтения попадали в
    mapped-память и мусор маркировался молча (повезло), а free-list
    указатели, видимо, не попадали в ptrs-метаданные. НА ЗАМЕТКУ: ptrs
    глобалов может содержать сомнительные слоты — если вылезет снова,
    искать КОНКРЕТНЫЙ модуль/слот (frame-археология через modList —
    Module record: next@0, nofptrs@44, varBase@96, ptrs@112, name@136).
77. **КОДГЕН: загрузка глобала Int32 как r64 (мусор в индексном регистре).**
    MarkLocals: candidates[nofcand] := max — nofcand (INTEGER) грузился
    `mov rax, [rip+disp]` (8 байт!) → старшие 32 бита = соседний глобал
    (0x60040000) → rax*8 → запись по адресу-мусору → SIGSEGV. Место:
    Dev/Mod/CPLamd64.odc.txt GenMove, ветвь `(to.reg = AX) & (from.mode =
    Abs) & (from.scale = 0)`, подветвь `from.obj # NIL` — там стоял
    безусловный REXW + 8BH. Латентно било ВСЕ Int32-глобалы во всех
    модулях (обычно маскируется последующими 32-битными операциями;
    фатально при 64-битном использовании регистра — индексы/адреса).
    ФИКС: REXW только если Size[from.form] >= 8, опкод 8AH + w (как в
    общей ветке). Сборка: go32.sh DevCPLamd64 (dev0), затем test64.sh.
    ПРИМЕЧАНИЕ: похожие безусловные REXW проверять везде в CPLamd64.
78. **baseStack = 0 — консервативный скан стека в MarkLocals НИКОГДА не
    работал (2026-08-09, КОРЕНЬ серии крашей).** bbrun64 предустанавливает
    modList для CP Kernel → тело Kernel пропускает ветку `IF modList = NIL`,
    где был `S.GETREG(SP, baseStack)` → baseStack = 0 навсегда →
    `WHILE sp < baseStack` ложно сразу → candidates не собираются →
    объекты, живые только через стек (локальные переменные DevCPT при
    импорте sym!), умирают при первом GC → use-after-free → крахи GC.
    Доказательная цепочка: watchpoint-жизнь блока B (DevCPT.Struc):
    alloc (NewObj из InObj) → Sweep освобождает (Insert, caller=Sweep) →
    DevCPT пишет в мёртвый объект → следующий GC падает. В момент
    освобождения: heap/module ссылок нет, на стеке указатель есть
    (InObj+0x2d6 push obj), но в candidates[] его нет → скан мёртв →
    baseStack = 0 (gdb: root @0x42636158, baseStack @0x42636160 = 0).
    ФИКС: тело Kernel — `IF baseStack = 0 THEN GETREG(SP,baseStack) END`
    вне ветки modList. Урок процесса: эта бага объясняет и "ASLR-
    зависимый краш" п.66, и часть исторических GC-крахов.
79. **Техника gdb (накопленное):**
    - HW watchpoint сообщает $pc ПОСЛЕ пишущей инструкции (брейк надо
      ставить на несколько байт РАНЬШЕ, по дизасму ocf).
    - CODE-breakpoints (int3) в модульной памяти НЕ работают, если
      поставлены до загрузки модуля: лоадер перечитывает .ocf поверх
      патча. HW watchpoints работают всегда (heap мапится рано).
      Поздний якорь — первый printf: heap уже замаплен, код ещё нет.
    - FreeDesc.next в OCF v2 лежит по offset 12 (выравнивание максимум
      4!), не 16. Cluster: size@0, next@4 (8-байтный по 4-смещению!).
      Проверять layout дизасмом, не предполагать natural alignment.
    - MarkLocals/DSW: min/max/p через FPU (intrealtyp) — точные 64-бит.
    - python в gdb commands с вложенными end ломается — выносить в
      отдельный .py и source после остановки (if $hit<N cont end).
80. **Кодеген: SYSTEM.GETREG/PUTREG с LONGINT (2026-08-09, исправлено).**
    Int64 в регистрах = ПАРА (reg=lo, index=hi) — см. CPCamd64.LoadLong.
    getrfn делал MakeReg(y, reg, Int64) без index → hi брался из
    мусорного регистра (eax) → MarkLocals сканировал не стек, а ~0x0000
    0000ffffXXXX → SIGSEGV. putrfn симметрично (mov ebp,lo затирает hi
    нулями). ФИКС: CPVamd64 getrfn/putrfn для Int64 — через новые
    CPCamd64.PtrToLong* (split: mov rh,r64; shr rh,32) и LongToPtr*
    (join: mov r,hi; shl r,32; or r,lo). PtrToLong и LoadLong теперь
    экспортированы (были приватные; у PtrToLong была forward без *).
    Проверено дизасмом: GETREG(FP,sp) теперь mov rbp,rax; shr; 2 stores.
81. **Статус "0ErrorsDetected" = УСПЕХ (ресурс #Dev:Ok в статус-баре),
    НЕ ветка ошибки!** Реальная ошибка = маркеры "pos= err=". Урок:
    не путать. ORD(BOOLEAN) → err 111 (не поддержан компилятором).
82. **В РАБОТЕ (слепок 2026-08-09 вечер):** компиляция внутри BB64
    (ConsCompiler64.Compile) завершается "успешно", но .ocf НЕ пишется
    (strace: нет openat(O_CREAT) вообще) → выполнение свежего модуля
    (Probe8.T) = CommandError CodeFileNotFound (то, что видел
    пользователь!), а при выполнении — wild jump (pc=0x766C... в main
    нити) — вероятно отдельный баг обработки отсутствующего модуля.
    Цепочка записи: DevCPVamd64.Module → DevCPM.NewObj(SelfName) →
    objFile := Files.dir.New(loc, ask) (loc из Librarian.lib.GetSpec)
    → DevCPE.OutCode → хвост: IF noerr THEN DevCPM.RegisterObj →
    objFile.Register(ObjFName,...) — syscalls нет → OutCode/RegisterObj
    не доезжают ИЛИ Files.dir.New/Register молча не работают в 64-бит.
    СЛЕДУЮЩИЙ ШАГ: проверить дизасм/логи, доезжает ли до OutCode
    (между NewObj и OutCode много кода — возможен тихий уход), и
    Files.Register в LinFiles на 64-бит корректность.
83. **GC use-after-free (основная нить):** DevCPT.Struc (NewObj из
    InObj, caller DevCPT+0x79) освобождается Sweep, будучи живым;
    InsertIn+0xf9 пишет в мёртвый. Доказано: (а) указатель на объект
    лежит на стеке в локале InObj.obj (InObj+0x64) ДО GC; (б) скан
    MarkLocals ЧИТАЕТ этот слот (rwatch), но в candidates[] он не
    попадает; (в) candidates-батчи (45/26/24 записи) B не содержат;
    (г) min/max/baseStack корректны, константа 16.0 на месте.
    ПОДОЗРЕНИЕ: FPU-кодировка теста `(~strictStackSweep OR p MOD 16=0)`
    (fprem/ftst/fcom/xor/fadd/fcomps по константе @...fd6 — значение не
    проверено!) или ранний GC с меньшим max. Проверить константу fcomps
    и логику boolean-through-FPU в CPVamd64.
84. **GTK/нити:** pangoft2 (шрифты, LinFonts) создаёт glib-потоки при
    загрузке (g_object_new → g_thread_new) даже в консольном режиме;
    они получают сигналы (sig=15/18) и LinKernel.HandleTrap (на ВСЕ
    сигналы процесса) ловит их как BB-трапы → шум/каскады. Main-нить
    при этом падает отдельно (wild pc). Разводить: HandleTrap должен
    обрабатывать только SEGV/FPE/ILL/INT и только main-нить.
85. **gdb техника (дополнение к п.79):** rwatch работает для ловли
    чтений; code-breakpoints в модульной памяти теряются при дозагрузке
    (перечитывание .ocf поверх int3) — ставить только hw watchpoints или
    брейки после полной загрузки; якорь — break printf (heap замаплен,
    модульный код ещё нет). В batch+python: не вкладывать python в
    commands с вложенными end — выносить в .py и source после стопа.

== Сессия 2026-08-15 (GUI-ветка, корневой баг GC найден) ==

86. **Kernel.AllocModMem: единый регион на все 4 блока.** Раньше
    desc/meta/code/var выделялись отдельными mmap(MAP_32BIT) и
    разъезжались по всем 4 ГБ → RIP-relative disp32 (знаковый ±2 ГБ) не
    влезал → SHORT(disp) через FISTP m32 → SIGFPE в StdLoader.Fixup при
    загрузке LinInit. Фикс: один непрерывный mmap на суммарный размер,
    блоки раскладываются внутри (munmap поддиапазонов при
    DeallocModMem/InvalModMem легален). Проверено: LinInit dad/mad/cad
    идут подряд от 0x60040000.

87. **LinKernel.ThisDllObj: StubFor-трамполины.** Раньше
    SHORT(dlsym(...)) урезал адрес libc до 32 бит. Теперь как в
    bbrun64.c: `mov rax,imm64; jmp rax` (48 B8 <8> FF E0), bump по 16
    байт в RWX-страницах с MAP_32BIT; модульные переменные
    stubPage/stubLeft.

88. **bbrun64: невыбранному лоадеру ставить opts |= init.** Иначе
    ленивый Kernel.InitModule (Meta.Lookup по modList, напр. из
    LinInit.SearchVar) прогонял тело LinIntLoader в GUI-режиме →
    консольный REPL → EOF stdin → тихий Quit(0) до старта GUI.
    (~строка 829 bbrun64.c.)

89. **bbcp64use: Rsrc-симлинки.** "cannot open menu file" было из-за
    отсутствия Rsrc; сделано: для System/Std/Text/Form/Dev/Obx
    `ln -s ~/sources/bbcp/<S>/Rsrc bbcp64use/<S>/Rsrc`.

90. **КОРЕНЬ use-after-free всей недели: MarkLocals сканировал стек с
    FP≡4 (mod 8).** У этого кодгена rbp бывает не 8-выровнен
    (наблюдали rbp=...7a34); скан с `S.GETREG(FP, sp)` и шагом 8 читал
    все слоты со сдвигом 4 → 8-выровненные pointer-слоты не находились
    → якорей нет → Sweep собирал живые объекты (TextModels-Piece,
    DevCPT.Struc — п.83 и все прежние UAF). Проявления: ASSERT 32 в
    Kernel.Insert (free-спан через живой Piece), порча size free-блока
    из StdModel.Internalize → Next() за кластер. ФИКС: в MarkLocals
    после GETREG: `INC(sp, 7); sp := sp DIV 8 * 8`. После фикса:
    консоль чистая, P10 (2000 объектов + 3 collect) OK. УРОК: п.83 —
    FPU-константа была красной селёдкой, реальная причина —
    выравнивание; "слот читается, но не маркируется" надо было читать
    как "читается НЕ ТОТ слот".

91. **FPU-leak check в bbrun64 чист.** Под BB_FPUCHECK: fxsave +
    ftw/fsw после каждого тела модуля — тела не текут. fctrl=0x37e
    (invalid-op unmasked, by design Kernel.InitFpu) — любая FPU-ошибка
    = SIGFPE на следующем fwait.

92. **gdb-рецепты (GUI/модули).** До загрузки модулей sw-breakpoints в
    их коде затираются fread лоадера → якорь: `set environment
    BB_TRAP=1`, run → SIGILL → `set $rip = $rip + 2` → ставить bp →
    `signal 0` (НЕ continue — иначе сигнал уйдёт в HandleTrap!).
    refs из ocf.py = КОНЦЫ процедур (entry = предыдущий конец). Дизасм
    ocf.py файловый (sentinel 0x6Axxxxxx), реальный disp — только в gdb
    по runtime-адресу; после trap-encoding (8D xx) дизасм
    дезсинхронизируется — читать байты (x/28bx).

93. **Текущий SEGV (2026-08-15, не закрыт):** GUI доходит до
    `[LI] configCmd=StdConfig.Setup`, `SetupBefore res=0`, затем SEGV в
    TextModels.Find+0xfc8 (pc=0x4285BFC8: `cmp 0x10(%rax),%edx` — v.len
    при v=NIL, addr=0x10) во время StdConfig.Setup (чтение Menus.odc
    через Views.OldView → StdReader.ReadPrevView → Reset → Find).
    Данные: Find идёт по живому, но НЕ замкнутому piece-списку с
    m=0x12e0=4832 при t.len=4291 — нарушен pre Find (pos <= t.len) →
    rd.pos/rd.state неконсистентны. reader obj ~0x60002d80:
    base@0x18=0x6003fa90 ✓, dword@+0x20: [1, 0xffffffff] — -1 рядом с
    pos=1. Piece-список цел (адреса убывают по mmap-кластерам — GC не
    при чём). ГИПОТЕЗА: 32/64 путаница в цепочке чтения
    Stores/LinFiles64/StdReader (rd.pos/era/off, ReadInt, версии
    Stores). Пробник ObxProbe11 (чтение Menus.odc в консоли) НЕ
    скомпилировался: err 83 at pos 887,910 — на `IF v IS
    TextViews.View THEN` / приведении; выяснить err 83
    (Dev/Rsrc/Errors.odc) и поправить.

94. **Карта модулей (gui_run5/6):** Kernel cad=0x42655000 (cs=25652
    после фикса MarkLocals), StdLoader 0x42678000, LinKernel 0x426c4000,
    LinLoader 0x427b7000, TextModels 0x4285b000, Stores 0x4275d000,
    Views 0x427ca000, Documents 0x42842000. Полная карта печатается в
    начале прогона (`+ Module dad=... cad=...`). Kernel refs старого
    ocf устарели после пересборки — пересчитывать через ocf.py.

95. **Layout (подтверждено):** FList node: tag@obj-8, next@0, blk@8,
    iptr/aiptr@16. Piece: prev@0, next@8, len@16, attr@24, file@32.
    StdModel: trailer@48, pc.org@56, pc.prev@64, spill@72, rd@80,
    size=88, ptroffs=[0,48,64,72,80,-24,-1]; trailer.len=0x7FFFFFFF.
    Runtime ptroffs-дескриптор: [offsets..., отрицательный up-link,
    -1], tag указывает сразу на offsets (header из OutDesc не
    попадает). Block: tag@0,last@8,actual@16,first@24, объект=b+8;
    free-блок: tag=b+8, stored size=total-8; array-блоки: tag|2.
    Cluster: size@0,next@4, блоки с base+24; кластеры 256КБ, mmap
    top-down (новые НИЖЕ).

== Сессия 2026-08-15 (вторая половина): GUI ожил ==

96. **MarkLocals: шаг 4, а не 8 (ЗАМЕНЯЕТ п.90 частично).** Выравнивание
    на 8 из п.90 недостаточно: компилятор ПАКУЕТ 8-байтные поля записей
    без 8-выравнивания (Cluster.next@4, max@12), поэтому указатели на
    стеке (поля записей-локалов, напр. Stores.Reader) бывают на адресах
    ≡ 4 (mod 8). Скан с шагом 8 любой фазы пропускает половину слотов.
    Доказано в gdb: в фатальном collect якорь модели лежал ТОЛЬКО в
    слоте ≡4 (mod 8) → Sweep освободил живой Piece → SEGV в
    TextModels.Find (v.len при v=NIL). Фикс: `INC(sp,3); sp := sp DIV
    4 * 4` + шаг 4. Техника охоты: watchpoint на trailer.next/tag блока
    + счётчик collect'ей (Collect/FastCollect entry) + стек-скан из gdb.

97. **Views.Overwritten: 32-битная реликвия.** SYSTEM.GET(TYP(v) - 4*(mno+1))
    → метод-слоты 8-байтные: -8*(mno+1). Иначе мусор → ASSERT 20 в
    View.CopyFrom при чтении меню (SIGILL trap 20).

98. **HandleTrap: только fault-сигналы.** Вешался на ВСЕ сигналы
    1.._NSIG-1 → ловил SIGCONT/SIGURG от glib-потоков (pango thread
    pool) → каскад фальшивых трапов → "Recursive trap" abort. Теперь
    только SIGINT/SIGILL/SIGFPE/SIGPIPE/SIGTERM (+SIGSEGV на altstack).

99. **Try-машинерия на ADDRESS.** Kernel.TryHandler/Try, Platform.Try,
    Setup OUT try: INTEGER→ADDRESS. Каскад правок: Kernel.ExecFinalizer/
    TrapCleanup/Report (были (_,__,___: INTEGER)), Dialog.Exec,
    Services.Try/TryRec (убраны SHORT вокруг ADR — усекали стековые
    адреса → SEGV в Services.TryHandler), SafeRecAction.adr/typ →
    Kernel.ADDRESS, StdTabViews.ExecNotifier (from,to → Kernel.ADDRESS,
    тело SHORT(from/to)). CPB: StPar1 THISRECORD/THISARRAY разрешён
    Int64 при processor=12 (было только Int32 → err 111).
    УРОК: err 115 "parameter does not match" показывал позиции НЕ те
    (начало следующей процедуры); нашли инструментацией
    CPB.CheckParameters (печать имён через DevCPM.LogW*) — виновники
    ExecFinalizer/TrapCleanup/Report.

100. **КОРЕНЬ "errors detected in menu file": баг кодегена GenConOp
    ripTrail.** CPLamd64.GenConOp: для `cmp byte-глобал, imm8`
    (80H /7 id) ripTrail ставил 4 вместо 1 → loader считал disp32 =
    target-(ladr+4+4) вместо (ladr+4+1) → ЧТЕНИЯ bool/byte/char8
    глобалов съезжали на -3 (читали паддинг = 0 → всегда FALSE).
    Записи были верны (GenMove имеет кейс `from.form <= Int8 → 1`,
    GenConOp — нет). Проявление: `noerr := TRUE; IF noerr` → FALSE;
    `boolVar & (strEq OR strEq)` неверно → StdMenuTool.ParseMenus
    не входил в цикл → "MENU expected". Минимальный репробник:
    ObxProbe17 (VAR g,g2: BOOLEAN; i: INTEGER). Диагностика:
    ASSERT(g,77) в пробнике → SIGILL в gdb → runtime-дизасм write vs
    read target; цепочки data-фиксапов из ocf (slot = next24+typ*2^24,
    typ=106+immLen). ФИКС: GenConOp: `(s = 2) OR (src.form <= Int8) →
    ripTrail := 1`. ПОСЛЕ ФИКСА — ПОЛНАЯ пересборка мира (баг зашит
    во все ранее собранные ocf!), включая build-dev64.

101. **Техника: отладка компилятора.** Инструментация DevCPB/DevCPP
    принтами (DevCPM.LogWStr/LogW/LogWNum; ORD(BOOLEAN) = err 111,
    нельзя; DevCPT.String = SHORTCHAR[] — печатать посимвольно LogW);
    пересборка 32-бит: go32.sh DevCPX (грузится dev0 из Dev/Code);
    probes: Obx/Mod/ProbeN.odc.txt → go64.sh → консольный прогон.
    GUI-окна проверяются xwd-скриншотом (конверт в PNG вручную python).

102. **subs64/test64 тонкости.** subs64 прячет bbcp64use/Dev →
    ConsCompiler64 падает с err 249 (inconsistent import: берёт 32-бит
    Dev-sym из bbcp) — артефакт тулинга, не регрессия; ConsCompiler64
    собирается в build-dev64.sh. После смены интерфейса Kernel
    (TryHandler) все зависимые ocf "illegal footprint" → обязательна
    пересборка подсистем (subs64/test64), иначе loader молча скипает
    модули → NIL-вызовы.

== Сессия 2026-08-15 (финал): GUI работает ==

103. **SysVPostCall не снимал слоты аргументов.** SysVPreCall кладёт
     аргументы на стек ДО push r12 и читает их из [r12+8+i*8];
     SysVPostCall делал только `mov rsp,r12; pop r12` → слоты оставались.
     Для верхнеуровневого ccall безвредно (кадр чистится mov rsp,rbp),
     но при ВЛОЖЕННОМ ccall (результат одного ccall = аргумент другого)
     остатки слотов внутреннего вызова сдвигают аргументы внешнего:
     pango_layout_line_get_pixel_extents(pango_layout_get_line(...),
     NIL, rect) получал (line, мусор, NIL) вместо (line, NIL, &rect) →
     pango писал logical_rect куда попало → порча g_class → SEGV в
     pango_layout_get_text. Фикс: SysVPostCall(nslots) + add rsp,
     nslots*8. Проверка: gdb break на C-функции, печать rdi/rsi/rdx.

104. **LinKernel.StubFor возвращал start+11** (p после последнего PUT)
     — вызов runtime-загруженных dll-функций (g_timeout_add из LinInit)
     прыгал на байт E0 трамплина → loopnz → нули → SEGV addr=0.
     Boot-стабы (bbrun64.c StubFor) были верны — поэтому packed-модули
     работали, а runtime-модули (LinInit) падали. Фикс: RETURN SHORT(p0).

105. **C→BB callbacks (GTK signals) — две ошибки в SysV Enter/Exit.**
     (а) CP-код использует rbx/r12-r15 как scratch, а GTK ждёт их
     сохранёнными → в Enter для [ccall]-процедур добавлены push
     r15,r14,r13,r12,rbx (над аргументами, чтобы [rbp+16]=arg1 не
     съехал), в Exit — mov из [rsp+56..88]. (б) ГЛАВНОЕ: выход был
     plain ret (GenReturn(0)) — 6 рег-аргументов (+5 сохранений)
     оставались на стеке C-вызывающего → каждый callback сдвигал rsp
     GTK на 48 (стало 88) байт → каскадная порча (g_closure_invoke с
     closure=наш func_data, call *heap-указатель). Фикс Exit: mov r11,
     [rsp]; add rsp, 96; jmp r11. Диагностика: break на вход/выход
     callback'а, сравнение rsp и [rsp]. ПРИМЕЧАНИЕ: Enter/Exit для
     [ccall] уже существовал (pop r11/push args), но балансировка была
     неверна изначально — в 32 битах было cdecl с ret $n, всё сходилось.

106. **РЕЗУЛЬТАТ: 64-битная среда BlackBox поднимается**: меню
     (File/Edit/.../Help), главное окно, окно Log, ноль трапов за прогон.
     Проверка окна: wmctrl -l + xwd-скриншот.

107. **Техника сессии (gdb).** Пробник с ASSERT(x,99) → SIGILL до
     handler'а в gdb → runtime-дизасм с реальными disp. Watchpoint на
     поле объекта (g_class) для поимки порчи. Условный bp на
     g_closure_invoke для не-heap closure. Скриншоты окон через xwd +
     ручной xwd→png на python (convert отсутствует). Модули: ocf.py
     refs = КОНЦЫ процедур; entry = конец предыдущей (в refs-листе
     легко ошибиться на один proc — проверять байты пролога!).

108. **Int64-КОНСТАНТА как value-параметр пушилась ДВУМЯ qword (hi, lo)
     вместо одного** — корневой баг сессии 2026-08-16. Наследие i386
     (там push = 4 байта, Int64 = пара регистров). Каждый вызов с
     LONGINT-константой сдвигал ВСЕ последующие параметры на 8 байт.
     Жертва: Services.DoLater(resetBar, immediately=-1) — resetBar не
     выполнялся → ASSERT(bar = NIL, 100) в StdDocuments.HandleCtrlMsg
     при Help→Contents. Фикс: CPCamd64.Param, ветка ap.mode = Con +
     par.form = Int64: mov rax, imm64; push rax (ОДИН слот). Ветка
     curCCall паттерн уже имела. Верификация: ObxProbe21/22
     (LONGINT+BOOLEAN параметры, SYSTEM.ADR раскладка) — до фикса
     BOOLEAN попадал в байты чужих слотов, после — всё сошлось.
     ТЕХНИКА: дизасм показал, что callee (Echo) всегда был прав
     (time@rbp+16, nb@+24, ret 0x20) — ломался caller с константами.
     Урок: сравнивать caller и callee дизасм РАНО, не крутить рантайм.
     ПОСЛЕ ТАКОГО ФИКСА КОДГЕНА — полная пересборка мира (баг зашит
     во все .ocf): test64.sh System Lin Std Text Form Cons Obx.
     NB: go32.sh DevCPCamd64 ОБЯЗАТЕЛЬНА после правок CPC*/CPV*/CPL*,
     иначе dev0 компилирует мир старым багом.

109. **THISARRAY/THISRECORD как actual для open-array/record параметра:
     лишний push (rsp)** — второй корневой баг сессии. Цепочка: вокруг
     adr-аргумента THISARRAY фронтенд ставит conv-узел с typ=intrealtyp
     (form=Real64; создатель НЕ найден — CPB.Convert инструментирован и
     НЕ создаёт его; узел появляется между CPB.StPar1 и кодогеном —
     открытый вопрос). expr(conv) в CPVamd64: conv-ветка →
     CPCamd64.Convert(x, Real64, -1) → ConvMove "int -> float" при
     m=Undef: `IF y.mode = Reg THEN Push(y) END` — значение пушится,
     ap.mode становится Stk. Затем CPVamd64.ActualPar thisarrfn-ветка
     звала DevCPCamd64.Push(ap) безусловно → GenPush(Stk) =
     `push [rsp]` — ДУБЛИКАТ вершины стека. Итог: 6 слотов вместо 5,
     out-параметр (b.ptr) получал значение len (3) → Utf8ToString писал
     movw по адресу 3 → SEGV. Проявление: Help→About (About.odc
     содержит PNG-логотип → LinRastersPng.ThisDpi →
     Utf.Utf8ToString(THISARRAY(ADR(a[0]), len), b, res)).
     Фикс: CPVamd64.ActualPar — `IF ap.mode # Stk THEN Push(ap) END`
     для обоих push (тот же страж уже стоит в CPCamd64.Param для
     Pointer-ветки, см. п.~97 intrealtyp). Верификация: ObxProbe23
     (Plain vs ThisArr: дизасм 5 push vs 6; после фикса оба по 5),
     About открывается с логотипом. Пересобраны: Meta, Services,
     LinFiles, LinRastersPng (все с THISARRAY/THISRECORD в мире).
     ТЕХНИКА: трассировка компилятора принтами ap.mode/ap.form прямо в
     ActualPar/expr (go32.sh DevCPVamd64 → go64.sh пробника) локализует
     за 1 итерацию то, что дизасм-археология искала час.
     NB: Console в 64-бит мире НЕ имеет WriteInt — только
     WriteStr/WriteChar/WriteLn; DbgSz-рекурсия для чисел.

110. **Инфраструктура.** (а) bbcp64use не имел Docu — Help→Contents
     падал "file Docu/Help not found": добавлены симлинки Docu (корневой
     + per-subsystem) из bbcp. (б) bbrun64 в Dev/Rsrc был STRIPPED —
     gdb-хелперы (findmod/stackscan из tools64/gdb) слепли без символа
     modlist; пересборка `gcc -m64 -std=c99 -Wall -g -D_GNU_SOURCE -o
     bbrun64 bbrun64.c -ldl` (команда из tools64/cycle64.sh:18).
     (в) About-диалог показывает литералы appVersion/buildNum/buildDate
     — подстановка полей версии не работает (мелочь, отдельная задача).
     (г) При закрытии GUI: free(): invalid pointer (libc) — открыто.

111. **LONGINT-арифметика (+,-,*,DIV,MOD,сравнения) — ПРАВИЛЬНА**
     (ObxProbe24: a=1234567890123, b=10007; a+b, a-b, -a, a*2,
     a DIV b=123370429, a MOD b=7120, c=-a: c DIV b=-123370430
     (floor!), c MOD b=2887 (неотрицательный) — всё сошлось с CP-
     семантикой). DIV/MOD для Int64 идут НЕ через CPLamd64.GenDiv
     (там 32-битный idiv/cdq) — видимо через x87-путь; TODO64-коммент
     в CPLamd64:804 (dec rax/cqo) относится к мёртвому для Int64 пути.
     Ошибки err 260 при этом НЕ выдаётся — CPVamd64 потерял проверку
     `f = Int64 → err(260)` которая была в CPV486; фактически Int64
     арифметика реализована (LongAdd/LongSub/LongCmp + FPU) — это
     надо задокументировать, а не "чинить" обратно.

112. **п.82 ЗАКРЫТ: in-BB компиляция пишет .ocf** (2026-08-17).
     ConsCompiler64.Compile("", "Probe2.cp") в BB64-консоли создаёт
     System/Code/Probe2.ocf, Probe2.T выполняется без
     CommandError CodeFileNotFound. Полечено как ПОБОЧНЫЙ ЭФФЕКТ
     фиксов кодгена п.108/п.109 (Int64-константа в параметрах ломала
     Files.Register/OutCode — там передаются адреса/размеры).

113. **ripBased-фиксап: bt m32,imm8 эмитился с типом 106 (immLen=0)
     вместо 107** — CPLamd64.GenBitOp не выставлял ripTrail := 1 для
     Con-ветки (0F BA /5 ib — imm8 СЛЕДУЕТ за disp32). Лоадер считал
     disp = target-(linkadr+4+0) вместо -(linkadr+4+1) → ВСЕ
     rip-relative доступы к глобалам через bt с imm читали target+1:
     `31 IN options` (trap IN options) читал бит 7 первого байта
     СЛЕДУЮЩЕГО глобала → флаконо-зависимый HALT(100) в DevCPM.Mark
     при компиляции внутри BB64 (компилятор падал SIGILL вместо
     отчёта об ошибке). Диагностика: ocf.py bytes на месте HALT —
     маркер 6a вместо 6b в старшем байте disp32. Аудит: остальные
     инструкции с imm после disp32 (mov m,imm; ALU grp1; test; shifts)
     ripTrail выставляют — GenBitOp был единственным пропущенным.
     Фикс: ripTrail := 1 ... 0 вокруг 0BAH-эмиссии (идиома как в
     GenShiftOp). После фикса — полная пересборка мира.

114. **CPCamd64.Mem: SYSTEM.GET/PUT/BIT с адресом-выражением (a+4 в
     VAL(ANYPTR,...)) — err 220** (проявлялось как ObxTaAdr err 220).
     expr с stop ⊇ wreg законно оставляет значение в Stk/Ind
     (Assert в конце expr пушит, если регистры результата ∈ stop);
     Mem требовал Con|Reg (32-бит: expr всегда отдавала Reg).
     Фикс в CPVamd64.Mem: `IF x.mode # Con THEN IF x.form = Int64 THEN
     LongToPtr ELSE Load(x,{},{}) END END` — материализация адреса
     в регистр. Урок для Verification64 п.6.4-B: постусловие expr —
     "x.mode ∈ {Con,Reg,Stk,Ind,...} в зависимости от stop" — Mem
     должен принимать всё, что expr может вернуть по контракту,
     а не только Reg. Probe26 (a+4 внутри VAL) — компилируется,
     код верен (lea addr; fild/fadd/fistp для +4; mov (rax),eax).

115. **About: поля Version/Build — НЕ баг порта.** System/Rsrc/About.odc
     в bbcp идентичен оригиналу bbcb2 (diff пуст): значения
     appVersion/buildNum/buildDate подставляются релизным packaging'ом,
     в исходниках их никто не заполняет. Закрыто без действий.

116. **Sym-файлы portable; dev0 читает bbcp64use, fallback в bbcp.**
     LinFiles64.Old: при isUseDir & isCustomDir промах в useDir →
     customDir. run-dev0: standardDir=bbcp (по пути скрипта), useDir=cwd.
     Поэтому мир собирался по 32-битным osf и НЕ писал 64-битные в
     bbcp64use (fp совпадают → "new symbol file" не пишется) — это
     ШТАТНО. Для in-BB компиляции (bbrun64 без fallback) .osf должны
     лежать в bbcp64use — решается tools64/link-sym.sh (вызывается из
     test64.sh после wipe).

117. **LinBackends.KeyPressHandler.Do: g_free(SYSTEM.VAL(INTEGER, unused))**
     — unused это указатель от gdk_keymap_get_entries_for_keycode
     (g_malloc, выше 4ГБ); VAL(INTEGER,...) усекал до 32 бит →
     "free(): invalid pointer". Фикс: VAL(GLib.gpointer,...).
     ВАЖНО: остальные VAL(INTEGER, ptr) в LinBackends (строки ~470,
     ~629, ~653) трогают BB-arena объекты (<4ГБ) — безвредны, пока
     BB_ARENA_BASE=0x40000000; при переносе арены выше 4ГБ — чистить.
     Реестр класса "VAL(INTEGER, указатель)" см. Verification64 п.3-F.

118. **tools64/probes.sh — регрессия Obx-пробников** (17/17 PASS на
     2026-08-17). Probe7.P (S.GET по адресу 0) и Probe25.Go (NIL deref)
     — ловушки по дизайну, в список не включены. NB: вызов несуществу-
     ющей экспортированной команды в консольном REPL подвисает
     (CommandError-диалог ждёт?) — runner ловит это timeout'ом.

119. **GUI-верификация на новом мире (2026-08-17, после всех фиксов
     п.108-117) — ПРОЙДЕНА.** Живой клик-тест через MCP
     computer-control:
     - Help→Contents ОТКРЫВАЕТСЯ (ранее: ASSERT bar=NIL до фикса
       п.108, затем "index out of range" в StdMenus — оба ушли).
     - Ссылки в Help Contents работают: Guided Tour открывается,
       документ рендерится полностью.
     - Help→About работает (логотип есть; Version/Build пусты —
       не баг, п.115).
     - Obx→Trap!: окно трапа StdDebug ОТКРЫВАЕТСЯ и система ВЫЖИВАЕТ:
       "index out of range", ObxTrap.Do [0x4F] с локалками (.i=777),
       стек до Loop.Loop [0x132]; фреймы ядра/сервисов показываются
       как Module.??? (ref-инфо не резолвит неэкспортированные
       процедуры — косметика). Рекурсивных падений StdDebug больше
       нет (ранее: deref стекового адреса в StdDebug+0x174D).
     - Закрытие главного окна: процесс завершается БЕЗ
       "free(): invalid pointer" (фикс п.117 подтверждён вживую).
       Остаётся однократный GLib-GObject-CRITICAL
       "g_object_unref: assertion 'G_IS_OBJECT (object)' failed"
       на выходе — нефатально, вероятный ещё один усечённый/
       невалидный указатель в shutdown-пути LinBackends; записано
       как minor issue.
     - В логе при трапе: "~TRAP sig=4 code=2" — штатный SIGILL от
       HALT-инструкции ObxTrap, обработан kernel'ом.

120. **РАЗГАДКА intrealtyp (закрывает " conv-узел не найден" из п.108/6.6).
     Int64-арифметика = x87 FPU, дизайн BB 1.7/2.0 LARGEINT.**
     DevCPH.UseReals (вызывается из CPVamd64: `UseReals(prog,
     {longDop, longMop})`) обходит AST ПОСЛЕ CPB и перетипирует:
     Ndop с Int64-операндом → оба операнда force-Convert в intrealtyp,
     сам узел → intrealtyp; Nmop abs/minus с Int64 — аналогично.
     На выходе из рекурсии `~(hide IN opts) & (n.typ = intrealtyp)` →
     Convert(n, int64typ) — ВОТ создатель conv-узлов с typ=intrealtyp
     (тот самый вокруг adr-аргумента THISARRAY из п.108; CPH.odc не
     имеет .txt-экспорта, поэтому grep по txt его не находил!).
     intrealtyp = клон real64typ (CPT:1735): expr() в CPVamd64 берёт
     ветку `(f IN realSet)` → FloatDOp → fildll/faddp/fdivrp/fprem/
     frndint; Push материализует: `IF x.typ = intrealtyp THEN x.form
     := Int64` → FISTP qword. Целочисленный путь CPCamd64 (LongAdd/
     LongSub/LongCmp/LongNeg/LargeInc, пары lo/hi) для выражений
     ЗАТЕНЁН UseReals — жив для INC/DEC (LargeInc) и SYSTEM-путей
     (LongToPtr для адресов). GenDiv/GenMul (CPLamd64) Int64 НЕ
     достигают — TODO64-коммент про "dec rax + cqo для Int64" на
     CPLamd64:804 МОТ (moot): GenDiv видит только <= Int32.

121. **Верификация LONGINT (Probe27+Probe28, сверено с Python):**
     +,-,*,DIV,MOD (вкл. floor-семантику отрицательных), унарный минус,
     сравнения, ASH (конст и ПЕРЕМЕННЫЙ сдвиг), ABS, MIN, MAX, ODD,
     max/min/±2^62 — ВСЁ ВЕРНО. Два известных ограничения:
     (а) SYSTEM.LSH/ROT на LONGINT → err 260 компиляции (UseReals
     делает узел intrealtyp, а lsh/rot исключены из FPU-ветки expr →
     CPVamd64:1258 err(260)); на INTEGER работают. Фикс = целочисленный
     сдвиг Int64 в кодегене (или не трогать lsh/rot в UseReals).
     (б) Переполнение Int64 → SIGFPE (FPE_FLTINV от FISTP вне
     диапазона), НЕ молчаливый wrap: в прологе процедур с FPU
     стоит `fldcw 0x33E` — invalid-op exception РАЗМАСКИРОВАН
     (дефолт x87 0x37F маскирует всё). Побочный эффект: 0.0/0.0 и
     прочие invalid real-опы тоже будут трапать — отличие от 32-бит.
     Решение осознанное (трап вместо тихой порчи), но задокументировать.
     NB: LSH/ROT в bbcp — SYSTEM-функции (CPT:1676), не преdeclared.

122. **Нативный single-reg Int64 (этап 2, коммит 5a19d12f).** UseReals
     (CPH) больше не вызывается из CPVamd64.Module — Int64-выражения
     идут целочисленно: значение = один 64-битный регистр (как Pointer).
     LoadLong/PtrToLong/LongToPtr = retype/один mov; DivMod через
     GenDiv (cqo+idiv REX.W); результат функции Int64 в RAX (SysV тоже).
     Переполнение = wrap (как в 32-бит), SYSTEM.LSH/ROT на LONGINT
     работают. Пара lo/hi мертва (LongAdd/LongSub/LongCmp/LongNeg/
     MakeLongHi — удалить при чистке). intrealtyp-машинерия спит.
     Конверсии Int64<->Real по-прежнему x87 (fild/fistp).
     УРОКИ этапа: (а) GenConst32(short=TRUE) для C7 m64,imm32 —
     десинхрон потока кода (у C7 нет imm8): эмиттер съехал на 3 байта,
     crash в Kernel64.Init; (б) GetReg не знал Int64 — trap 130
     "invalid case"; (в) LoadLong->Load рекурсия (form=Pointer при
     typ=Int64); (г) Param (SysV ccall) использовал ap.index пары —
     мусор 99 (FReg sentinel) -> ASSERT в MakeReg. Все пойманы
     пробниками/пересборкой мира.
123. **ЗАВИСАНИЕ OpenBrowser('Docu/Tut-2') — открытая проблема.**
     Полный разбор: KB/HangTut2-GC-clusters.md. Кратко: куча раздувается
     до ~1300 кластеров по 256KB -> GC квадратичен (InHeap O(n) на
     кандидата) -> "вечный" GC при открытии документа со вложенными
     view. Регресс vs FPU-мира. Консольная репродукция есть.
