# Dialog.Notify / Views.NotifyMsg — 64-битный порт (2026-08-18)

## Баг

`Dialog.Update*` усекали адрес рекорда: `adr := SHORT(SYSTEM.ADR(x))`,
`Dialog.Notify(id0, id1: INTEGER)`, `Views.NotifyMsg.id0/id1: INTEGER`.
Пока куча жила ниже 4 ГБ (MAP_32BIT) — работало. После снятия MAP_32BIT
(куча >4 ГБ) усечение стало ломать механизм нотификаций.

Симптом-ловушка: тела DevAnalyzer/DevBrowser (StdRegistry.ReadBool +
Dialog.Update при init) трапались ASSERT(100) в Views.NotifyHook.Notify
— но см. ниже, там ДВА отдельных бага.

## Порт (LONGINT-диапазоны адресов)

- Dialog: Notify(id0,id1: LONGINT), NotifyHook.Notify — абстракт тоже LONGINT,
  вся семья Update* — adr: LONGINT, node.tree: LONGINT (24 SHORT(SYSTEM.ADR)).
- Views: NotifyMsg.id0*/id1* — LONGINT; NotifyHook.Notify — LONGINT.
- Controls: msg.id0 := c.item.adr (SHORT убран); c.adr — ARRAY OF LONGINT;
  Sort по LONGINT.
- StdTables/StdLinks/StdFolds/DevInspector: fingerprint/fp — LONGINT
  (суммы Services.AdrOf).
- StdTabFrames: свой IntMap.id — LONGINT (ключ = адрес view).
- Services.AdrOf — возвращает LONGINT.
- Meta.Item.adr — был портирован раньше (LONGINT).

## Второй баг: headless ASSERT(100)

Views.NotifyHook.Notify делал ASSERT(msgHook # NIL, 100). msgHook ставит
Windows.Init (GUI); ConsWindows (headless) НЕ ставит. bbrun64 грузит и
инитит ВСЕ модули мира → тела с Dialog.Update (DevAnalyzer, DevBrowser)
трапались при буте консоли. В 32-битном BB таких тел при буте нет, т.к.
модули грузятся по требованию.
Фикс: guard `IF msgHook # NIL THEN ... Omnicast ... END` (Views.odc.txt).

## Уроки пайплайна

- Меняешь публичный интерфейс System/Views/Dialog — сразу полная пересборка
  (test64), точечная go64 перекомпиляция создаёт несогласованные osf/ocf,
  и консольный sync-odc умирает → дальше всё едет молча.
- OdcTextU.Batch в ПОЛУМЁРТВОЙ консоли может записать битый .odc
  (случай: Kernel.odc, err 37 у Fold-вьюшки). Лечение: git checkout .odc,
  реконвертация через bbcb2 OdcTextU.Import (UTF-8!). Признак здоровья
  консоли перед sync: `echo 'ObxProbe8.T' | run-bb64 --console` → "P8 OK".
- bbcb2 OdcText.Import (БЕЗ U) — 8-битный, кириллицу портит. Только OdcTextU!
