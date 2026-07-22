# Порт BlackBox на 64 бита (bbcp) — журнал работ

Цель: завершить перенос системы с 32 на 64 бита. Компилятор работает, GUI — нет.
Загрузчик: `Dev/Rsrc/bbrun64.c`. Эталоны: 32-битный `Dev/Rsrc/bbrun.c` (принципы),
`Hr/Mod/Ocf.odc.txt` + `Hr/Mod/E.odc.txt` (как правильно сделан 64-битный формат).

## Диагноз (коренная причина провала прошлой попытки)

Компилятор bbcp (DevCPE + DevCPLamd64, processor=12) генерирует OCF с **32-битной
раскладкой дескрипторов**: все указательные поля (ModDesc.code/data/refs/...,
Type.mod/base/fields, Object.ostruct, import-таблица, proc-таблица, method-таблица)
— 4-байтные слоты с fixup-метаданными (typ*1000000H + linkadr24).

А runtime-записи в Kernel64 (CP-записи Module/Type) — 64-битные (8-байтные указатели).
Файловый ModDesc НЕ совпадает с Kernel64.Module ни по смещениям, ни по размерам.
Загрузчик не может это починить точечно — отсюда бесконечные хаки (эвристическое
сканирование кода в поиске fixup-метаданных, goto skip_exports_64_mod и т.п.).

**Вывод: чинить надо источник — эмиттер компилятора (DevCPE), а не загрузчик.**
Пользователь подтвердил: не рассчитывать на <4 ГБ, наследовать принципы 32-битной
версии, 64-битный дизайн исправить как надо.

## Установленные факты

### Формат файла (Dev OCF, пишет DevCPE.OutHeader/OutCode)
```
ObjFile = HeaderBlk MetaBlk DescBlk CodeBlk FixBlk UseBlk
```
- HeaderBlk: tag(4)=0x6F4F4346 processor(4)=12 hs ms ds cs vs (по 4),
  nofImports(RNum), name(utf8,0), имена импортов, Align(16). hs = headSize.
- ms = modPos - headSize (MetaBlk: refs, export, ptrs, import-таблица, names, consts)
- ds = codePos - modPos (DescBlk: ModDesc + ProcTable + дескрипторы типов)
- cs = pc (CodeBlk), vs = dsize (данные; в файле НЕ хранятся, только аллоцируются)
- FixBlk сразу после CodeBlk; 6 групп (CPE.odc.txt:1036-1055):
  1. KNewRec.links  2. KNewArr.links
  3. meta: Const8/16/32/64.links + Meta.links
  4. desc: тип-дескрипторы links + [pVarInd: Proc.links, CPLinks] + Mod.links
  5. code: [~pVarInd: CLinks] + CaseLinks + Code.links
  6. data: Data.links
  Каждая группа: пары RNum(head) RNum(offset)..., терминатор 0X.
- UseBlk (CPE.odc.txt:887-911): per-import: байты типа (mTyp=2/mVar=3/mProc=4) +
  name + RNum(fprint) + OutLink(цепочка), терминатор 0X на импорт.
- Семантика цепочек (32-бит bbrun.c Fixup, строки 314-367): link>0 → code,
  link<0: |link|<ms → meta, иначе desc (|link|-ms). Слот 4 байта: typ*1000000H+next24.
- Типы фиксапов (CPLamd64:95-96): absolute=100 relative=101 copy=102 table=103
  tableend=104 short=105 ripBased=106 ripBased1=107 ripBased2=108 ripBased4=110
  ripBased8=114 (immLen = typ-106, disp = target-(ladr+4+immLen)).
- Hr (другой формат семейства!) использует absolute64=116: слот 8 байт
  (4 метаданных + 4 сторож 11223344H), патч = 8-байтная запись (Hr/E.odc.txt:74,569).

### Распарсенный Kernel64.ocf (проверено по hex)
- hs=0x30 ms=0x660 ds=0x458 cs=0xC4 vs=0x60; FixBlk начинается на hs+ms+ds+cs=0xBAC
  (НЕ +vs!). Первые два байта FixBlk = 00 00 (пустые newRec/newArr группы).
