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

## ГЛАВНЫЙ ОТКРЫТЫЙ БАГ: SysV FFI — см. KB/FFI-SysV.md

## Уроки процесса
- Ассерт-инварианты окупаются: BADPTR (Pointer/ProcTyp size=8) поймал
  processor=10 и builtin-types=4 НА КОМПИЛЯЦИИ, а не в рантайме.
- objdump ДЕСИНХРОНИЗИРУЕТСЯ на trap-энкодингах (8d f0 XX / 8d e7) —
  доверять только сырым байтам (x/Nxb).
- 32-битный эталон: компилировать тот же микро-модуль 32-битным бэкендом
  (go32) и diff дизасма — мгновенно показывает потерянные байты (dec!).
