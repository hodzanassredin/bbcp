# Аудит GTK-биндингов на 64-битную совместимость (2026-07-24)

Объём: `Lin/Mod/Gtk2{GLib,GObject,Gdk,Gtk,Pango,Keysyms,Util}.odc`,
`Lin/Mod/{Gui,Cairo,CairoPango,GdkPixbuf,Clipboard}.odc`.
Только анализ; исходники не менялись.

## Контекст FFI (по KB/FFI-SysV.md, на дату аудита)

- SysV ccall для целых аргументов: СДЕЛАНО (rdi..r9, стековый хвост, dyn-align, AL=0).
- REAL-аргументы/результаты (xmm0-7): НЕ сделано — слот считается как 1 int-аргумент.
- Callbacks C→BB (SysV Enter): НЕ сделано.
- By-value структуры > 8 байт: раскладка не по SysV (классы INTEGER/MEMORY).
- Все GTK-биндинги объявлены как `[ccall16]` (≈1970 деклараций) — легаси-конвенция;
  на amd64 рабочей является `[ccall]`. Нужна массовая миграция атрибута
  (либо поддержка ccall16→SysV в backend). Счётчик ccall16 по файлам:
  GLib 736, Gdk 491, Gtk 301, Pango 247, GObject 164, Cairo 15, GdkPixbuf 10, Gui 6 (proc-var типы), CairoPango 2.

## Правила маппинга (по образцу Lin/Mod/Libc.odc.txt)

- x86-64 LP64: `long`, `unsigned long`, `size_t/ssize_t`, указатели → `LONGINT`
  (стиль LinLibc: `PtrVoid* = LONGINT; long* = LONGINT; size_t* = LONGINT`).
- `int`, `guint`, `gint`, `gboolean`, `pid_t`, enum, X11 guint32-time → `INTEGER` (остаётся).
- Указатели, объявленные как BB-указатели (`POINTER TO ...`), уже 64-битные — ок.
- INTEGER-параметр sign-extend'ится в 8-байтный слот, поэтому gsize/long **входные**
  параметры в диапазоне int32 практически работают. Опасны: указатели, 64-битные
  **результаты**, VAR/OUT-параметры и поля записей.

---

## LinGtk2GLib (Lin/Mod/Gtk2GLib.odc)

### Базовые типы — текущее → нужное

| Объявление | Сейчас | Нужно (x86-64) |
|---|---|---|
| `gsize`, `gssize` | INTEGER | LONGINT (8 байт) |
| `glong`, `gulong` | INTEGER | LONGINT |
| `gpointer`, `gconstpointer` | INTEGER | LONGINT (или SYSTEM.PTR-стиль) — КРИТИЧНО, используется везде (GList.data, user_data, возвраты g_malloc и т.п.) |
| `GTime` | INTEGER | LONGINT (glong) |
| `GTimeVal.tv_sec/tv_usec` | INTEGER | LONGINT ×2 (glong; сейчас запись 8 байт вместо 16) |
| `GPid` | INTEGER | INTEGER (pid_t = int) — ок |
| `GQuark`, `gunichar`, `gboolean`, `gint/guint`, `gint64/guint64` | INTEGER/LONGINT | ок |
| `guint16 = CHAR`, `gushort = CHAR`, `gint16 = SHORTINT`, `guint8 = SHORTCHAR`, `gint8 = BYTE` | — | ок по размеру |

### Поля записей

- `GHook.hook_id: INTEGER` → gulong = LONGINT. C-раскладка: data@0, next@8, prev@16,
  ref_count@24(guint), hook_id@32(gulong), flags@40, func@48, destroy@56.
- `GString.len, allocated_len: INTEGER` → gsize = LONGINT (смещения: str@0, len@8, allocated@16).
- `GIOChannel.buf_size: INTEGER` → gsize = LONGINT. Остальное (line_term_len guint, flags SET-битфилд, указатели) ок.
- `GMemVTable.*(n_bytes: INTEGER)` → gsize = LONGINT (все 6 proc-полей).
- `GOptionEntry`: на 64 битах C кладёт flags@16 (short_name@8 + 7 байт паддинга),
  BB без паддинга положит flags@12 — НУЖНО явное паддинг-поле после `short_name: gchar`.
  Раскладка C: long_name@0, short_name@8, flags@16, arg@20, arg_data@24, description@32, arg_description@40.
