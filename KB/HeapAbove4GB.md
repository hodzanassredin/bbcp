# Куча выше 4 ГБ: снятие MAP_32BIT (аудит B1-B5, 2026-08-17)

Цель: GC-куча BlackBox может расти выше 4 ГБ. Модульная память (код, дескрипторы
типов, meta-арена) НАМЕРЕННО остаётся MAP_32BIT (< 4 ГБ): codegen использует
RIP-relative адресацию и 32-битные теги типов — см. CPB (TYP остаётся Int32,
ADR = Int64 при processor=12).

## Каталог правок (System/Mod/Kernel.odc.txt, Lin/Mod/Kernel.odc.txt, Std/Mod/{Debug,Menus}.odc.txt)

- **B1. NewRec/NewArr: INTEGER → LONGINT.** Результат NEW возвращался из EAX,
  верх RAX обнулялся → любой объект выше 4 ГБ терял старшие 32 бита адреса.
  Сигнатуры `NewRec*/NewArr* (…): LONGINT`; codegen для Int64-результата пишет
  полный `mov rax`, компилятор не трогали. Также `Allocated*/Used*/Root* (): LONGINT`
  и счётчики `allocated/used/ttotal: LONGINT`.
- **B2. Mark: free-блок по точному инварианту.** Раньше free-блок распознавался
  по усечённому до INTEGER тегу `InHeap(dt)` — при куче > 4 ГБ усечение ломает
  проверку. Теперь: `ft := S.VAL(LONGINT, this.tag); DEC(ft, ft MOD 4);
  IF (ft > 0) & (ft # S.ADR(this.last))` — инвариант free: `tag = ADR(block.last)`
  (так же делает CheckCandidates). ВНИМАНИЕ: это читает тег 8-байтным чтением —
  **32-битная сборка Kernel из этого источника сломана** (в 32 бит tag 4 байта,
  S.VAL(LONGINT, tag) захватит соседнее поле). 32-бит legacy выброшен осознанно;
  dev0 ходит на СТАРОМ 32-бит Kernel.ocf, не пересобирать его из этого источника.
  Убраны `SHORT(S.ADR(this.last))` → `S.ADR(this.last)` (2 места).
- **B3. [code] Next: 32-битные mov → 64-битные.** `MOV ECX,[EAX]` читал тег
  32-битно и складывал указатели в EAX. Переписан на RCX/RAX (см. байты в коде);
  поле size остаётся INTEGER — читается 32-битным `mov ecx,[rcx]` с zero-extend.
- **B4. LONGINT-сравнения кластеров.** MakeFreeMulticluster сортирует цепочку
  кластеров по адресу (`S.VAL(LONGINT, new) < S.VAL(LONGINT, root)` и т.п.);
  Sweep: dealloc-check `S.VAL(LONGINT, fblk) = S.VAL(LONGINT, cluster) + 24`,
  `INC(allocated, LONGINT-разность)`, `Insert(fblk, SHORT(разность))`.
- **B5. LastBlock(limit: LONGINT)** + вызовы `S.VAL(LONGINT, root) + a`
  (mono-only, на Linux не ходится, но исправлено для консистентности).
- LinKernel AllocateClusterMem: убран MAP_32BIT и оба SHORT у mmap.
- StdDebug: 2 места `S.VAL(INTEGER, c)` → LONGINT при сравнении кластеров.
- StdMenus.UpdateMetrics: alloc/used LONGINT, AppendInt(n: LONGINT).

## Инварианты layout (64 бит)

- FreeDesc: tag@0 (Type), size@8 (INTEGER), next@16; free-инвариант
  `blk.tag = ADR(blk.size) = ADR(block.last)`.
- Block: tag@0, last@8, actual@16, first@24 (LONGINT).
- Cluster: size INTEGER (кластер < 2 ГБ, ASSERT 61 в AllocateCluster),
  next, max LONGINT. ADDRESS = LONGINT (Kernel:164).
- physicalMemory: INTEGER в Platform — НЕ тронут (mono-only; Linux multicluster).

## Ловушка диагностики: позиции ошибок компилятора

err 111 «operand inapplicable» сообщал pos внутри MakeFreeMulticluster, а реальная
ошибка была в ПРЕДЫДУЩЕЙ процедуре MakeFreeMonocluster: `LONG(allocated)` после
смены allocated на LONGINT (LONG(Int64) неприменим). Компилятор сообщает позицию
сканера на момент детекции (конец процедуры + lookahead), НЕ позицию конструкции.
Метод: бисекция удалением операторов — если pos не сдвинулся после удаления
строки, ошибка РАНЬШЕ неё. errpos.sh даёт только нижнюю оценку района.

## Проверка

Probe35 (Obx/Mod/Probe35.odc.txt): 80 кусков × 64 МБ = 5 ГБ, touch каждой
страницы, полный Kernel.Collect на живой куче, проверка данных, освобождение
половины → Used уменьшается, ре-аллокация, полное освобождение.

