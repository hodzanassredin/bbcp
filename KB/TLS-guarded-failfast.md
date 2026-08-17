# FS:[0]/TLS и guarded-процедуры — fail-fast (err 271)

Дата: 2026-08-17.

## Что было

Backend amd64 (CPCamd64.Enter/Exit, по флагу isGuarded из
CPVamd64.Parameters) генерировал SEH-стайл фреймы исключений:
`push fs:[0]` / `mov fs:[0], rsp` (GenCode(64H) = FS-префикс) —
наследие Win32, где FS:[0] = голова цепочки обработчиков.

На Linux amd64 FS-base указывает на TCB glibc, fs:[0] = self-pointer.
Запись туда ломает TLS glibc (pthread_self, dtv и т.п.).

## Почему fail-fast, а не redesign

- Потребителя цепочки на Linux НЕТ: `Kernel.InterfaceTrapHandler` —
  assert-stub. Трапы идут через sigsetjmp/siglongjmp
  (`LinKernel.currentTryContext`), не через FS-цепочку.
- isGuarded ставится только для: (1) явных `[guarded]` процедур —
  в исходниках ноль; (2) внутренних COM-interface thunks (TProc,
  numPreIntProc..) — ни один модуль мира не использует TO INTERFACE.
- Мёртвый путь, который молча портит TLS, — хуже, чем ошибка компиляции.

## Что сделано

- `Dev/Mod/CPVamd64.odc.txt` Parameters: `DevCPM.err(271)` при isGuarded.
- `Dev/Rsrc/Errors.odc`: 271 "guarded/interface procedures not supported
  on amd64 (FS:[0] is glibc TLS)".
- Код эмиссии FS-фреймов в CPCamd64.Enter/Exit оставлен (модуль с err 271
  не пишется), как референс для будущего redesign.

## Если интерфейсы понадобятся

Заменить FS:[0] на глобальную переменную головы цепочки в Kernel
(мир однопоточный — TLS не нужен вовсе) и реализовать ход по цепочке
в трап-обработчике. CPCamd64: Enter ~2396 (push-фрейм), Exit ~2451 (снятие).