- ModDesc в файле: link(4) opts(4)=0x17d refcnt(4) ymdhms(12) loadtime(12) ext(4)
  term(4) nofimps(4)=0 nofptrs(4)=21 csize(4)=196 dsize(4)=96 rsize(4)=213
  code..export (9 слотов по 4 байта с метаданными 0x64xxxxxx) name "Kernel64".
- Kernel64.Module (CP, 64-бит): next@0(8) opts@8 refcnt@12 ext@16 termLo@20 termHi@24
  nofimps@28 nofptrs@32 csize@36 dsize@40 rsize@44 code@48(8) ... export@112(8)
  name@120(256). Смещение code=72 у HrOcf.ModDesc — другое поле (у него есть closeSection).
  bbrun64.c C-struct Module == Kernel64.Module (совпадают). Но файловый desc им НЕ
  соответствует.

### Тулчейн
- dev0Linux — 32-битный BlackBox (консольный), грузит модули из */Code.
- DevCompiler64 (Dev/Mod/Compiler64.odc) IMPORT DevCPV := DevCPVamd64 — кросс-компилятор
  в amd64. Проверено: `echo 'DevCompiler64.CompileSubs System' | ./run-dev0` работает,
  компилирует модули System (Kernel64 — 7 ошибок из-за выпиленного NewRec/NewArr).
