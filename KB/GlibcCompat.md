# Совместимость bbrun64 со старыми glibc (2026-08-18)

Симптом у пользователя (Ubuntu 22.04, glibc 2.35):
`bbrun64: /lib/x86_64-linux-gnu/libc.so.6: version 'GLIBC_2.38' not found`.

## Причина

Коммиченный бинарь собирался на хосте с glibc 2.39. В glibc >= 2.38 хедеры
при `-D_GNU_SOURCE` (он у нас в CFLAGS) включают `__GLIBC_USE_C2X_STRTOL`
и перенаправляют `strtoull` -> `__isoc23_strtoull` (asm-редирект, -std=c99
НЕ спасает: _GNU_SOURCE включает _ISOC2X_SOURCE вне зависимости от -std).

## Фикс

strtoull был нужен ровно в одном месте (разбор BB_ARENA_BASE) — заменён на
свой разборщик hex/dec (`parse_ull` в bbrun64.c). Итоговые версии символов:
2.2.5 / 2.4 / 2.34 -> бинарь из репо работает на glibc >= 2.34.

GLIBC_2.34 (__libc_start_main, dlopen и др. — слияние libdl в libc) флагами
с хоста 2.39 не срезать: версии приходят из libc.so.6 линковщика. Для более
старых дистрибутивов — локальная пересборка: `make -C Dev/Rsrc -f Makefile64`
(нужен только gcc). Это задокументировано в QUICKSTART64.md, раздел 2.

Правило на будущее: в bbrun64.c не использовать strto*-функции (isoc23
редирект); проверка после сборки:
`objdump -T Dev/Rsrc/bbrun64 | grep -oP 'GLIBC_[0-9.]+' | sort -Vu`

Заодно из git удалены протухшие отладочные бинарники (bbrun64_clean/dbg/
debug/g/test, bbrun64.c.bak). Платформенные img (exeFreeBSD/NetBSD/OpenBSD)
НЕ тронуты — их нечем пересобрать на этом хосте.
