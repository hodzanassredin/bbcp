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
