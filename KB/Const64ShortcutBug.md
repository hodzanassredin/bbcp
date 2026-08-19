# ИСПРАВЛЕННЫЙ БАГ: Int64-константы с нулевыми младшими 32 битами превращались в 0 (2026-08-19)

## Симптом

GUI / Paket Update: `TRAP 139 division by zero` в Strings (StringToLInt+421),
затем вторичный трап в DevDebug (frame-walker). Корневой код в StringToLInt:

```
10e8: mov 0x20(%rbp),%rax     ; x (OUT-VARPAR, дабл-дереф)
10ec: mov (%rax),%rax
10ef: xor %ecx,%ecx           ; делитель = 0  <-- hexLimit = 0x1000000000000000 потерян!
10f3: idiv %rcx               ; x := x MOD hexLimit -> деление по 0
```

Бьёт chunked-загрузку Paket: размер чанка — hex, парсится через StringToLInt.

## Корень

Представление Int64-константы в Item (Con): `offset` = младшие 32 бита,
`scale` = старшие 32 бита (для 32-битных значений scale = знаковое
расширение: 0 или -1). Подтверждено конвенцией GenPush/GenConOp:
"fits imm32" ⟺ (scale=0 & offset>=0) OR (scale=-1 & offset<0).

В CPLamd64.GenMove (Con → Reg) shortcut `(offset = 0) & (obj = NIL)` эмитил
`XOR r,r`, игнорируя scale. Константа 0x1000000000000000 (hexLimit =
MAX(LONGINT) DIV 8 + 1 в StringToLInt) имеет offset=0, scale=0x10000000
→ обнулялась → idiv по нулю. При этом `hexLimit DIV 2` фолдился компилятором
правильно (movabs 0x0800000000000000 рядом) — баг именно в материализации
Con-итема, не в константной арифметике фронтенда.

## Весь класс shortcut'ов по младшим 32 битам (починено разом)

В Dev/Mod/CPLamd64.odc.txt:
- GenMove Con→Reg: XOR-обнуление — добавлено `& (from.scale = 0)`.
- GenMove a1-кэш (AX): сравнение констант — добавлено `from.scale = a1.scale`
  (иначе 0 и 0x1000000000000000 считались одной константой).
- GenComp: `or r,r` (сравнение с нулём) — `& (src.scale = 0)`.
- GenAnd: пропуск AND с -1 — теперь только при ПОЛНОМ -1 (offset=-1 И
  scale=-1); 0xFFFFFFFF (scale=0) для 64-битного dst не тождественность.
- GenOr/GenXor: пропуск при 0 — `OR (src.scale # 0)` (полный 64-битный ноль).
- GenMul: пропуск умножения на 1 — `& (src.scale = 0)`.

Латентное (НЕ тронуто, следить): GenTest с Int64 Con пишет imm32
(sign-extended) без проверки "fits imm32" — для констант >32 бит неверно;
типичные булевы тесты константами малы, поэтому не стреляло.

## Инвариант (добавить к Stk-инварианту из EntierStackBug.md)

Любая оптимизация/shortcut над Con-итемом обязана проверять ОБА слова
(offset И scale), либо явно ограничиваться 32-битными формами.

## Проверка

Probe52: StringToLInt("3039H") и ("100000000H") — при баге TRAP 139.
probes 28/28, Probe41 (HTTP GET) OK. Побочно выяснилось: имя —
StringToLInt (не StringToLongInt); hex-литералы > MAX(INTEGER) не компилируются
(err 203) — писать LONG(20000000H) * 8.

## Диагностический инструмент

ObxProbe51: маппинг code-офсета трапа в имя процедуры через
Kernel.GetRefProc (offset → owner). Не включён в probes.sh — dev-утилита.
Параметр target зашит в тексте, менять под задачу.