- `GHookList`, `GArray`, `GByteArray`, `GPtrArray`, `GQueue`, `GNode`, `GList`, `GSList`,
  `GError`, `GDateDesc`, `GPollFD` (fd@0 int, events@4, revents@6), `GMarkupParser`,
  `GSourceFuncs`, `GSourceCallbackFuncs`, `GIOFuncs`, `GIOChannel` (кроме buf_size) — ок.
- `stat = RECORD (*!!!*) END` — пустая заглушка для g_stat/g_lstat; на 64 битах непригодна
  (использовать LinLibc.stat). Не на критическом пути.
- `GDateYear = SHORTINT`, `GDateDay = BYTE` — ок по размеру (guint16/guchar).

### Функции с gsize/gsize*/glong в сигнатуре (обязательно LONGINT)

- `g_iconv(...; VAR inbytes_left, outbytes_left: INTEGER): INTEGER` — gsize* и gssize-результат.
- `g_convert*`, `g_locale_to_utf8`, `g_locale_from_utf8`, `g_filename_to/from_utf8` —
  `OUT bytes_read, bytes_written` это gsize* → LONGINT; `len` это gssize.
- `g_file_get_contents(...; OUT length: INTEGER ...)` — gsize*.
- `g_file_set_contents(...; length: INTEGER ...)` — gssize.
- `g_mapped_file_get_length(): INTEGER` — gsize-результат.
- `g_strlcpy/g_strlcat(dest_size: INTEGER): INTEGER` — gsize параметр и результат.
- `g_utf8_strlen(p; max: INTEGER): INTEGER` — gssize/glong.
- `g_timer_elapsed(timer; OUT microseconds: INTEGER)` — gulong* (плюс REAL-результат, см. xmm).
- `g_time_val_add(VAR time: GTimeVal; microseconds: INTEGER)` — glong.
- `g_malloc/g_malloc0/g_try_malloc*/g_realloc/g_memdup/g_mem_chunk_new` — n_bytes/atom_size gsize
  (входные — работают через sign-extend, но по-правильному LONGINT; возврат gpointer → 64 бита!).
- Все функции, возвращающие `gpointer`/`gconstpointer`, — следуют за фиксом типа.

### Баги, не зависящие от битности (замечены по ходу)

- `g_get_current_time(result: GTimeVal)` и `g_source_get_current_time(source; timeval: GTimeVal)` —
  в C это `GTimeVal*` (указатель), у нас запись по значению → должен быть VAR. Баг и на 32 битах.
- `g_main_context_query(...; fds: GPollFD; ...)` — в C `GPollFD*`, у нас по значению.

---

## LinGtk2GObject (Lin/Mod/Gtk2GObject.odc)

- `GType* = INTEGER` → **LONGINT** (GType = gsize!). КРИТИЧНО: g_type_from_name и др.
  возвращают heap-id > 2^31, усечение в INTEGER фатально. Все ~60 функций с GType
  в сигнатуре исправляются автоматически после типа.
- `GValueDesc`: после фикса GType: g_type@0(8), data@8 (union 2×8) = 24 байта — совпадёт с C.
  Сейчас 4+16=20, смещение data неверно.
- `GTypeQuery`: type GType→8 байт, далее type_name@8, class_size@16(guint), instance_size@20 — ок после фикса.
- `GTypeInfo`: class_size guint16@0, указатели@8..40, instance_size/n_preallocs@48/50,
  instance_init@56, value_table@64 — раскладка совпадает с C при CHAR=2 байта. Ок.
- `GClosure`: ref_count SET(guint-битфилд)@0, marshal@8, data@16, notifiers@24 — ок.
- `GParamSpec`, `GObject`, `GObjectClass` — ок после фикса GType/GData (указатели).
- `g_param_spec_long/ulong`, `g_value_set/get_long/ulong` — glong/gulong → LONGINT (через GLib).
- Varargs: `g_object_set/get/connect/disconnect` с заглушкой `arg0: BYTE` — см. раздел varargs.
- double/float: `g_value_set/get_float`, `g_value_set/get_double`, `g_param_spec_float/double` — см. xmm-раздел.

---

## LinGtk2Gdk (Lin/Mod/Gtk2Gdk.odc)

### Типы

- `GdkAtom* = INTEGER` → **LONGINT** (GdkAtom = указатель на opaque). КРИТИЧНО:
  gdk_atom_intern возвращает 64-битное значение; Clipboard хранит атомы в INTEGER.
  Константы GDK_SELECTION_CLIPBOARD=69 и т.п. — это _GDK_MAKE_ATOM (малые числа как
  указатели), остаются корректными после смены типа.
- `GdkNativeWindow = INTEGER` → LONGINT (XID = unsigned long в X11/X.h, 8 байт на LP64;
  значения 32-битные, но тип 8-байтный).
