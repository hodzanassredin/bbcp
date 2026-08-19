# Frame walker и трап-репорты (2026-08-19, коммит 9a425b19)

## Корневые баги (по убыванию важности)

1. **`LinKernel.Below` — x86-32 [code]** (`CMP EAX,[ESP]; POP EAX; SETC AL`):
   на amd64 сравнивал младшие половины и ломал стек. Использовался в
   `InActivationStack` и проверках диапазонов — walker принимал/отвергал
   фреймы случайно. Переписан на чистый CP: unsigned '<' = сравнение со
   сбросом знакового бита `(a<0)=(b<0) ? a<b : b<0`.

2. **`LinKernel.baseStack = 0` навсегда**: `Kernel.SetPlatform` вызывал
   `platform.Setup(baseStack, ...)` ДО того, как `Kernel.Start` делал
   `GETREG(SP, baseStack)` → 0. `InActivationStack` = always FALSE →
   walker останавливался на первом фрейме (в консольном репорте фреймов не
   было вообще). Фикс: SetPlatform берёт `GETREG(SP, baseStack)` перед Setup.

3. **`ASSERT(trap.top # -1)` в LinKernel.HandleTrap** — двигатель бесконечной
   рекурсии: вложенный трап на сигнальном стеке с trap.top=-1 → ASSERT →
   новый трап в той же точке → ... до исчерпания sigStack → core dump.
   Заменён на fallback (`trap.top := fp`).

4. **`Kernel.MarkLocals` на сигнальном стеке**: GC во время трапа сканировал
   [FP_сигстека, baseStack) ≈ сотни ГБ → SEGV-каскад ("137 stack overflow").
   Теперь: если FP вне [baseStack-64MB, baseStack] — сканируем от Kernel.sp
   (sp трапа на основном стеке); совсем вне — пропускаем.

5. **`Kernel.GetRefFrame.Step`** — без проверок: читал [fp]/[fp+8] вслепую,
   битый фрейм → SEGV или цикл (cycle guard 256). Теперь: IsReadable(fp..+16)
   + строгий рост FP; битый фрейм = конец walk'а. `GetThisRefFrame` теперь
   инициализирует eos (GetRefFrameDo OR-ит).

6. **sigStack 64K → 1M**: трап-вьювер (DevDebug) переполнял alt-стек,
   вложенный SIGSEGV убивал процесс без репорта.

7. **DevDebug.ShowArray**: сканы строк читали [a..a+len*size] вслепую —
   гарды IsReadable + отсечка len>64 для обратного скана.

8. **`~IsReadable` спам** в консоли убран (probe-fault — штатная ситуация).

## Состояние после

- Консольный репорт: печатает фрейм упавшей процедуры (module.proc [@pos]),
  процесс завершается чисто (exit 1), без спама и core.
- HALT в листовой процедуре: печатается только фрейм 0 — у трамплина HALT
  нет валидной fp-связки к caller'у (fp=sp, [fp] указывает вниз). Полная
  цепочка для таких фреймов — отдельная задача кодгена/трамплинов.
- probes 28/28.

## Известные остатки

- GC во время репорта может дать вторичный репорт ("137" в CheckCandidates)
  — не фатально, процесс выходит; чинить = запрет GC во время viewer'а.
- GUI Trap-окно не проверялось после правок (нет доступа к дисплею).

## Часть 2 (8c2d8e7f): полные цепочки фреймов

После первой порции фиксов walker печатал только фрейм 0. Причины:

1. **`sentry := "Initialized"` не выполнялся**: bbrun64 предустанавливает
   modList → ветка инициализации в теле Kernel пропускалась, sentry = NIL.
   GetRefFrame считал FrameDesc неинициализированным и делал GETREG(FP) —
   walker уходил в СВОИ фреймы (внутрь обработчика) и обрывался.
   Фикс: sentry присваивается безусловно.
2. **baseStack из Setup (SP в момент SetPlatform) глубже фреймов приложения**
   → InActivationStack отвергал легальные фреймы. Фикс:
   LinKernel.Platform.Start делает GETREG(SP, baseStack) на уровне главного
   цикла.
3. **DevDebug.Trap в консоли падал** (pc=0 через NIL в консольном StdLog.buf)
   и утил в каскад. Фикс: при BB_CONSOLE=1 viewer пропускается — консольный
   репорт ядра уже напечатан. Побочно это закрыло и "вторичный 137 в
   CheckCandidates" — он шёл от аллокаций viewer'а → GC во время трапа.

Итог: консольный репорт = полная цепочка module.proc[@pos] от точки падения
до StdInterpreter.CallProc, один ~TRAP, exit(1). Проверки: ObxProbe78
(HALT в листе), ObxProbe80 (NIL через procvar), ObxProbe81 (HALT с локалами).

## GUI-проверка (2026-08-20, пользователь)

TrapTest (Obx/Docu/TrapTest.odc, командер ObxProbe81.Go) в GUI: Trap-окно
показывает ПОЛНЫЙ стек с локалами (Level3..Go с значениями переменных,
затем Kernel.Call, StdInterpreter, DevCommanders, Views, StdWindows,
LinBackends mouse handler, Loop.Loop, Kernel.Start). Приложение живо.
GUI-ветка walker'а подтверждена.
