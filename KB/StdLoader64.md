# StdLoader: порт на OCF v2 (amd64), 2026-07-23

Std/Mod/Loader.odc.txt — Fixup и UseBlk-разбор портированы на 64-битный формат
(эталон Dev/Rsrc/bbrun64.c, формат KB/OcfFormat64.md).

## Ключевые решения

- `Fixup(adr: LONGINT; mod: ModSpec)` — приватная сигнатура расширена до LONGINT
  (экспортируемый интерфейс StdLoader не менялся).
- Чтение/запись слотов — typed-pointer идиома (S.GET/S.PUT по LONGINT-локалам
  роняют backend в Mem): локальные типы `IntRef` (4 байта) и `AdrRef` (8 байт),
  доступ `S.VAL(AdrRef, adr).a`.
- absolute/copy/table/tableend — 8-байтная запись (перезаписывает метаданные +
  sentinel 11223344H); relative и ripBased (106..114, immLen = typ-106) — 4-байтный
  disp32. table: следующий элемент `link + 8` (важно: link НЕ инвертируется при
  разборе meta/desc-цепочек, как в C; старый 32-битный код мутировал link).
- short=105 для amd64 не эмитится — в лоадере отсутствует (как в bbrun64.c),
  неизвестный тип → Error(syntaxError) + обрыв цепочки (n := 0).
- UseBlk: `Fixup(imp.mod.varBase + obj.offs)` / `procBase` без SHORT;
  mTyp: `Fixup(S.VAL(LONGINT, obj.struct))`; imports-таблица пишется типизированно:
  `mod.mod.imports[i] := imp.mod` (8-байтные элементы, без S.PUT/арифметики).

## Проверка

`tools64/sync-odc.sh && tools64/test64.sh System Std Text Form Lin Cons`:
StdLoader компилируется чисто. Контрольный прогон без правок (git stash)
подтвердил: 2 ошибки err 249 (InconsistentImport) в ConsCompiler64 — предсуществующие,
не связаны с лоадером (bbcp64use/*/Mod/*.odc — symlinks на bbcp, контроль валиден).

## Открытые вопросы (вне StdLoader)

- `Kernel.AllocModMem`/`ProtectModMem`/`DeallocModMem` — адреса VAR INTEGER
  (32 бита, SHORT внутри). Блоки модулей должны лежать < 4 ГБ; Lin AllocateModMem
  делает `addr := SHORT(Libc.mmap(...))` без MAP_32BIT — потенциальное усечение.
- `Kernel.ThisDllObj(...): INTEGER` — адреса DLL-объектов усечены до 32 бит
  (в bbrun64.c — intptr_t/dlsym).
- Runtime-верификация лоадера ещё не проводилась (только компиляция).