- `GdkFilterFunc = INTEGER`, `GdkSpanFunc = INTEGER` — это проц.указатели → типизировать
  как PROCEDURE [ccall] / SYSTEM.PTR.
- `GdkColor`: C = {guint32 pixel; guint16 red, green, blue} = 12 байт, align 4 —
  текущее объявление (pixel INTEGER + 3×SHORTINT) **корректно и на 64 битах**.
  Проблема не в записи, а в передаче по значению (см. by-value раздел).
- `GdkPoint/GdkRectangle/GdkSegment/GdkSpan/GdkKeymapKey` (все поля gint) — ок.
- `GdkGCValues` — ок (GdkColor 12 байт + указатели/enum, смещения совпадают: font@24, tile@40...).
- `GdkGeometry` — ок (8 gint, min_aspect gdouble@32, max_aspect@40, gravity@48).
- `GdkWindowAttr` — ок (title@0, event_mask@8, ..., override_redirect@80).
- `GdkDeviceAxis` — ок (use@0, min@8, max@16).
- `GdkVisual`, `GdkColormap`, `GdkScreen`, `GdkDevice` — ок (после GObject-базы 24 байта).
- `GdkImage` — объявление выглядит синтаксически странно (`POINTER TO LIMITED RECORD (GObject.GObject);`
  с продолжением полей) — проверить в исходнике при портировании; не на критическом пути.

### GdkEvent* — раскладки (C base: type@0 gint, window@8 ptr, send_event@16 gint8)

| Запись | Вердикт |
|---|---|
| GdkEventKeyDesc | ок (time@20, state@24, keyval@28, length@32, string@40, hw_keycode@48, group@50, is_modifier@52) |
| GdkEventButtonDesc | `deviceid: INTEGER` → в C это `GdkDevice *device` (8 байт). Смещения x_root@64/y_root@72 совпадают случайно (паддинг), но поле надо заменить на GdkDevice |
| GdkEventConfigure | ок (4 gint @20..32) |
| GdkEventExpose | ок (area@20, region@40, count@48) |
| GdkEventFocus | ок (gint16@20) |
| GdkEventMotion | ок (device — указатель, смещения совпадают) |
| GdkEventScrollDesc | ок (device@48, x_root@56, y_root@64) |
| GdkEventProperty | **сломано**: atom — GdkAtom(8)@24; сейчас INTEGER@20 |
| GdkEventProximity | ок |
| GdkEventClient | **сломано**: message_type GdkAtom(8)@24; data_format gint@32; union data в C = {char b[20]; short s[10]; **long l[5]**} = 40 байт@40, итого 80. Сейчас: INTEGER@20, BYTE@24, union 20 байт (l: ARRAY 5 OF INTEGER). Нужно: message_type→8 байт, l→ARRAY 5 OF LONGINT |
| GdkEventCrossing | **сломано**: `subwindow: GdkAtom` (INTEGER@20) — в C это `GdkWindow*`@24. После фикса: time@32, x@40, y@48, x_root@56, y_root@64, mode@72, detail@76, focus@80, state@84 |
| GdkEventSelection | **сломано**: selection/target/property GdkAtom(8)@24/32/40, time guint32@48, requestor GdkNativeWindow(8)@56. Сейчас всё INTEGER |
| GdkEventDND | ок (context@24, time@32, x_root/y_root SHORTINT@34/36) |
| GdkEventWindowState | ок |
| GdkEventSetting | ок |
| GdkEventVisibility / GdkEventNoExpose | ок |

### Функции

- `gdk_atom_intern(...): GdkAtom` — 64-битный результат (КРИТИЧНО для Clipboard).
- `time: INTEGER` во всех gdk_* (guint32) — ок.
- `gdk_event_get_coords/get_root_coords/get_axis`, `gdk_device_get_state/get_axis` —
  REAL только через VAR/OUT (указатели) — xmm НЕ нужен, ок.
- By-value GdkColor/GdkRectangle — см. by-value раздел.
- Колбэки: GdkEventFunc, GdkFilterFunc, GdkInputFunction, ChildFunc, GdkSpanFunc,
  GdkDestroyNotify — см. раздел колбэков.
- `gdk_cairo_create/cairo_*` с REAL — см. xmm-раздел.

---

## LinGtk2Gtk (Lin/Mod/Gtk2Gtk.odc)

