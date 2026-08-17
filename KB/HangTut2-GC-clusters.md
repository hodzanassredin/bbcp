# Зависание при открытии Docu/Tut-2 (Compound Documents) — РЕШЕНО

Статус на 2026-08-17 ~15:00: РЕШЕНО. Корень — sliver-shadowing в
Kernel.GetOldFreeBlock (наша же 64-битная поправка). Консольный OpenBrowser
('Docu/Tut-2') завершается, probes 20/20 PASS.

## Корень (доказан)

Бакеты free-листа = ТОЧНЫЕ классы размеров: blk.size всегда ≡ 8 (mod 16),
поэтому bucket i = size DIV 16 хранит ровно размер 16i+8. Оригинальный
GetOldFreeBlock сканирует только ОДИН непустой бакет — в оригинале это
корректно, т.к. первый же блок в нём заведомо ≥ s.

Наша 64-битная поправка (sliver-правило `b.size - s = 16` → skip) сломала
инвариант: sliver-блок в низком бакете (напр. size=40 в бакете 2 при s=24)
отвергался, скан НЕ шёл в старшие бакеты → промах при ЖИВОМ большом блоке в
бакете 7 → FastCollect/Collect на каждый промах (спин Mark→InHeap) →
MakeFreeMulticluster → новый кластер 256KB на каждый NewBlock(≤9 байт) →
цепочка 300..1300 кластеров → квадратичный GC = «вечное» зависание.
Поймано fail-fast'ом: дамп free[] на 301-м кластере показал bucket2=40,
bucket3=56, bucket7=41464 — классическая картина затенения.

## Фикс (System/Mod/Kernel.odc.txt, GetOldFreeBlock ~2073)

При отвержении блоков в бакете i ПЕРЕХОДИМ к бакету i+1 (внешний цикл по
бакетам), а не возвращаем NIL. Sliver-правило сохранено (a=16 нельзя ни
Insert, ни absorb — Next/Sweep его не перешагнёт). OldBlock (мёртвый код,
не зовётся) не тронут.

## Побочные находки

1. **Инструментация Гейзенберга**: НЕЛЬЗЯ логировать из AllocateCluster через
   BString/BInt — BAppend растит blog.buf через GrowBuf→NewBlock→(промах)→
   AllocateCluster → рекурсия-шторм (тысячи «AC req=» без чисел в логе).
   Живой лог только через blog.string/blog.ln (platform.String = libc,
   не аллоцирует). В Kernel.AllocateCluster оставлены неаллоцирующие
   LStr/LInt/LLn/LDump + fail-fast: цепочка > 300 кластеров → дамп free[]
   + HALT(77). Это постоянный инвариант, не снимать.
2. **GrowBuf баг округления** (Kernel.odc.txt:610): `len := (pos+by) +
   (logInc-1) DIV logInc * logInc` — DIV связывает не то: (logInc-1) DIV
   logInc = 0 → len = pos+by БЕЗ округления вверх. Каждый BAppend сверх
   ёмкости реаллоцирует впритык. Отдельный follow-up (не трогали).
3. **Трап-репортёр зацикливается** на битом fp-стеке: 437k одинаковых строк
   «0: Kernel. <PC=..>» при крахе во время GC. Нужен cycle-guard в
   LogThisStack/walker. Follow-up.
4. Таймауты: `timeout` без `-k` не добивает зависший bbrun64 (игнорит TERM
   в спине) — всегда `timeout -k 5 N`.
5. Остаточная «гроза» req=2136 при Tut-2 — НЕ баг: 41 кластер × 256KB для
   ~5000 объектов по 2KB (в логе только AllocateCluster, между ними ~124
   молчаливых NewBlock). Probe32 (3000 NEW по 2100 байт): 50 кластеров,
   dAlloc≈dUsed — reuse работает идеально.

## Симптом (историческая справка)

- GUI: Help → Contents работает; клик на ссылку «Compound Documents»
  (`StdCmds.OpenBrowser('Docu/Tut-2', ...)`) — окно зависало, CPU ~40-50%.
- Консольная репродукция:
  `echo "StdCmds.OpenBrowser('Docu/Tut-2', 'x')" | BB_CONSOLE=1 BB_STANDARD_DIR=~/sources/bbcp64use timeout -k 5 60 ~/sources/bbcp/Dev/Rsrc/bbrun64 --console`
- На FPU-мире (≤14b0d8b7) ссылка работала — sliver-правило появилось позже.

## Техника отладки (важно!)

- ptrace_scope=1 → gdb не аттачится к чужим процессам. Решение: GUI под gdb
  с рождения через FIFO: `tools64/gdb-gui.sh`; команды: `echo 'bt' > /tmp/gdbin`;
  прерывание inferior: `kill -INT $(cat /tmp/inferior.pid)`. НЕ давать fifo EOF
  (gdb отвечает Y на quit!) — держит вечный писатель (fifo_holder.pid).
- bbrun64 печатает ~TRAP sig=.. pc=.. при SIGSEGV — `kill -SEGV <pid>` даёт pc
  спина. Маппинг pc → модуль: таблица `+ Mod dad=... cad=...` в логе бута
  (есть и в GUI-логе); дальше `ocf.py refs/dis <ocf> <off>`. ВНИМАНИЕ:
  refs-оффсеты ocf.py могут съезжать на процедуру назад — сверять ret $N.
- Пользователь кликает UI САМ (без MCP-кликов); я только направляю.
- ~TRAP-цепочки после SIGSEGV — каскад обработчика трапов, смотреть только
  ПЕРВУЮ строку (code=0/SI_USER = мой сигнал → pc спина; code=1 = настоящий
  SEGV; sig=15 code=0 = SIGTERM от timeout — НЕ баг).
- Свежий Kernel.ocf — в bbcp64use/*/Code (go64.sh пишет туда), НЕ в bbcp/!
