# ИСПРАВЛЕННЫЙ БАГ: ENTIER в аргументах вызова — сирота-слот на стеке (2026-08-19)

## Симптом

Paket → загрузка списка пакетов: NIL deref в `Strings.IntToString` (s=NIL),
вызванной из `PaketHttp.Reader.Do`. Трап-окно (после фикса имён — refs 10X):
`IntToString[14B] .s NIL VARPAR, .x 0` ← `Reader.Do[1CE6]`.

## Доказательства (дизассемблер ocf)

Caller (Paket/Code/Http.ocf, Reader.Do ~0x1C97):
```
push $0x100              ; len(tmp)
lea  -0x438(%rbp),%rax
push  %rax               ; adr(tmp)
call  Ticks              ; (fixup)
...fildll/fdivs/frndint  ; FPU: (Ticks()-r.last)/1000
add  $-8,%rsp            ; ВРЕМЕННЫЙ СЛОТ для fistpl
fistpl (%rsp)            ; ENTIER пишет в темп
movslq (%rsp),%rax
push  %rax               ; push x  <-- темп-слот НЕ снят (нет add $8,%rsp)!
call  IntToString
```
Итог: между x и adr остаётся сирота-слот 8 байт → callee читает s-adr из
темп-слота (= 0, когда x=0) → NIL deref. Callee-раскладка верна
(x@[rbp+10h], s-adr@[rbp+18h], s-len@[rbp+20h]).

## Условие срабатывания

Вызов, где ДО FPU-аргумента (ENTIER/SHORT(ENTIER)/реальная математика через
x87-темп) уже пушнуты другие параметры. Одноаргументные вызовы не страдают.
Т.е. баг в эмиттере: последовательность alloc-temp → fistpl (%rsp) →
movslq → push не освобождает темп перед push.

## Куда смотреть (следующий шаг)

DevCPCamd64: эмиттер ENTIER-пути (CPB: entierfn/lentierfcn → CPCamd64).
grep "frndint|fistpl" в CPCamd64.odc.txt пуст — опкоды пишутся числовыми
константами; искать по комментариям/по образцу байт (D9 FC frndint,
DB 1C 24 fistpl). Исправление: снимать темп-слот (add $8,%rsp) до push
результата, либо писать fistpl сразу в аргументный слот.

## КОРЕНЬ НАЙДЕН И ИСПРАВЛЕН (2026-08-19)

Грабля grep'а: *.odc.txt в .gitignore — Grep по каталогу их МОЛЧА пропускает;
искать с include_ignored=true или по конкретному файлу.

Точный дизасм caller'а (tools64/ocf.py dis Http.ocf 0x1C60):
```
1cc1: add $-8,%rsp        ; DecStack — слот под ENTIER
1cd8: fistpl (%rsp)       ; DB 1C 24: FISTP dword — значение Int32 на Stk
1cdc: movslq (%rsp),%rax  ; 48 63 04 24: LoadLong читает слот...
1ce0: push %rax           ; ...и пушит, НЕ сняв слот (нет add $8,%rsp)!
1ce2: call IntToString
```

Цепочка кодгена для `IntToString(SHORT(ENTIER(expr)), tmp)` (формал x: LONGINT):
1. Внутренняя конверсия в Int32 (ConvMove, m=Undef): `DecStack` + `fistpl`
   → значение Int32 лежит в Stk-слоте (это by design, Stk = временное на
   машстеке, потребляется через Pop/Load).
2. Внешняя конверсия Int32→Int64 формала: ConvMove CASE y.form=Int32,
   f=Int64 → `LoadLong(y)`. Ветка узких форм LoadLong делала
   `movsxd r64, [rsp]` БЕЗ освобождения слота — в отличие от Load/LoadW/
   LoadL, где x.mode=Stk идёт через Pop (pop снимает слот).
3. Хвост ConvMove (m=Stk): Push(y) → `push %rax`. Итого два слота вместо
   одного: сирота между x и adr(tmp) → callee читает s=NIL.

Фикс (Dev/Mod/CPCamd64.odc.txt, LoadLong, ELSE-ветка узких форм):
```oberon
IF x.mode = Stk THEN IncStack(x.form) END;	(* Stk-слот прочитан — освободить *)
```
после movsxd/movsx, до `x.mode := Reg`. Покрывает все 12 вызовов LoadLong.

Урок (аналогия с CompilerFwdRef64 «OUT-пар не инициализирован»): LoadLong —
это «потребитель» Stk, как Load/LoadW/LoadL, но контракт «прочитал Stk =
освободи слот» в нём был реализован только для Int64/Pointer-ветки (Pop),
а для узких форм — нет. Инвариант: любой путь, читающий x.mode=Stk,
обязан снять слот (Pop или IncStack после чтения).

Проверка: Probe49 (P(111, SHORT(ENTIER(r)), 333) — при баге b читается
из сироты =2 вместо 333), probes.sh, Paket Update в GUI.

## Как воспроизвести

GUI → Paket → Update package list (или вызов
Strings.IntToString(SHORT(ENTIER(rx)), buf) при любом rx из метода).
В консоли НЕ воспроизводится: Paket качает через Services actions, которые
между командами консоли не качаются.

## Проверка после фикса

- Probe41 (HTTP GET) + Paket Update в GUI.
- Минимальная прoba: процедура с двумя параметрами, первый —
  SHORT(ENTIER(...)) — проверить оба значения внутри.

## Смежные открытые

- Консольный frame-walker при HALT-трапах спамит ~IsReadable и падает
  (reentrant SEGV вне isReadable-контекста). GUI-путь ок.
- Старт GUI: спорадические HALT (StdDocuments+0x2f13, Strings+0x120) —
  после фикса ENTIER перепроверить, может быть тем же корнем
  (IntToString(SHORT(ENTIER)) в статус-баре/документах).