- `ADDRESS = INTEGER` → LONGINT. Используется для GtkSignalFunc, GtkMenuDetachFunc,
  GtkCallbackMarshal, GtkDestroyNotify. КРИТИЧНО: SYSTEM.ADR(Proc) — 64-битный адрес,
  усечение в INTEGER ломает все signal-connect.
- `GtkClipboard* = INTEGER` → LONGINT (это GtkClipboard* — указатель). КРИТИЧНО (Clipboard).
- `GtkSelectionData`: selection/target/type — GdkAtom → 8 байт. Раскладка после фикса:
  selection@0, target@8, type@16, format@24(gint), data@32(ptr), length@40(gint),
  display@48(ptr) — совпадает с C. Сейчас всё съехано (3×INTEGER в начале).
- `gtk_signal_connect_full`: func GtkSignalFunc, marshal, destroy_func, func_data gpointer —
  все 4 → 64 бита; `gtk_signal_compat_matched` data: gpointer → 64 бита.
- Раскладки GtkObject/GtkWidget/GtkAdjustment/GtkWindow/GtkRcStyle/GtkStyle/GtkBin/GtkContainer
  и иерархии — проверены против GTK2: **совпадают** (BB-указатели 8 байт, GdkColor 12,
  SET-битфилды = guint 4 байта, gdouble-поля GtkAdjustment @32 по align 8).
- `configure_request_count*: SHORTINTINTEGER;` (GtkWindow, помечено «???») — подозрительная
  лексема (в C — guint16 + битфилды guint). Проверить в .odc при портировании.
- Varargs: `gtk_message_dialog_new`, `gtk_file_chooser_dialog_new`, `gtk_dialog_add_buttons`
  (обрезанный varargs — в C (dialog, first_text, ...), объявлено (dialog, name)) — см. раздел varargs.
- double: `gtk_misc_set_alignment`, `gtk_adjustment_new`, `gtk_clist_moveto`,
  `gtk_spin_button_new/set_value` — см. xmm-раздел.
- Колбэки: TextLenProc, GtkCallBack, GtkFunction, GtkKeySnoopFunc [ccall]; GtkSignalFunc —
  универсальный канал для всех сигналов (delete-event, expose-event, clicked и пр.,
  подключаемых из LinBackends/LinMechanisms через LinGtk2Util).

---

## LinGtk2Pango (Lin/Mod/Gtk2Pango.odc)

- `PangoAttrFloat` — **сломано**: внутри record с базой PangoAttribute повторно объявлено
  поле `attr: PangoAttribute` → value REAL лежит @32 вместо @16. Убрать дубль-поле.
- Остальные записи ок: PangoRectangle (gint×4), PangoColor (guint16×3), PangoMatrix (6 gdouble),
  PangoAnalysis (3 ptr, level guint8@24, language@32, extra_attrs@40), PangoItem,
  PangoGlyphString (num_glyphs@0, glyphs@8, log_clusters@16, space@24), PangoLayoutLine,
  PangoGlyphInfo, PangoLogAttr (битфилд guint).
- double: `pango_font_description_set_absolute_size`, `pango_matrix_translate/scale/rotate`,
  `pango_matrix_get_font_scale_factor(): REAL`, `pango_attr_scale_new` — см. xmm-раздел.
- By-value: PangoMatrix/PangoAnalysis/PangoRectangle/PangoColor в IN-параметрах — см. by-value раздел.
- `pango_tab_array_new_with_positions` — varargs, закомментирован (не объявлен).
- SCALE_XX_SMALL..XX_LARGE — REAL-константы, ок.

---

## LinGtk2Keysyms

Только INTEGER-константы (все < 2^31). Изменений не требует.

---

## LinGtk2Util (Lin/Mod/Gtk2Util.odc)

- `gtk_signal_connect*`, `gtk_signal_connect_after*`: `func_data: INTEGER` → gpointer (64 бита);
  `func: GtkSignalFunc` следует за фиксом ADDRESS в Gtk. КРИТИЧНО (все сигналы идут через это).
- Обертки помечены `[ccall]`, хотя это BB-процедуры — атрибут лишний/безобидный, но при
  миграции конвенций пересмотреть.

---

## LinCairo (Lin/Mod/Cairo.odc)

- `cairo_t`, `cairo_surface_t` — BB-указатели, ок. `cairo_format_t` = enum INTEGER, ок.
- 7 функций с REAL по значению — см. xmm-раздел (это основной рисующий API!).

## LinCairoPango

- Только указатели. Ок.

## LinGdkPixbuf (Lin/Mod/GdkPixbuf.odc)

