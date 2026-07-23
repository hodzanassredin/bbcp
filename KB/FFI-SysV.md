# SysV FFI (ccall) для amd64 — РЕШЕНО (2026-07-23/24)

## Реализация

Компилятор (DevCPCamd64 + DevCPVamd64 + DevCPB):

- `CPCamd64.SysVPreCall(nslots)` / `SysVPostCall` — эмиссия вокруг `GenCall`
  для `sysflag = ccall` (прямые вызовы XProc и proc-var):
  - `push r12; mov r12, rsp; and rsp, -16` — динамическое выравнивание
    (статически alignment BB-фрейма неизвестен), r12 сохранён => вложенность ок.
  - стековый хвост (аргументы за 6-ю) копируется вниз в выровненную область
    (`mov rax, [r12+8+nreg*8+i*8]; mov [rsp+i*8], rax`), место резервируется
    `sub rsp, (tail*8+15)//16*16`.
  - arg1..6 грузятся из исходной области: `mov rdi/rsi/rdx/rcx/r8/r9, [r12+8+i*8]`.
  - `xor eax, eax` — variadic AL=0 (printf).
  - Эпилог: `mov rsp, r12; pop r12` — снимает ВСЁ (хвост, паддинг, слоты).
    AdjustStack для ccall больше не используется.
- `CCallSlots(proc, typ)` — число 8-байтных слотов аргументов (cdecl-порядок
  пушей: ActualPar рекурсией кладёт справа-налево, [rsp] = arg1; каждый слот
  = один C-аргумент). VarPar DynArr tagged = n+1 (adr + lens), Record tagged = 2,
  остальные = 1, by-value comp > 8 = (size+7)//8.
- `curCCall` (VAR в CPCamd64): контекст "идут параметры ccall" для Param.
  Ставится в PrepCall (прямые) и `CPCamd64.BeginCCall` (proc-var, из
  CPVamd64.Call). В Call сохраняется/восстанавливается (вложенные вызовы).
- Int64 value-параметр при ccall = ОДИН 8-байтный слот (Param):
  Con -> `mov rax, imm64; push rax`; Reg-пара -> sub rsp,8 + 2 dword-сторa;
  32-бит Reg -> `movsxd rax, r; push rax`; mem -> `push qword [mem]`.
- Int64 результат при ccall: SysV возвращает в rax; Call делит на пару
  lo/hi (`mov r_lo, eax; shr rax,32; mov r_hi, eax`) — backend держит Int64
  как пару регистров.
- `CCallParSize` больше для ccall не нужен (остался для ccall16).

## Проверено в буте

LinConsole.Init (fdopen ASSERT) прошёл; LinKernel.Init прошёл ЦЕЛИКОМ:
sysconf, mmap/munmap, calloc, sigaltstack (errno EINVAL ушёл после 64-битных
stack_t), sigaction loop, LibW.setlocale, SetPlatform, InitHeap.
Бут доходит до LinLoader.

## НЕ сделано / ограничения

- Callbacks C->BB (sa_sigaction, Fake, GLib): C кладёт аргументы в регистры,
  наш Enter ждёт cdecl-стек. Signal handlers сломаны до redesign (задача 5,
  isGuarded/fs:0 тоже 32-битный).
- REAL-параметры ccall (xmm0-7) не поддержаны — в GTK есть gdouble; слот
  считается как 1 int-аргумент (неверно, но таких вызовов на пути бута нет).
- By-value структуры > 8 байт в ccall: раскладка 4-байтными блоками из Param
  не совпадает с SysV (MEMORY-класс). Нет на пути бута.
- Int64-арифметика в backend ОТСУТСТВУЕТ: Ndop с form=Int64 -> DevCPM.err(260)
  + fallback вычисляет ТОЛЬКО левый операнд (молча неверный код!), в контексте
  Mem/GET падает компилятор (ASSERT в CPCamd64.Mem). Любая арифметика над
  LONGINT (size_t и т.п.) — бомба. Нужна реализация add/sub/cmp на паре
  (add/adc, sub/sbb) или переход Int64 на одиночный r64.
