# Findings: диагноз и история проблем (64-bit port)

## Корневой диагноз

Прошлая попытка порта failed потому что компилятор (DevCPE+CPLamd64, processor=12)
эмитировал дескрипторы в 32-битной раскладке (4-байтные слоты указателей с
fixup-метаданными), а Kernel64 объявляет 64-битные CP-записи. Загрузчик не мог это
починить → хаки (сканирование кода, goto skip_exports_64_mod, RegisterModule через
отдельный Module вместо dad). Лечится в эмиттере, не в лоадере.

Пользователь: 32-битные принципы сохранить, обратная совместимость не нужна,
<4 ГБ не ограничивать.

## Решённые проблемы

1. **PointerSize=4 const в DevCPM** — раскладка типов 32-битная. Решение:
   CPT.PtrSz()/ProcSz() (не экспортированы, по processor=12 → 8); CPVamd64: 8.
   DevCPM НЕ трогаем (packed в dev0; VAR ломает packed-совместимость).
2. **Packed-модули dev0 затеняют Code** — правки CPE/CPT не действовали. Решение:
   repack dev0Linux без модулей компилятора (tools64/repack-dev0.sh).
3. **Смешение 32/64 osf в одних Sym/** — "not consistently imported". Решение:
   bbcp64use (изолированные Sym/Code). bbcp64use/Dev НЕ создавать.
4. **Коллизии MODULE-имён** — Kernel64×4 файла, LinKernel64 затирал Kernel64.
   Решение: bbcp/Mod64/ + аккуратные симлинки в use64.
5. **ETXTBSY при repack** — pack выполнять из-под blackboxInterpLinux, не dev0.
6. **Bugs codegen**: imm64 4-байтный слот, moffs64, case-таблица abs32 —
   исправлено в CPLamd64 (8-байтные слоты; case: mov r11,imm64 + jmp [r11+idx*8]).
7. **CP-синтаксис**: forward-decl нет (объявлять до использования), ORD(BOOLEAN) —
   нельзя, SHORTCHAR vs CHAR несовместимы, поля с "-" read-only.

## Открытая проблема: fingerprint instability — РЕШЕНА (2026-07-22)

Симптом: "X is not consistently imported" (error 249) при чистой сборке System.
Причина: **32-битный osf fallback**. При компиляции 64-бит в bbcp64use, если osf
подсистемы (Std, Text) не собрана 64-бит, читается 32-битный osf из bbcp;
встроенные в него fingerprint типов (pvfp = size/align/fld.adr/hidden ptrs)
32-битной раскладки конфликтуют с 64-битными копиями в свежих osf.
Controls → StdCFrames (Std); StdDialog → TextModels/TextViews (Text).
Решение: всегда компилировать ПОЛНЫЙ список подсистем:
`tools64/test64.sh "System Std Text Form"` (83 модуля, 0 ошибок).
Диагностика: DbgTyp/OLD/NEW в DevCPT (убрать после стабилизации).
Урок: pvfp рекорда включает typ.size, typ.align, typ.n и адреса полей →
любое смешение 32/64 osf в одном дереве фатально.

## Calling convention amd64 v2 (реализовано, KERNEL OK)
- ParOff=16 ([rbp]=saved rbp, [rbp+8]=ret, params @rbp+16); слоты параметров 8 байт;
  VarPar record = 16 ([tag][adr]); DynArr = [adr8][len4...] (ArrDOffs=8).
- Enter/Exit: imVar slot 8 (BX), isCallback 16 (DI,SI — у всех XProc), guarded 48
  (ОТЛОЖЕНО: exception frame fs:0 32-битный, нужен amd64 redesign TLS).
- ret N = padr - 16. Push Int64 = один qword. heap tag at obj-8.
- RIP-relative disp32: immLen = typ-106 (trailing bytes после disp: lea/mov/call=0,
  imm8=1, imm16=2, imm32=4) — CPLamd64.ripTrail.

## Что подтверждено работать

- Формат OCF v2 эмитируется правильно (Kernel64.ocf: ModDesc 8-байтные слоты,
  sentinel 11223344, name@152 — hex-проверка 2026-07-22).
- Быстрый цикл правок: sync-odc + go32/go64 (DevOnce) — секунды на модуль.