- Указатели ок. `g_bytes_new_with_free_func(...; size: INTEGER; ...)` — size это gsize → LONGINT.
- `GDestroyNotify` (free_func) — колбэк C→BB, если реально передаётся BB-процедура.
- `new_from_stream(...; VAR error: Glib.GError)` — GError** через VAR указателя — ок.

---

## LinGui (Lin/Mod/Gui.odc)

Всё построено на proc-var типах через LinDl.dlsym:

- `InitCheckType = PROCEDURE [ccall16] (argc, argv: INTEGER): INTEGER` — в C это
  (int *argc, char ***argv); передаётся SYSTEM.ADR(...) → усечение 64-битного адреса. КРИТИЧНО.
  Нужны параметры LONGINT/SYSTEM.PTR (или VAR).
- `GtkMessageDialogNewType (...): INTEGER` — возвращает GtkWidget* → LONGINT. КРИТИЧНО.
- `GtkDialogRunType/GtkWidgetDestroyType/GtkWindowSetTitleType (dlg/window: INTEGER)` — указатели → LONGINT.
- `MessageBox`: `dlg: INTEGER` — хранит GtkMessageDialog* → LONGINT.
- `Init`: `adr: INTEGER` из Dl.dlsym → LONGINT; зависит от порта LinDl
  (Lin/Mod/Dl.odc: `PtrVoid* = INTEGER; HANDLE* = PtrVoid` — пока 32-битный, dlsym-результат
  усечётся уже там. LinDl НЕ входил в объём аудита, но является блокером LinGui).
- gtk_message_dialog_new — varargs, вызывается как ("%s", str) → нужен AL=0 (в FFI уже есть).

---

## LinClipboard (Lin/Mod/Clipboard.odc)

- `bbAtom-, targetUTF8_STRING, targetTEXT: INTEGER` — GdkAtom → LONGINT (следует за Gdk).
- Колбэки [ccall] (C→BB, см. раздел колбэков):
  - `Clear* (w_: GtkWidget; event_, user_data_: INTEGER)` — event_ GdkEvent*, user_data_ gpointer → 64 бита.
  - `ConvertCopy* (widget_: GtkWidget; VAR selection_data: GtkSelectionData; info_, time_: INTEGER; data_: INTEGER)` —
    info_ guint ок, time_ guint32 ок, data_ gpointer → 64 бита. VAR selection_data — по указателю, ок
    после исправления раскладки GtkSelectionData.
  - `DoPaste* (widget_; VAR selection_data; time_: INTEGER; data_: INTEGER)` — аналогично.
- Логика сравнения `selection_data.target = targetUTF8_STRING` заработает только после
  согласованного фикса GdkAtom.
- SetSignals: `SYSTEM.ADR(DoPaste)` → GtkSignalFunc(ADDRESS=INTEGER) — усечение. КРИТИЧНО.

---

# Сводный раздел: double/xmm-функции (REAL по значению или REAL-результат)

По SysV double-аргументы идут в xmm0-7, double-результат в xmm0. Текущий FFI этого не умеет.
(REAL через VAR/OUT — указатели, xmm НЕ нужен: gdk_event_get_coords, gdk_device_get_axis,
gtk_color_selection_get/set_color, GtkColors и т.п. — не входят в список.)

**LinCairo** (весь рисующий API!):
- `cairo_translate (cr: cairo_t; tx, ty: REAL)`
- `cairo_rotate (cr: cairo_t; angle: REAL)`
- `cairo_scale (cr: cairo_t; sx, sy: REAL)`
- `cairo_rectangle (cr: cairo_t; x, y, w, h: REAL)`
- `cairo_set_source_rgb (cr: cairo_t; r, g, b: REAL)`
- `cairo_move_to (cr: cairo_t; x, y: REAL)`
- `cairo_line_to (cr: cairo_t; x, y: REAL)`

**LinGtk2Gdk**:
- `cairo_rectangle (cr: t; x, y, width, height: REAL)`
- `cairo_scale (cr: t; sx, sy: REAL)`
- `cairo_translate (cr: t; tx, ty: REAL)`
- `gdk_cairo_set_source_pixbuf (cr: t; pixbuf: GdkPixbuf; x, y: REAL)`

**LinGtk2Gtk**:
- `gtk_misc_set_alignment (misc: GtkMisc; xalign, yalign: REAL)`
- `gtk_adjustment_new (value, lower, upper, step_increment, page_increment, page_size: REAL): GtkAdjustment` — 6 double!
- `gtk_clist_moveto (clist: GtkCList; row, column: INTEGER; row_align, col_align: REAL)`
- `gtk_spin_button_new (adjustment: GtkAdjustment; climb_rate: REAL; digits: INTEGER): GtkSpinButton`
- `gtk_spin_button_set_value (spin_button: GtkWidget; value: REAL)`

