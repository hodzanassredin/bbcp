# Выравнивание записей: pack-4 конвенция OCF vs C-ABI (2026-08-18)

## Итоговое правило (после двух заходов)

- **Дефолт компилятора — pack-4** (выравнивание полей максимум по 4). Это
  конвенция, на которой построен весь OCF v2: метаданные (Directory/Object/
  Signature/Module) читаются VAL-оверлеями CP-записей поверх файловых байтов,
  а bbrun64.c держит те же раскладки packed-структурами с _Static_assert.
  Менять дефолт НЕЛЬЗЯ: массив 8-выравниваемых элементов после 4-байтного
  поля (Directory.obj) невыразим инвариантно, а атрибуты не комбинируются
  ([untagged, align4] — ошибка: sysflag один).
- **C-ABI записи** (биндинги .so), где 8-байтное поле (указатель/LONGINT)
  идёт после не-8-кратного смещения, помечаются **`RECORD [align8]`**.
  sysflag>0 сам по себе даёт untagged, так что [align8] заменяет [untagged].
  Либо — явные pad-поля, как уже сделано в LinLibc (sigaction_t.pad0,
  stack_t.pad0): pads делают раскладку инвариантной к правилу вообще.
- Первый заход (дефолт 8) сломал ВЕСЬ мир: "command Install not found in
  FormControllers" (Kernel.ThisObject бинарным поиском по export.obj[] читал
  со stride/offset нового правила, файл — старого) + hang в poll на старте.

## История бага

getaddrinfo-путь (Paket HTTP): glibc пишет addrinfo.ai_addr по @24
(5×int + 4 паддинг), CP читал по @20 → мусорный указатель → SEGV.
127.0.0.1 (без DNS) работало — маскировка. Поймано дизассемблированием окна
$rip в gdb: `mov rax,[rax+0x14]` при ожидаемом @24.

## Пробы

- Probe43: getaddrinfo("localhost") + deref ai_addr (ip=127.0) — ловил баг.
- Probe41: полный HTTP GET blackbox.oberon.org/list (26 КБ) — end-to-end.
- Probe44: сужающее копирование SHORT(wide$) — не причём, но оставлено.
- Probe45: connect по имени "localhost" (loopback + getaddrinfo).

## BootInfo (побочная находка)

bbrun64.c писал Kernel.BootInfo по смещениям pack-4 (argv@12). Поля BootInfo
переставлены в rule-инвариантный порядок: modList@0, argv@8, argc@16 —
одинаково при любом alignLimit. **Правило: если C пишет CP-запись руками,
поля заказывать так, чтобы паддинга не было ни при каком правиле.**

## Конвенция для FFI (дополняет SoBindings.md)

1. Записи под C-структуры: сначала свернуть раскладку с заголовком
   (`gcc -fdump-record-layouts` или offsetof-проба), расставить явные pads
   (как в LinLibc) ИЛИ пометить [align8].
2. Проверять чтение ПОСЛЕДНИХ полей, не только первых (Probe43 v1 читал
   ai_family@4 и был "зелёный" при битом ai_addr@24).
3. Non-blocking connect: первые write/read = EAGAIN — ретраить.
