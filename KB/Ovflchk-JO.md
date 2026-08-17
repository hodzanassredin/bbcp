# INTO → JNO+trap: overflow check (ovflchk) в amd64

Дата: 2026-08-17.

## Проблема

`DevCPLamd64` эмитил `GenByte(0CEH)` (INTO) после арифметики при ovflchk.
INTO **невалиден в 64-битном режиме** (#UD). ovflchk включается только
опцией allchecks ("+"), поэтому баг не мешал обычной компиляции.

## Решение

INTO заменён на штатный механизм трапов компилятора — `GenAssert`:

```pascal
IF ovflchk THEN GenAssert(ccNO, ovflTrap) END
```

`ovflTrap = 138` (integer overflow — тот же номер, что даёт 32-битный путь
через SIGFPE/FPE_INTOVF в `LinKernel.SigToErr`). Эмитится:

```
71 03        JNO +3        ; переполнения нет — пропускаем трап
8D F0 8A     LEA (mod=11)  ; невалидная → SIGILL → SigToErr: 8D F0 <n> → err=n=138
```

Заменено 6 мест: GenAdd, GenAddC, GenSub, GenSubC, GenNeg, GenMul.
GenAssert объявлен после мест использования → добавлен forward-decl
`PROCEDURE^ GenAssert* (cc, no: INTEGER);`.

ВАЖНО: генератор, которым dev0 кросс-компилирует мир, — это **32-битный**
`bbcp/Dev/Code/CPLamd64.ocf`. После правки CPLamd64.odc.txt нужен
`tools64/go32.sh DevCPLamd64` (для dev0) И `build-dev64.sh` (для мира).

## Инфраструктура компиляции с опциями (добавлена)

- `DevCompiler64.CompileTextOpt*(text, beg, opt, error)` — как CompileText,
  но со строкой опций ("+" = allchecks). Парсинг опций вынесен в
  неэкспортированный `ParseOpt`, используется и CompileOpt.
- `ConsCompiler64.CompileOpt*(path, name, opt)` — in-world компиляция с
  опциями из консоли: `ConsCompiler64.CompileOpt("Obx/Mod","Probe30.odc.txt","+")`.
  Умеет и .odc, и сырой текст (Load0).
- DevOnce "+"-суффикс НЕ сделан: 32-битная пересборка DevOnce/DevCompiler64
  упирается в sym-rot (KB/Bootstrap32-symrot.md), а in-world пути достаточно.

## Проверка

- Пробник `Obx/Mod/Probe30.odc.txt`: INC(MAX(INTEGER)) должен трапнуться.
- Статика: в `Obx/Code/Probe30.ocf` байты `71 03 8D F0 8A`, байта 0xCE нет.
- Динамика: `tools64/probes-trap.sh` — ждёт `~TRAP` и отсутствие "BAD".
  Probe30 НЕ добавлять в probes.sh (там любой ~TRAP = FAIL).