**LinGtk2Pango**:
- `pango_font_description_set_absolute_size (desc: PangoFontDescription; size: REAL)`
- `pango_matrix_translate (VAR matrix: PangoMatrix; tx, ty: REAL)`
- `pango_matrix_scale (IN matrix: PangoMatrix; scale_x, scale_y: REAL)`
- `pango_matrix_rotate (VAR matrix: PangoMatrix; degrees: REAL)`
- `pango_matrix_get_font_scale_factor (IN matrix: PangoMatrix): REAL` — double-результат
- `pango_attr_scale_new (scale_factor: REAL): PangoAttribute`

**LinGtk2GLib**:
- `g_strtod (nptr: PString; OUT endptr: PString): REAL` — double-результат
- `g_ascii_strtod (nptr: PString; OUT endptr: PString): REAL` — double-результат
- `g_ascii_dtostr (buffer: PString; buf_len: INTEGER; d: REAL): PString`
- `g_ascii_formatd (buffer: PString; buf_len: INTEGER; format: PString; d: REAL): PString`
- `g_rand_double (rand: GRand): REAL` / `g_rand_double_range (rand: GRand; begin, end: REAL): REAL`
- `g_random_double (): REAL` / `g_random_double_range (begin, end: REAL): REAL`
- `g_timer_elapsed (timer: GTimer; OUT microseconds: INTEGER): REAL` — double-результат + gulong*

**LinGtk2GObject**:
- `g_value_set_float (value: GValue; v_float: SHORTREAL)` / `g_value_get_float (): SHORTREAL`
- `g_value_set_double (value: GValue; v_double: REAL)` / `g_value_get_double (): REAL`
- `g_param_spec_float (..., minimum, maximum, default_value: SHORTREAL, ...)`
- `g_param_spec_double (..., minimum, maximum, default_value: REAL, ...)`

# Сводный раздел: varargs-функции

Varargs по SysV требуют AL = число использованных xmm-регистров. Наш FFI ставит AL=0 —
достаточно, пока среди «...»-аргументов нет double (во всех ниже — только строки/указатели/int).

- `LinGtk2Gtk.gtk_message_dialog_new (parent, flags: SET; type, buttons; IN message_format; str: PString)` —
  C: (..., const gchar *message_format, ...). Эмулирован фиксированным хвостом ("%s", str). AL=0 ок.
  Используется в LinGui.MessageBox — на критическом пути.
- `LinGui.GtkMessageDialogNewType` (proc-var через dlsym) — тот же приём, AL=0 ок.
- `LinGtk2Gtk.gtk_file_chooser_dialog_new (title; parent; action; b1; r1; b2; r2; terminator)` —
  varargs эмулирован двумя парами + NULL-терминатор. AL=0 ок.
- `LinGtk2Gtk.gtk_dialog_add_buttons (dialog; name: PString)` — в C varargs
  (dialog, first_button_text, ...); объявление обрезано (нет response-id пар и терминатора) —
  формально некорректно, практически не используется. AL=0.
- `LinGtk2GObject.g_object_set / g_object_get / g_object_connect / g_object_disconnect`
  (object; first_property_name: PString; arg0: BYTE) — заглушка varargs. AL=0; семантика
  «...» фактически недоступна (передать можно 1 байт-фейк). Если понадобятся — нужен
  отдельный механизм varargs.
- НЕ объявлены (и хорошо): g_log, g_strdup_printf, g_snprintf, g_error_new,
  gtk_list_store_set, gtk_tree_store_set, gtk_widget_set (varargs), pango_tab_array_new_with_positions.
  Если появятся вызовы с %f — потребуется AL = счётчик xmm (FFI-доработка).

# Сводный раздел: колбэки C→BB

SysV Enter для BB-процедур не реализован (KB/FFI-SysV.md, задача 5). Все перечисленные
места неработоспособны до его появления. Calling convention везде SysV: аргументы в
rdi/rsi/rdx/rcx/r8/r9 (+ xmm для double-аргументов сигналов, напр. "motion-notify"
передаёт GdkEvent* — указатель, регистр).

**Реально подключаемые (из аудированных файлов):**
- `LinClipboard.DoPaste` — "selection-received" (Clipboard.SetSignals, gtk_signal_connect)
- `LinClipboard.ConvertCopy` — "selection-get"
- `LinClipboard.Clear` — "selection-clear-event"
- `LinGdkPixbuf.GDestroyNotify` — free_func в g_bytes_new_with_free_func (если передаётся BB-проц.)

