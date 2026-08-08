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
