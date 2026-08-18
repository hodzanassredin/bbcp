# Порт подсистемы Comm на 64 бита (2026-08-18)

Comm (CommStreams + CommTCP + CommV24 + ObxStreams*) вошла в 64-битный мир.
Проба ObxProbe40.Go: TCP loopback listener/connect/accept/send/recv 8 байт +
проверка LocalAdr/RemoteAdr — OK. probes 23/23.

## Что было сломано в LinNet (главная находка)

`Lin/Mod/Net.odc` компилировался в мир из оригинального i386-источника без
аудита (не было .odc.txt). Критичные 32-битные типы:

- `PtrVoid = INTEGER` — усечение указателей (буферы recv/send, optval).
- `time_t/suseconds_t = INTEGER` — `timeval` был 8 байт вместо 16: `select`
  писал 16 байт в 8-байтовый рекорд -> порча стека. **Латентная бомба**,
  сработала бы при первом реальном select.
- `size_t/ssize_t/nfds_t = INTEGER` — неверная ширина для LP64.
- `sockaddr_storage.__ss_align = INTEGER` — смещение 4 вместо 8.

Фикс — по образцу уже портированного LinLibc: все указательные/размерные
типы = LONGINT (LP64). `socklen_t/in_addr_t` остаются INTEGER (32 бита и в
amd64 ABI). `addrinfo`: 5xINTEGER + паддинг + 3 указателя — CP-компилятор
даёт те же смещения, что C (ai_addr @24, canonname @32, next @40, SIZE=48).

LinIoctl и LinTermios проверены — корректны как есть (ioctl int*, termios
60 байт идентичен i386/amd64).

## Правки Comm

- `CommTCP__Lin`: `SHORT(Net.send/recv(...))` — ssize_t теперь LONGINT,
  OUT-параметры интерфейса CommStreams остаются INTEGER (err 113).
- Остальное (Streams/TCP/V24/V24__Lin/Obx*) — чистый CP, без правок.
- `fd_set` как ARRAY 32 OF SET и FD_SET(fd DIV 32) — корректно и на 64 битах:
  little-endian бит-нумерация fd_set на уровне байт одинакова для 32/64.

## Инфраструктура

- `mkworld64.sh`: Comm добавлена в список подсистем мира.
- `test64.sh`: `CompileSubs @Lin ...` — фильтр платформенных вариантов
  (`__Lin` компилируется, `__Win/__Fbsd/__Nbsd/__Obsd` пропускаются).
  Без @ попытка собрать Comm обваливалась на чужих вариантах.
- `sync-odc.sh`: glob заменён на `"$BB"/Mod64/*.odc.txt "$BB"/*/Mod/*.odc.txt`
  — раньше список подсистем был захардкожен и Comm (и любая новая подсистема)
  молча не синхронизировалась ("nothing to sync" при правках).
- `probes.sh`: добавлена Probe40.Go.

## Ловушки CP, всплывшие на пробе

- `out[i] := 41H + i` — INTEGER не присваивается BYTE: `SYSTEM.VAL(BYTE, ...)`.
- Строковый литерал и строковая CONST не индексируются (`pfx[i]` — err 79):
  копировать в VAR-массив и сравнивать строки целиком.
- `accept`ed stream.RemoteAdr() — это адрес КЛИЕНТА (эфемерный порт), а не
  адрес listener'а. LocalAdr() listener'а — свой bind-адрес.

## Ожидаемый шум test64 (не баги)

В основном проходе CompileSubs падают LinIntInit (err 152: Cons* ещё не
собраны — добирается отдельным DevOnce после Cons) и ObxCompileLog
(err 152: DevCP* sym спрятаны — добирается build-dev64.sh в конце).
Итоговая строка "failed = 3 of 243" с этими двумя — норма.