**Точки подключения сигналов вне аудированных файлов, но через аудированные типы:**
- все `gtk_signal_connect*` (LinGtk2Util) — "delete-event", "expose-event", "clicked",
  "configure-event", key/motion-сигналы — подключаются из LinBackends/LinMechanisms
  через `GtkSignalFunc = ADDRESS` (сейчас INTEGER → двойная поломка: усечение адреса + нет SysV Enter).
- `gdk_event_handler_set (GdkEventFunc [ccall] (e: GdkEvent; data: SYSTEM.PTR))` — главный цикл событий.
- `g_timeout_add*/g_idle_add*` (GLib.GSourceFunc [ccall]) — таймеры/idle.

**Объявленные типы колбэков (потенциальные):**
- Gdk: GdkEventFunc, GdkFilterFunc(=INTEGER!), GdkInputFunction, ChildFunc, GdkSpanFunc(=INTEGER!), GdkDestroyNotify.
- Gtk: TextLenProc, GtkCallBack, GtkFunction, GtkKeySnoopFunc, GtkSignalFunc(=ADDRESS), GtkCallbackMarshal, GtkDestroyNotify, GtkMenuDetachFunc.
- GLib: GSourceFunc, GDestroyNotify, GLogFunc, GPrintFunc, GFunc, GCompareFunc/DataFunc, GEqualFunc,
  GHashFunc, GHFunc, GTranslateFunc, GHookFunc-семейство, GIOFunc, GOptionArgFunc/ParseFunc/ErrorFunc,
  GSpawnChildSetupFunc, GDataForeachFunc, GCacheNewFunc/DupFunc/DestroyFunc, GCopyFunc,
  GNodeTraverseFunc/ForeachFunc, GTraverseFunc, GHRFunc, GChildWatchFunc, GPollFunc,
  записи GMarkupParser(5), GIOFuncs(8), GSourceFuncs(6), GSourceCallbackFuncs(3), GMemVTable(6).
- GObject: GBaseInit/FinalizeFunc, GClassInit/FinalizeFunc, GInstanceInitFunc, GInterface*Func,
  GTypeValueTable(6 proc), GObjectConstructor, GObjectGet/SetPropertyFunc, GObjectFinalizeFunc,
  GObjectDispatchFunc, GObjectNotifyFunc, GWeakNotify, GClosureNotify, GCallback.
- Pango: PangoFontsetForeachFunc, PangoAttrFilterFunc, PangoAttrDataCopyFunc, PangoAttrClass(3 proc).

# Сводный раздел: by-value структуры в аргументах (SysV классы INTEGER/MEMORY)

Текущий FFI кладёт by-value comp-аргументы на стек; SysV требует: ≤16 байт — в регистрах
(по eightbytes), >16 байт — MEMORY на стеке. Все нижеперечисленные вызовы некорректны:

- **GdkColor (12 байт → 2 регистра)**: gdk_gc_set_foreground, gdk_gc_set_background,
  gdk_gc_set_rgb_fg_color, gdk_gc_set_rgb_bg_color, gdk_window_set_background,
  gdk_cursor_new_from_pixmap (fg, bg), gdk_pixmap_create_from_data (fg, bg),
  gdk_pixmap_colormap_create_from_xpm(+_d) (transparent_color), gdk_draw_layout_with_colors,
  gdk_draw_layout_line_with_colors, gtk_text_insert (fore, back), gtk_clist_set_background.
- **GdkRectangle (16 байт → 2 регистра)**: gdk_rectangle_intersect, gdk_rectangle_union,
  gtk_widget_draw.
- **GtkAllocation (16 байт)**: gtk_widget_size_allocate.
- **PangoColor (6 байт → 1 регистр)**: pango_color_copy.
- **PangoRectangle (16 байт)**: pango_attr_shape_new(+_with_data), pango_glyph_string_extents(+_range).
- **PangoMatrix (48 байт → MEMORY)**: pango_context_set_matrix, pango_matrix_concat,
  pango_matrix_copy, pango_matrix_scale, pango_matrix_get_font_scale_factor.
- **PangoAnalysis (48 байт → MEMORY)**: pango_shape, pango_break,
  pango_glyph_string_index_to_x, pango_glyph_string_x_to_index.
- **GdkEventDesc (24 байта → MEMORY)**: gtk_widget_event.
- **GTypeInfo/GTypeFundamentalInfo/GInterfaceInfo (IN)**: g_type_register_static/fundamental,
  g_type_add_interface_static — MEMORY.
