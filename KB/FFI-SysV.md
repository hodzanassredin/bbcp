# SysV FFI (ccall) для amd64 — КЛЮЧЕВОЙ БЛОКИРУЮЩИЙ БАГ

## Диагноз (2026-07-23, подтверждено в gdb)

32-битная конвенция ccall (аргументы на стеке, caller cleanup) осталась в amd64
бэкенде. На x86-64 Linux (SysV ABI) первые 6 integer/pointer аргументов идут в
РЕГИСТРАХ: rdi, rsi, rdx, rcx, r8, r9; SSE: xmm0-7; остальные — на стеке.
Все вызовы `$dll` (LinLibc, LinGtk2*, LinDl, ...) сейчас получают мусор.

Симптом: `LinConsole.Init`: `Libc.fdopen(0, "rb")` вернул NULL → ASSERT(100) →
HALT (trap-энкодинг 8d f0 64). В gdb: rdi/rsi = мусор.

Вторичные баги той же зоны:
- `add rsp, 0x0c` после ccall: caller cleanup считает 4-байтные слоты
  (CCallParSize), а push всегда 8-байтные → накопительный дисбаланс стека.
- Адреса функций/FILE* сохраняются как 4 байта (`mov [rip],eax`) — усечение
  64-битных указателей. Корень: LinLibc типы (`PtrFILE`, `PtrVoid`, `long`,
  `size_t`) объявлены INTEGER. Нужно LONGINT (8 байт) — механическая правка
  Lin/Mod/Libc.odc + все потребители.

## План

1. Компилятор (CPCamd64.Call, sysflag ccall/ccall16): генерация SysV ABI:
   - integer/pointer args: rdi, rsi, rdx, rcx, r8, r9; далее стек (8-байтные
     слоты, выравнивание rsp по 16 перед call).
   - возврат: rax (int/ptr), xmm0 (real), st0 НЕ используется в SysV.
   - variadic (printf): AL = число vector-регистров (0 для наших).
   - callee-saved: rbx, rbp, r12-15 — BB-фреймы их не трогают (ок).
2. CCallParSize → только хвост за 6 аргументами (стековая часть).
3. LinLibc типы: INTEGER → LONGINT для указателей/long/size_t (PtrFILE, PtrVoid,
   long, size_t, ssize_t, off_t, time_t, ...). Ревизия всех RECORD-обёрток
   GTK (их поля-указатели тоже 8 байт, раскладка!).
4. Callbacks (ccall из C в BB: Fake в LinInit, GLib callbacks): SysV тоже —
   C зовёт нас с аргументами в регистрах; наш Enter должен их снимать.

## Связанные задачи

- LinConsole ASSERT(input # Libc.NULL, 100) — первая проверка FFI после починки.
- GUI (задача 5 в журнале) полностью завязан на GTK-вызовы.