- DevCPE общий для 32/64 (ветвиться по processor=12). CPLamd64/CPVamd64 — только 64.
- Правка компилятора: правим Dev/Mod/*.odc.txt → OdcText.Import → .odc →
  пересборка 32-битным DevCompiler под dev0 → DevCompiler64 компилирует систему.

### Найденные баги кодогенерации CPLamd64 (кроме формата)
1. GenCaseJump/CaseEntry (строки 861-893): jmp [reg*4+disp32abs] — 32-битный абсолют,
   записи таблицы 3-байтные + table/tableend fixup → сломается вне 4 ГБ.
   Решение: RIP-relative таблица (disp32 от базы таблицы) или 8-байтные записи.
2. `MOV r64, imm64` (0B8H+reg, строка 391): GenLinked пишет только 4 байта после B8 —
   обрезанный imm64. Нужен 8-байтный слот + absolute64.
3. 0A0H/0A2H (moffs64, строки 323,348): GenLinked 4 байта вместо 8.
4. procVarIndirect: в defopt НЕ включён (pVarInd=14) → прямые CALL E8 rel32
   (GenCall:897-905) — это хорошо, как в 32-бит. ProcTable в desc эмитируется всегда
   (Out2(4EF9H)+addr+Out2(0) по 8 байт на XProc) — для amd64 бесполезна, кандидат на
   удаление/замену.
5. Kernel64_full.odc (2381 строка, полный порт Kernel) — но Module.code/data/refs
   остались INTEGER (4 байта). Дорабатывать до ADDRESS.

### Что было сломано в bbrun64.c (прошлая сессия)
- goto skip_exports_64_mod: пропуск fixup/import; эвристические сканеры кода в main.
- fread(var) из файла (VarBlk в файле нет) и 2 лишние/перепутанные группы.
- Fixup писал *(intptr_t*) = 8 байт в 4-байтные слоты (затирание соседних полей).
- RegisterModule создавал отдельный Module вместо dad (32-бит принцип: dad==Module).

## РЕШЕНИЕ: спецификация OCF-amd64 v2 (Dev-семейство, 8-байтные указатели)

Принципы из 32-бит: 6 групп FixBlk, UseBlk с цепочками, dad == Module, Fixup(adr)
для импортов. Изменения только в разрядности указательных слотов:

1. Все указательные слоты в Meta/Desc — 8 байт: 4 метаданных + 4 сторож (11223344H).
   Fixup-тип absolute64=116, патч: *(uint64*)slot = adr + offset.
   Затронуто: OutReference (Mod/типы/methods/proc-entries/struct refs в meta),
   OutModDesc (code..export — 9 полей), OutObject.ostruct, import-таблица (impPos:
   по 8 байт на импорт), method-таблица (8 байт на метод, маркер -1 → 8 байт?),
   copy-fixup смещения -4-4*i → -8-8*i.
2. ModDesc (amd64) = CP-запись Kernel64.Module:
   next(8) opts(4) refcnt(4) compTime(6) loadTime(6) ext(4) pad(4) term(8)
   nofimps(4) nofptrs(4) csize(4) dsize(4) rsize(4) pad(4)
   code(8) data(8) refs(8) procBase(8) varBase(8) names(8) ptrs(8) imports(8) export(8)
   name(256). Выравнивание 8/16.
3. Type descriptor (record): methods (по 8), затем desc@: size(4) mod(8) id(4)
   base[16](по 8) fields(8) ptroffs(по 4, оффсеты, -1 окончание) — == Kernel64.Type.
4. Export Directory: num(4); записи: fprint(4) offs(4) id(4) pad(4) ostruct(8) = 24.
5. Код: RIP-relative (ripBased*) и relative — без изменений; disp32 ограничивает
   код↔данные и межмодульные CALL ±2 ГБ → загрузчик аллоцирует все блоки в одной
   арене (один большой mmap, подраздача) — локальность, а не ограничение 4 ГБ.
6. Case-таблицы: переделать на RIP-relative (без table/tableend для amd64).
7. imm64 в коде (B8+r, A0/A2): 8-байтные слоты + absolute64 (в code-группе).
8. Kernel64: полный порт из Kernel64_full с ADDRESS-полями; вернуть NewRec/NewArr.

## План по стадиям
- A. Компилятор: DevCPE (8-байтные слоты, ModDesc/Type/Export раскладки) +
  CPLamd64 (case-таблица, imm64). Ветвление по processor=12. Проверка hex-дампом.
- B. Загрузчик bbrun64.c: переписать начисто по bbrun.c (6 групп, UseBlk, dad==Module,
  арена, mprotect). Тест на Kernel64.ocf.
- C. Kernel64 полный (ADDRESS-поля, NewRec/NewArr, GC) — загрузка 91 модуля.
- D. LinInit/GUI.

## Лог проб
- 2026-07-22: dev0 + DevCompiler64.CompileSubs System — компилирует (Kernel64: 7 ошибок
  из-за выпиленных NewRec/NewArr в рабочем дереве). Hex-анализ Kernel64.ocf подтвердил
  32-битную раскладку desc → диагноз.

## Промежуточные итоги (2026-07-22, сессия 2)

### Сделано
- Правки компилятора (стадия A): CPE (8-байтные слоты, ModDesc/Type/Export v2,
  import-таблица 8 байт, ProcTable пропущена), CPLamd64 (imm64/moffs64, case-таблица
  mov r11,imm64 + jmp [r11+idx*8], записи 8 байт), CPCamd64 (Tag0Offset=24,
  Mth0Offset=-8), CPVamd64 (pointer/proctyp=8, align 8, DynArr=12), CPT (PtrSz/ProcSz
  НЕ экспортированы — интерфейс не меняется).
- Инфраструктура:
  - `~/sources/bbcp64use` — изолированное дерево для 64-битных Sym/Code (симлинки на
    исходники + свои Sym/Code). БЕЗ поддерева Dev (иначе dev0 грузит 64-битный DevCPT!).
  - dev0Linux перепакован с правлеными модулями (link через DevLinker1.LinkElfExe,
    pack через DevPacker.PackThis, запуск pack ИЗ-ПОД run-BlackBoxInterp — нельзя писать
    в запущенный бинарь ETXTBSY).
  - `bbcp/Mod64/` — amd64-исходники (Kernel64, LinKernel64, Stores64); junk прежней
    сессии (Gui/KGui/Mini/Test2/SystemTestK) убран в /tmp/opencode/junk.
  - LogMarks в DevCompiler64 (печать позиций ошибок в консоль); pvfp/fprint диагностика
    в CPT (DevCPM.LogWStr/LogWNum).

### Найденные грабли (и решения)
1. **Packed-модули dev0 затеняют Code**: правки CPE/CPT не действовали, пока не
   перепаковали dev0Linux. НЕpacked: CPLamd64, CPCamd64, CPVamd64, Compiler64.
2. **Общие Sym/Code для 32/64** → "not consistently imported" от смешения fingerprint.
   Решение: отдельное дерево bbcp64use.
3. **Коллизии имён модулей**: Kernel64.odc/_gui/_orig/_full все = MODULE Kernel64;
   Lin/Mod/Kernel64.odc = LinKernel64 и ЗАТЁР System/Mod/Kernel64.odc в Mod64.
4. **CP-мелочи**: объявление до использования (3 ошибки), ORD(BOOLEAN) нельзя (2),
   SHORTCHAR vs CHAR в LogWStr (2), msg- read-only (1).
5. **.odc.txt не трекается git'ом частично** → после git checkout в .txt остались правки
   → дубликаты. Правило: источник истины = .odc.txt, .odc генерируется скриптом.

### Стадия B (загрузчик) — ПРОРЫВ 2026-07-23
- bbrun64.c переписан начисто (6 групп, UseBlk, dad==Module, арена 512MB RWX,
  directory scan + multi-pass import resolution). 119 модулей грузятся.
- Баг C: Directory.obj выравнивался на 8 (intptr_t), в файле записи на +4 → packed.
- Кодген: критические баги calling convention (всё было 32-битное):
  - `add esp` → REXW add rsp (GenConOp/GenDirOp/AdjustStack)
  - `inc/dec r32` (40-4F = REX!) → FF /0,/1
  - ripBased: trailing immLen=typ-106 (lea/mov/call=0, cmp imm8=1, imm16=2, imm32=4)
    через ripTrail в CPLamd64
  - фрейм: ParOff 8→16, слоты параметров 8 байт, Enter/Exit per-flag pops
    (imVar 8, isCallback 16, guarded 48 — guarded отложен, exception frame TODO),
    ret N = padr-16, Push(Int64) один qword, heap tag at obj-8,
    VarPar record tag at +8, DynArr len at +8
  - case-таблица: mov r11,imm64 + jmp [r11+idx*8], записи 8 байт (проверено дизасмом)
- **KERNEL OK**: Kernel64 body исполняется и возвращается (2026-07-23).
- LinInit body запускается, но завершает процесс молча (без MAIN OK) — дальше.
- LinKernel64 (Mod64): 6 ошибок источника (Kernel64.InitHeap/Cluster/monoCluster) —
  ждёт полный Kernel64 (стадия C).
- Lin/Code/IntInit.ocf не грузится: needs ConsFonts ConsWindows ConsLog (Cons
  subsystem не собран 64-бит; консольные модули — позже).
- Причина: компиляция 64-бит в use64 читала osf несобранных подсистем (Std, Text)
  из bbcp (32-бит) — встроенные fingerprint (pvfp: size/align/fld.adr/hidden ptrs)
  32-битной раскладки конфликтовали с 64-битными. Controls → StdCFrames (Std);
  StdDialog → TextModels (Text).
- Диагностика путей: OLD/NEW дампы полей (DbgTyp в CPT) показали 4-байтные offsets
  в OLD → 32-битный osf. Запуск CompileSubs с ПОЛНЫМ списком подсистем решает.
- Итог: `test64.sh "System Std Text Form"` — 83 модуля, 0 ошибок.
- Lin: 37 модулей ок; LinKernel64 (Mod64, минимальный) — 6 ошибок источника
  (Kernel64.InitHeap/Cluster/monoCluster — ждёт полный Kernel64, стадия C).
- Диагностику PVFP/FP249/DbgTyp/W в CPT убрать после стабилизации (TODO).

### Тулинг (приоритет перед продолжением)
- DevOnce (Go32/Go64): компиляция одиночных модулей по списку /tmp/compile1.txt.
- tools64/*.sh: sync-odc, go32/go64, test64, repack-dev0.
- dev0 без packed компилятора (CPE/CPT/etc грузятся из Code → правки без repack).