- Отдельные баги by-value (должны быть указателями): g_get_current_time,
  g_source_get_current_time, g_main_context_query(fds) — см. GLib-раздел.

---

# Оценка объёма работ и минимальный путь до окна

## Что менять (по убыванию критичности)

1. **Миграция конвенции**: ~1970 деклараций `[ccall16]` → рабочая SysV-конвенция
   (массовая правка атрибута или поддержка в backend). Без этого не вызывается ничего.
2. **LinDl** (вне объёма аудита, блокер LinGui): PtrVoid/HANDLE → LONGINT.
3. **Базовые типы** (правок ~15 строк, эффект глобальный):
   GLib: gpointer/gconstpointer, glong/gulong, gsize/gssize → LONGINT;
   GObject: GType → LONGINT; Gdk: GdkAtom, GdkNativeWindow → LONGINT;
   Gtk: ADDRESS → LONGINT, GtkClipboard → LONGINT.
4. **LinGui**: 6 proc-var типов + `adr`/`dlg` INTEGER → LONGINT (≈10 правок).
5. **Поля записей**: GTimeVal(2), GHook.hook_id, GString(2), GIOChannel.buf_size,
   GOptionEntry паддинг, GtkSelectionData(3 поля), GdkEventButton.deviceid,
   GdkEventClient(2), GdkEventCrossing.subwindow, GdkEventSelection(4), GdkEventProperty.atom,
   PangoAttrFloat(дубль-поле) — ≈20 полей в 12 записях.
6. **FFI xmm** (REAL args/results) — нужен для отрисовки (cairo/pango/adjustment), не для открытия окна.
7. **FFI callbacks C→BB (SysV Enter)** — нужен для ЛЮБОГО события (delete-event, expose,
   selection, таймеры). Без него окно откроется, но не закроется и не перерисуется.
8. **FFI by-value struct классификация** — нужна для gdk_gc_set_foreground,
   gdk_window_set_background, gtk_widget_size_allocate и др. при отрисовке.
9. GdkFilterFunc/GdkSpanFunc (=INTEGER) → проц.типы; правка LinGtk2Util func_data;
   GdkPixbuf g_bytes size; GLib gsize-VAR/OUT функции (~20 сигнатур).

## Минимальный путь до открытия окна (поэтапно)

- **Этап A — GTK MessageBox из консоли** (почти не зависит от GTK-модулей):
  LinDl 64-бит + LinGui proc-var типы → LONGINT. gtk_message_dialog_new — varargs AL=0 (готово).
  Колбэки и double не нужны. Объём: ~15 правок в 2 файлах.
- **Этап B — пустое окно + главный цикл** (gtk_init, gtk_window_new, gtk_widget_show,
  gtk_main_iteration): пункты 1+3 (ccall16-миграция, базовые типы) + Gtk-функции
  (все нужные — pointer/INTEGER args). Double и колбэки всё ещё НЕ нужны.
  Окно появится, но без обработки событий.
- **Этап C — события/ввод**: SysV Enter для колбэков + раскладки GdkEvent* (8 записей из таблицы)
  + GtkSelectionData + LinClipboard-типы. После этого работают delete-event, клавиатура/мышь, clipboard.
- **Этап D — отрисовка**: xmm-поддержка (список из 31 функции, критичны cairo_* и
  pango_font_description_set_absolute_size) + by-value struct классификация (GdkColor/GdkRectangle).

## Оценка трудоёмкости (только правки биндингов, без FFI-движка)

- Этап A: ~0.5 дня (2 файла).
- Этап B: 1–2 дня (массовая механическая замена ccall16 + типы; ~2000 строк деклараций,
  реально правятся ~30 типов/сигнатур + глобальный атрибут).
- Этап C: 1 день на записи + зависит от SysV Enter в компиляторе (FFI-задача, отдельная).
- Этап D: зависит от xmm и by-value в FFI (2 отдельные FFI-задачи); правки биндингов нулевые
  (сигнатуры уже REAL — FFI должен научиться их передавать).

Риски: (1) `SHORTINTINTEGER` в GtkWindow и странное объявление GdkImage — проверить
в исходниках при правке; (2) g_get_current_time/g_source_get_current_time/g_main_context_query —
by-value баги, существующие и на 32 битах; (3) GtkClipboard/GtkSignalFunc как INTEGER
уже используются в LinClipboard/LinBackends — после смены типов проверить все call-site'ы
в LinPorts/LinMechanisms/LinBackends (вне объёма аудита).
