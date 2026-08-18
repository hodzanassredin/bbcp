# Подсистема Cuda — биндинги внешних .so (2026-08-18)

Образец для привязки внешних shared-библиотек к BB64. Сделано по мотивам
Json (bbcb2, C-библиотека + CHook) и LinGtk2* (чистые интерфейсные модули).

## Механизм

- `MODULE CudaRt ["libcudart.so.12"]` — атрибут библиотеки в заголовке.
  Загрузчик (bbrun64 LoadDll/ThisDllObj) при загрузке модуля делает
  `dlopen(lib, RTLD_LAZY+RTLD_GLOBAL)` и для каждой [ccall]-процедуры
  `dlsym(handle, name)`. Библиотека не найдена → модуль не грузится
  (в GUI — "code file not found", в консоли загрузчика — сообщение).
- Без атрибута [ccall]-объявление тоже возможно: символ ищется в глобальной
  таблице (нужен предварительный dlopen с RTLD_GLOBAL из чужого модуля —
  так LinGui открывает GTK, а LinGtk2Util биндится без атрибута).
- [ccall]-процедура С ТЕЛОМ в обычном модуле — это колбэк C→BB
  (LinBackends Signal-обработчики), не путать с биндингом.

## Правила (набитые грабли, все с ошибками компилятора)

1. В модуле С атрибутом библиотеки разрешены ТОЛЬКО [ccall]-объявления
   без тел. Процедура с телом там → странные ошибки (err 38 "BEGIN or END
   missing", err 124 у RETURN). Обёртки — в соседнем модуле без атрибута
   (CudaUtil; прецедент: LinGtk2Util vs LinGtk2Gtk).
2. [ccall] без атрибута библиотеки и без тела → err 225/48.
3. Адрес данных динамического массива: `SYSTEM.ADR(a[0])`.
   `SYSTEM.VAL(LONGINT, a)` даёт указатель на ХЕДЕР (last-поле блока);
   данные на +28 байт (headSize=4*nofdim+24, KB/ArrayHeader64.md).
   Симптом нашего бага: round-trip копирования "терял" ровно последние
   28 байт буфера любого размера (4096/65536/1МБ) — копировался хедер
   вместо хвоста данных.
4. NEW для POINTER TO ARRAY [untagged] запрещён (err 138). Буфер под
   C-структуру — локальный `VAR buf: ARRAY N OF SHORTCHAR` + параметр
   `VAR x: ARRAY [untagged] OF SHORTCHAR` в биндинге.
5. Нуль-литерал для SHORTCHAR — `0X` (как в LinFiles); `0S` НЕ существует
   (err 113 incompatible assignment).
6. cudaError_t/enums = INTEGER, size_t/указатели = LONGINT,
   cudaDeviceProp — буфер 4096 байт (поле name[256] всегда первое).

## Файлы

- `Cuda/Mod/Rt.odc.txt` — CudaRt ["libcudart.so.12"]: 16 биндингов
  (device/version/malloc/free/memcpy/memset/memGetInfo/sync/errors).
- `Cuda/Mod/Util.odc.txt` — CudaUtil: ErrorText, DeviceName.
- `Cuda/Mod/Test.odc.txt` — CudaTest.Go: версии, список GPU,
  round-trip H2D/D2H для 4КБ/64КБ/1МБ с проверкой паттерна.
- Интеграция: mkworld64.sh (подсистема Cuda), sync-odc.sh (Cuda/Mod),
  go64.sh (префикс Cuda*), test64.sh (доборка Cuda после Fig),
  probes.sh (CudaTest.Go в ALL; поддержка полных имён с точкой).

## Результат (RTX 5070 Ti + 5060 Ti, CUDA 12.0 runtime / 13.0 driver)

```
cuda runtime=12.0 driver=13.0
devices=2
dev0: NVIDIA GeForce RTX 5070 Ti
mem free=13435MB total=15817MB
CudaTest OK
```
