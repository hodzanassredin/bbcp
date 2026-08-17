# Lazy InitModule и порядок загрузки (bbrun64)

## Симптомы (2026-08-17)

- GUI не стартует / окно без меню; диалог `[LinInit] MODULE IMPORT LinInit: file not found!`
- В логе загрузки: `init LinRegistry...` → поток Gdk/Pango-CRITICAL (`GDK_IS_SCREEN (screen) failed` и т.п.) → цикл тел обрывается, нет `body loop finished`.

## Корневая причина

`Kernel.ThisLoadedMod` (System/Mod/Kernel.odc.txt ~1218) делает ленивый
`InitModule(m)`, если у модуля нет флага `init` в `m.opts`.

`LinRegistry.Init → SearchVar` (Lin/Mod/Registry.odc.txt) идёт по **всему**
`Kernel.modList` и для каждого модуля вызывает `Meta.Lookup(m.name$)` →
`Kernel.ThisMod → StdLoader.ThisMod → ThisLoadedMod → InitModule`.
Итог: посреди тела LinRegistry **каскадно исполняются тела ~80 ещё не
инициализированных модулей в порядке modList (обратном loadOrder)**:

- тела трогают GTK до `gtk_init` (он в теле **LinGui**, которое в loadOrder
  идёт после LinRegistry) → CRITICAL-спам и отравленное состояние (окно без меню);
- тело **LinLoader** стреляет преждевременно → `Load("LinInit")` →
  `Kernel.LoadMod` реентерабельно внутри Meta → `res=1 fileNotFound`
  (мир ещё не готов) → FatalError-диалог.

Преждевременный выстрел LinLoader раньше был фактически «несущим»:
gtk_init выполнялся рано, и всё остальное работало — поэтому GUI когда-то
запускался «через ошибку».

`appStartupProcedure` (ради которой существует SearchVar) **нигде не
определена** — всегда дефолт `Startup.Setup` (no-op).

## Фикс (два слоя, оба нужны)

1. `Lin/Mod/Registry.odc.txt` SearchVar: сканировать только
   инициализированные модули — `IF (16 IN m.opts) & ~(m.refcnt < 0)`.
   16 = Kernel init flag (константа `init` в Kernel не экспортирована).
   Загрузка стала детерминированной: тела строго в loadOrder, без каскада.
2. `Dev/Rsrc/bbrun64.c`: оба лоадера (LinLoader/LinIntLoader) помечаются
   `init` **до выполнения любых тел** (не внутри цикла тел — LinLoader в
   loadOrder идёт ПОСЛЕ LinRegistry, пометка в цикле запаздывает).
   Тело выбранного лоадера вызывается явно в хвосте main.

Пересборка bbrun64: `cd ~/sources/bbcp/Dev/Rsrc && gcc -D_GNU_SOURCE -O2 -g -o bbrun64 bbrun64.c -ldl`
(без `-D_GNU_SOURCE` нет REG_RIP).

## Признаки здоровой загрузки в логе

- ноль `CRITICAL` до `init LinGui...`;
- `done LinRegistry` → тела всех модулей по порядку → `body loop finished`
  → `init LinLoader (main loader, gui mode)...` → `[LI] ... res=0` →
  `before Loop.Start`; окно с меню.

## Остатки-диагностики (убрать на общей чистке)

- `[LI] ...` принты в Lin/Mod/Init.odc.txt (закоммичены, безвредны, stderr).
- LinLoader: ветка `ELSE Kernel.FatalError(1, err)` с неинициализированным
  `err` — pre-existing, не трогали.
