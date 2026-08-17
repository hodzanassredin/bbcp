# Зависание при открытии Docu/Tut-2 (Compound Documents) — расследование

Статус на 2026-08-17 ~13:45: НЕ РЕШЕНО, механизм локализован, корень (раздувание
кластеров) не найден. Коммит состояния: 5a19d12f.

## Симптом

- GUI: Help → Contents работает; клик на ссылку «Compound Documents»
  (`StdCmds.OpenBrowser('Docu/Tut-2', ...)`) — окно зависает, CPU ~40-50%.
- Консольная репродукция ЕСТЬ (GUI не нужен!):
  `echo "StdCmds.OpenBrowser('Docu/Tut-2', 'x')" | BB_CONSOLE=1 BB_STANDARD_DIR=~/sources/bbcp64use timeout 30 ~/sources/bbcp/Dev/Rsrc/bbrun64 --console`
  → bbrun64 крутится на 99.9% CPU. `OpenBrowser('Docu/Tour')` — НЕ виснет
  (+60KB allocated, открывается мгновенно).
- На FPU-мире (до native Int64, коммит ≤14b0d8b7) ссылка работала.

## Механизм зависания (доказано gdb)

- Спин в `Kernel.InHeap` (System/Code/Kernel.ocf, proc span (0x3627,0x368c],
  цикл 0x3642-0x3680): `c := c.next` = `mov 0x4(%rax),%rax` (8-байтное чтение
  next по +4 — штатно, компилятор пакует указатели без 8-выравнивания),
  выход по `cmpl $0,-8(%rbp)` (младшие 32 бита c).
- Цепочка кластеров НЕ циклична (прогулка до 0), но ДЛИННА: ~1300 кластеров
  по 256KB (0x40000). Замеры: от 0x6c0c4000 → 136 до конца; от 0x63284000 →
  1127 до конца. Адреса кластеров 0x63..0x6f_xx_4000 (выше арены 0x40000000-
  0x60000000 — отдельные mmap через Platform.AllocateClusterMem).
- Стек вызовов: NewBlock → MakeFreeMulticluster → AllocateCluster →
  platform.AllocateClusterMem (LinKernel); GC: Collect → Mark → InHeap(dt)
  (Mark+0x21f, Kernel.odc.txt:1661) и InHeap(son-8) (:1689). InHeap O(n) на
  кандидата × тысячи кандидатов × 1300 кластеров ≈ квадрат/куб → «вечный» GC.
- RSS виснущего GUI 527MB (FPU-утренний GUI: 67MB) — но был и вис при RSS
  78MB: кластеры почти пустые, RSS не показатель; показатель — ЧИСЛО кластеров.

## Что исключено / проверено

- Kernel.Collect в консоли на свежем буте — мгновенно (GC сам по себе жив).
- Probe31 (~/sources/bbcp64use/Probe31.cp): печатает Kernel.Allocated()/Used()
  — работает; бут: allocated≈193024, used≈274432.
- LONGINT-арифметика верна (Probe24/27/28/29 самопроверяющиеся, 20/20 PASS).
- Цепочка next консистентна (size@0=0x40000, next@+4, max@+8=base).

## Гипотезы (по убыванию)

1. Free-list reuse сломан → каждый NewBlock при промахе делает новый кластер
   256KB (AllocateCluster(tsize+24)), остаток не переиспользуется. Подозреваемые
   места: Insert (Kernel.odc.txt ~1939: `blk.size := size-8`, bucket i=MIN(N-1,
   size DIV 16)), GetOldFreeBlock (~2061: sliver-правило `b.size - s = 16`),
   Next (~1738: stride=(size+23) DIV 16*16, min 32), Sweep (~1944: `end` LONGINT,
   VAL(INTEGER,...) усечения — кластеры пока < 4ГБ, безвредны).
2. Размер кластера 256KB слишком мелкий + аллокационный шторм при инстанцировании
   вложенных view (Tut-2 = глава про compound docs, в тексте формы/картинки).
3. Счётчики allocated/used (LONGINT) съезжают → эвристика роста кучи
   (`(tsize + LONG(allocated)) DIV 2 * 3`, Kernel.odc.txt:2114) врёт.

## План следующего захода (консоль, без GUI)

1. Инструментировать Kernel.NewBlock/AllocateCluster счётчиками/логом
   (каждый новый кластер: size, allocated, used) → консольный прогон
   OpenBrowser('Docu/Tut-2') покажет шторм аллокаций и его источник
   (размеры запросов).
2. Если шторм мелких запросов → смотреть, почему GetOldFreeBlock не находит
   остатки (дамп free[] бакетов до/после).
3. Минимизация триггера: Tut-1/Tut-3..., синтетический документ с одной
   вложенной формой (Obx формы через TextViews) — найти минимальный кейс.
4. Проверить FPU-билд на том же сценарии (откат компилятора на 14b0d8b7 →
   go32 → test64) — подтвердить, что регресс именно от native Int64.

## Техника отладки (важно!)

- ptrace_scope=1 → gdb не аттачится к чужим процессам. Решение: GUI под gdb
  с рождения через FIFO: `tools64/gdb-gui.sh`; команды: `echo 'bt' > /tmp/gdbin`;
  прерывание inferior: `kill -INT $(cat /tmp/inferior.pid)`. НЕ давать fifo EOF
  (gdb отвечает Y на quit!) — держит вечный писатель (fifo_holder.pid).
- bbrun64 печатает ~TRAP sig=.. pc=.. при SIGSEGV — `kill -SEGV <pid>` даёт pc
  спина. Маппинг pc → модуль: таблица `+ Mod dad=... cad=...` в логе бута
  (есть и в GUI-логе); дальше `ocf.py refs/dis <ocf> <off>`.
- Пользователь кликает UI САМ (без MCP-кликов); я только направляю.
- ~TRAP-цепочки после SIGSEGV — это каскад обработчика трапов (известная
  хрупкость), смотреть только ПЕРВУЮ строку (code=0/SI_USER = мой сигнал → pc
  спина; code=1 = настоящий SEGV).

## Дополнение (перед сжатием контекста)

Принятый подход — fail-fast инварианты (Дейкстра): не ловить hang, а трапать
в точке нарушения. Конкретные следующие шаги:
1. В Kernel.AllocateCluster (System/Mod/Kernel.odc.txt:772) добавить подсчёт
   цепочки root с капом: `c2 := root; n := 0; WHILE (c2 # NIL) & (n < 300) DO
   c2 := c2.next; INC(n) END; ASSERT(n < 300, 77)` + лог размера через
   BString/BInt/BLn (существуют, строки 631-663). НЕ добавлять глобалов в
   Kernel (раскладка varBase хрупкая: modList/root/baseStack вместе).
   Пересборка: `go64.sh Kernel` (интерфейс не меняется — каскада нет).
2. Консольный прогон OpenBrowser('Docu/Tut-2') → трап на 301-м кластере
   со стеком = источник шторма аллокаций.
3. A/B-доказательство (если надо): откат компилятора на 14b0d8b7 (go32 всех
   CP*) + test64 + тот же сценарий — подтвердить/снять регресс native Int64.
4. Кандидаты корня: Insert/GetOldFreeBlock/Next/Sweep (см. гипотезы выше).
