# ОТКРЫТЫЙ БАГ: ENTIER в аргументах вызова — сирота-слот на стеке (2026-08-19)

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
