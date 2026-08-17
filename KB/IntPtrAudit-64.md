# Аудит INTEGER-указателей для 64 бит (2026-08-18)

Контекст: GC-куча выше 4 ГБ (MAP_32BIT снят) — любой адрес кучи/libc/GTK/стека,
хранимый или передаваемый как 32-битный INTEGER, усекается → краш.
Модули (код/дескрипторы) пока осознанно ниже 4 ГБ — указатели на них в INTEGER
помечены "допустимо пока", но это долг.

Скоуп:
- **[base]** — ядро bbcp, чиним сейчас: System, Lin, Std, Dev, Text, Form, Cons, Obx.
- **[ext]** — расширения через Paket (Aos, Crypto, _Http, Comm, Json, Mcp, Fjson,
  Sdl2, Ogl, W3c, Sql?, Lists?) — отдельный этап после финиша ядра.
- **[ref]** — Hr: прототип компилятора, ТОЛЬКО для сверки, не чинить.

Уже исправлено (коммиты efd3cf47, e7e2d93f): LinBackends (7 GTK-обработчиков +
ConnectSignals), LinFiles64:668 THISARRAY, Kernel, LinKernel, StdDebug, StdMenus.

## [base] Критично — корневые typedef'ы (чинить первыми, веерная пересборка)

| Файл | Что | Последствие |
|---|---|---|
| Lin/Mod/Libc.odc.txt:328 | `PtrVoid* = INTEGER` | mmap/fread/fwrite/read/write буферы и адреса усекаются. Заодно `long/size_t/ssize_t/off_t = INTEGER` — на LP64 они 64-битные (ABI!) |
| Lin/Mod/Dl.odc.txt:29-34 | `PtrVoid/HANDLE = INTEGER` | dlopen/dlsym: адреса .so мапятся высоко → Lin/Mod/Gui.odc.txt:178-204 `adr := Dl.dlsym(...)` мусор |
| Lin/Mod/Gtk2GLib.odc.txt:39 | `gpointer* = INTEGER` | user_data всех GTK-коллбэков; обёртка Gtk2Util.odc.txt:9,15 `func_data: INTEGER` |
| Lin/Mod/Net.odc.txt:296 | `PtrVoid* = INTEGER` | recv/send буферы |

Веер: смена typedef меняет fingerprint → полная пересборка мира (test64.sh +
build-dev64.sh). Потребители Libc.PtrVoid: LinFiles64:513,750,836; LinFiles
(legacy, выкинуть), Comm/* ([ext]).

## [base] Критично — точечные

| Файл:строки | Что |
|---|---|
| Lin/Mod/Files64.odc.txt:783-796, 868-878 | `from, to: INTEGER := SYSTEM.ADR(...)` → SYSTEM.MOVE кучевых буферов |
| System/Mod/Services.odc.txt:274-277, 35, 305 | `AdrOf(): INTEGER`; `SafeRecAction.adr: INTEGER := ADR(rec)` → TryRec сломан |
| System/Mod/Meta.odc.txt | `Item.adr-: INTEGER` (52); 790-793 ADR стековых ret/b/s (результат Meta.Call*); 661-663 GET по кучевому n; 1188 THISRECORD(rec.adr) |
| Dev/Mod/Debug.odc.txt:414-449, 675, 1069 | зеркало исправленного StdDebug, НЕ исправлено: ShowPointer(a: INTEGER), GET по Cluster в куче, ADR стека в INTEGER-массив. NB: Std/Mod/Debug.odc.txt:381,391 в .txt протухло — перегенерить выгрузку! |
| Dev/Mod/HeapSpy.odc.txt:141-374 | весь обход кучи через VAL(INTEGER, ...) |
| Dev/Mod/Decoder386.odc.txt:1930,1951,2002 | `ref := ADR(meta[0])` (heap NEW) в INTEGER → GET по усечённому |
| Dev/Mod/MsgSpy.odc.txt:142 | ShowHeapObject(ADR(v.msg^)) → DevDebug.ShowHeapObject(adr: INTEGER) |
| Lin/Mod/Clipboard.odc.txt:82,88,225 | ccall-коллбэки с INTEGER-указателями; сейчас func_data=0 и аргументы не читаются — формально неверный ABI, фактически безопасно |

## [base] Допустимо пока (модули/дескрипторы <4 ГБ) / хрупко

- System/Mod/Dialog.odc.txt:97,995,1148-1250 + System/Mod/Views.odc.txt:97 —
  Notify/broadcast-id: адрес в INTEGER, обе стороны усечены консистентно →
  работает, но коллизии по младшим 32 битам возможны. Потребители: Sql ([ext?]).
- Meta.odc.txt:663,722,906-952 — дескрипторы типов <4 ГБ. Kernel.Call(par:
  ARRAY OF INTEGER) несёт адреса параметров — пометить при переносе.
- Std/Mod/Loader.odc.txt:180, Dev/Mod/Linker.odc.txt, LnkBase/LnkLoad —
  адреса загружаемых модулей.
- Lin/Mod/Gui.odc.txt:208,212 — ADR(argc/argv) глобалы.
- Lin/Mod/Init.odc.txt:41 — Fake(_: gpointer), аргумент не читается.
- Sql/Mod/DB.odc.txt:400, Lists/Mod/Op.odc.txt:74 — Kernel.ItemAttr.adr:
  INTEGER, assert гарантирует глобал → допустимо пока.

## [ext] Расширения — отдельный этап

- Aos/Crypto: `ADDRESS* = INTEGER` корневой typedef (Compat.odc.txt:10,
  AosCompat.odc.txt:12, CompatDebug.odc.txt:10); RealConversions:597 —
  endianness-детект через ADR в INTEGER сломан.
- Json/Mod/Dom.odc.txt — весь API на `base: INTEGER`; Mcp Server:407/Client:109
  кормят кучевые буферы → при включении Mcp чинить первым.
- Json/Mod/Native+Api, Fjson ScannerUnsafe/ScannerAsm/SSE* — base/buf: INTEGER;
  сейчас глобальные буферы → допустимо, API опасно.
- _Http/Mod/Openssl.odc.txt:77-78 — SSL_read/write(buf: INTEGER).
- Comm/Mod/TCP__Lin:384,398, V24__Lin:173-217 — через Libc.PtrVoid.

## [ref] Hr — не чинить, только сверка

- Hr/Mod/M.odc.txt:193,202 — ADR value-параметра REAL в INTEGER (LoWord/HiWord
  читают мусор); Ocf.odc.txt:328-366 — цепочки внутри образа модуля (ок).

## Мёртвое/безопасно (для полноты)

Sdl2 GL_GetProcAddress (не вызывается), StdPictures.ref (не вызывается),
Zlib/Inflate (индексы), Text/Models:1968 (только лог), Math/SMath GET/PUT по
ADR напрямую (значения, не адреса), Stores/Stores64:249,252 (числа).