## Вскрытые латентные баги кодгена (проявились только с кучей > 4 ГБ)

После снятия MAP_32BIT кластеры mmap ложатся ~0x7ffff6... — адреса сразу выше
4 ГБ, и скрытые 32-битные усечения в кодогенерации стали фатальными:

1. **CPCamd64.Param (ccall, ~1660)**: для Int64-фомала ветка `ap.mode = Reg`
   проверяла `ap.form = Int64`. ADR-узел имеет form=Pointer (CPLamd64 GenMove
   коерсит `to.form = Pointer`), поэтому шёл movsxd-путь → знаковое расширение
   младших 32 бит адреса. `LinFiles: fread(SYSTEM.ADR(buf.data),...)` →
   buf=0xFFFFFFFFF698B9B0 → SIGSEGV на init LinPackedFiles. Фикс: ветка
   `{Int64, Pointer, ProcTyp, Real64}` → полный push r64 (и Reg, и mem-ветка).
2. **CPLamd64.GenComp (~686)**: NIL-тест `p = 0` на регистре генерил
   `or eax,eax` без REXW для form=Pointer. 32-битная запись в eax ОБНУЛЯЕТ
   старшие 32 бита rax → после `call Kernel.NewArr` (результат полный 64-бит)
   caller терял верх адреса → `mov [rax+18H]` по усечённому адресу, SIGSEGV на
   init Integers. Фикс: REXW для `{Int64, Pointer, ProcTyp}` (идиома остального
   файла: `Size[form] >= 8` / сет из трёх форм — GenComp был единственным
   пропущенным местом).

Диагностический приём: gdb -batch -ex run (запуск дочерним процессом —
ptrace_scope=1 не мешает), на SIGSEGV `x/i $pc`, дизассемблирование caller'а
по PC из bt (модуль = по таблице cad из лога бута). Паттерн усечения:
0xFFFFFFFFxxxxxxxx = movsxd (знак), 0x00000000xxxxxxxx = or eax,eax / mov eax
(ноль). Оба класса надо искать по `form = Int64` в CPLamd64/CPCamd64 —
арифметика (Neg/Not/Mul/сдвиги) Pointer не получает легально, трогать не надо.

Probe36 (run): ptr=VAL(LONGINT,p) vs ADR(p[0]) равенство. Probe37/38 (compile-
only, дизасм ocf): fread(ADR(buf[0])) без movsxd; через локальную LONGINT —
было чисто и до фикса (обходной путь).

3. **CPLamd64.GenMove/GenConOp: NIL как 32-битный ноль.** NIL-константа несёт
   form=NilTyp (CPVamd64:1182), Size[NilTyp]=8, но CheckSize(NilTyp) даёт
   32-битный опкод и сеты `{Int64,Pointer,ProcTyp}` её не покрывали:
   - `p := NIL` в mem-слот (локал/поле) → `movl $0, [slot]` занулял только
     младшие 4 байта → при чтении qword получался 0x00007fff00000000
     (верх от старого значения) → SIGSEGV на init StdLog (Stores: res:=NIL
     после 64-битного стора в тот же слот).
   - `IF p = NIL` по mem → 32-битный cmp читал только младшие 4 байта
     (ложное равенство при адресе вида 0xXXXXXXXX00000000 — редко, но реально).
   Фикс: в GenMove Con-ветке и GenConOp коерсия `from.form := Pointer` для
   NilTyp ДО выбора пути (GenConst для NilTyp пишет только imm32 — нельзя
   просто добавить NilTyp в сет, нужна именно коерсия формы).

### Баг кодгена №4: MakeConst не инициализирует Item.scale (hi32 imm64)
Симптом: бут падает в Kernel.NewBlock, b = 0xF1B390C000000000 (мусорный верх
+ нулевой низ). Дизасм GetOldFreeBlock: `movabs $0xF1B390C000000000,%r11;
mov %r11,slot` — "NIL" с мусором в старших 4 байтах.
Корень: `CPLamd64.MakeConst` (~line 116) ставит `x.offset := val`, но НЕ
трогает `x.scale` (мусор стека). До коерсии NilTyp->Pointer (баг №3) NIL
эмитился как imm32 (GenConst: только x.offset) — scale не читался. После
коерсии GenConst для {Int64, Pointer, ProcTyp} эмитит `GenDbl(offset);
GenDbl(scale)` — и мусор пошёл в код.
Фикс: `x.scale := ASH(val, -31)` в MakeConst (знак-расширение; для NIL=0 даёт 0).
AllocConst уже ставил `x.scale := 0` — поэтому баг кусал только Con-константы.
УРОК: любая новая ветка, читающая ранее "мертвое" поле Item, должна
сопровождаться аудитом ВСЕХ конструкторов Item (MakeConst/AllocConst/...).
Проверка: `ocf.py bytes Kernel.ocf 0x4a86 10` -> `49 bb 00*8` (movabs $0);
поиск байт c0 90 b3 f1 по ocf -> не найдено. Бут доходит до конца.
