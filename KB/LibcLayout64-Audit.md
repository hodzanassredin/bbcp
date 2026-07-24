# Аудит раскладки RECORD на границе C ABI (x86-64), 2026-07-24

Правило компилятора DevCPCamd64: поля RECORD выравниваются максимум на 4 байта.
8-байтное поле (LONGINT, указатель, PROCEDURE, REAL) после 4-байтного поля встаёт
по смещению +4, а C ABI (SysV x86-64, glibc/GTK2) ждёт естественного выравнивания +8.

Метод: смещения glibc сняты программой с `offsetof` (gcc, `/tmp/audit64.c`) по
реальным заголовкам системы; смещения компилятора посчитаны вручную по правилу
«выравнивание ≤ 4». Для GTK-записей C-смещения — по известной ABI GTK2 (glib/gobject/
gdk/gtk/pango 2.x), без локальных заголовков.

Примечание: KB/Gtk64-Audit.md (того же дня) считал раскладки «ок» в предположении
естественного выравнивания 8-байтных полей. При реальном правиле «максимум 4»
эти вердикты недействительны — см. список ниже. Ширины типов (GdkAtom=LONGINT,
GType=LONGINT, gpointer=LONGINT и т.п.) в исходниках уже исправлены; ломается
именно выравнивание полей.

## (a) Исправлено в Lin/Mod/Libc.odc.txt

### tmDesc (строка ~366) — ИСПРАВЛЕНО
9×int @0..32, затем C кладёт tm_gmtoff@40, tm_zone@48; компилятор клал @36/@44.
Добавлено `pad0: int` после tm_isdst → tm_gmtoff@40, tm_zone@48, size 56 = sizeof(struct tm). ✔
Затрагивает mktime (VAR tmDesc), а через указатель tm — gmtime/localtime/strftime.

### siginfo_t (строка ~386) — ИСПРАВЛЕНО, активный баг
glibc x86-64 имеет явный `int __pad0` по +12; union _sifields начинается с +16
(проверено offsetof: si_addr=16). Компилятор клал union по +12 →
`Kernel.HandleTrap` читал `siginfo._sifields._sigfault.si_addr` по +12 вместо +16
(мусор вместо адреса отказа!). Правки:
- добавлено `pad0: int` после si_code (комментарий: glibc __pad0@12, _sifields@16);
- `_pad`: ARRAY 29 → **28** OF int (__SI_PAD_SIZE = 128/4 − 4 = 28; иначе размер
  записи вырос бы до 132 вместо 128);
- `_sigchild`: `pad0: int` после si_status → si_utime@16, si_stime@24 (было 12/20);
- `_sigfault`: `pad0: int` после si_addr_lsb → _bounds@16, _lower@16, _upper@24
  (было 12/12/20);
- `_sigpoll`: `si_band: int` → `si_band: long` (в C long int@0, si_fd@8; было 0/4).
Абсолютные смещения после правки совпадают с offsetof glibc (si_pid=16, si_addr=16,
si_status=24, si_utime=32, si_band=16, size=128). ✔

## (б) Подозрительные записи в остальных файлах (НЕ правились)

Формат: поле: компилятор → C. Базовая причина №1 — `GObject`: qdata@12 → C@16
(компиляторная база 20 байт вместо 24), от неё съезжает вся иерархия виджетов.
Причина №2 — `GdkEventDesc`: window@4 → C@8, send_event@12 → C@16
(компиляторная база 16 вместо 24), от неё съезжают все события.

### Lin/Mod/Gtk2GLib.odc.txt
- `GTimeVal` L61: tv_sec/tv_usec — glong, объявлены INTEGER (4+4 вместо 8+8; вопрос
  ширины, не паддинга).
- `GHook` L102: hook_id объявлен INTEGER (в C gulong@32!); func@36 → C@48,
  destroy@44 → C@56.
- `GHookList` L113: seq_id INTEGER (в C gulong@0); hooks@8 → C@16,
  hook_memchunk@16 → 24, finalize_hook@24 → 32, dummy1@32 → 40, dummy2@40 → 48.
- `GIOChannel` L463: funcs@4 → C@8, encoding@12 → 16, read_cd@20 → 24,
  write_cd@28 → 32, line_term@36 → 40, read_buf@52 → 64, encoded_read_buf@60 → 72,
  write_buf@68 → 80, reserved1@88 → 104, reserved2@96 → 112 (плюс в C buf_size —
  gsize@56, у нас INTEGER@48: двойной сдвиг после line_term_len).
- `GOptionEntry` L736: arg_data@20 → C@24, description@28 → 32,
  arg_description@36 → 40 (short_name: gchar@8 + flags@12 + arg@16).

### Lin/Mod/Gtk2GObject.odc.txt
- `GTypeInfo` L62: base_init@4 → C@8, base_finalize@12 → 16, class_init@20 → 24,
  class_finalize@28 → 32, class_data@36 → 40, instance_init@48 → 56,
  value_table@56 → 64 (class_size: guint16@0).
- `GValueArray` L103: values@4 → C@8, n_prealloced@12 → 16.
- `GClosure` L176: marshal@4 → C@8, data@12 → 16, notifiers@20 → 24.
- `GParamSpec` L186: value_type@20 → C@24, owner_type@28 → 32, _nick@36 → 40,
  _blurb@44 → 48, qdata@52 → 56, ref_count@60 → 64, param_id@64 → 68.
- `GObject` L200: qdata@12 → C@16. КОРНЕВОЕ — см. иерархию Gtk.

### Lin/Mod/Gtk2Gdk.odc.txt
- `GdkColormap` L444: size@20 → C@24, colors@24 → 32.
- `GdkImage` L454: visual@24 → C@32, byte_order@32 → 40, mem@52 → 64,
  colormap@60 → 72, windowing_data@68 → 80 (плюс база GObject).
- `GdkDeviceAxis` L528: min@4 → C@8, max@12 → 16.
- `GdkDevice` L533: name@20 → C@24, source@28 → 32, axes@44 → 48, num_keys@52 → 56,
  keys@56 → 64.
- `GdkScreen` L544: normal_gcs@24 → C@32, exposure_gcs@280 → 288 (массивы 32×GdkGC).
- `GdkRgbCmap` L575: info_list@1028 → C@1032 (после colors[256]@0 + n_colors@1024).
- `GdkWindowAttr` L581: cursor@52 → C@56, wmclass_name@60 → 64,
  wmclass_class@68 → 72, override_redirect@76 → 80.
- `GdkEventDesc` L617 (база всех событий): window@4 → C@8, send_event@12 → C@16.
- `GdkEventKeyDesc` L630: time@16 → C@20, state@20 → 24, keyval@24 → 28,
  length@28 → 32, string@32 → 40, hardware_keycode@40 → 48, group@42 → 50,
  is_modifier@44 → 52.
- `GdkEventButtonDesc` L643: time@16 → C@20, x@20 → 24, y@28 → 32, axes@36 → 40,
  state@44 → 48, button@48 → 52, x_root@56 → 64, y_root@64 → 72. Плюс семантика:
  `deviceid: INTEGER` — в C это `GdkDevice *device`@56.
- `GdkEventConfigure` L658: x/y/width/height @16/20/24/28 → C@20/24/28/32.
- `GdkEventExpose` L663: area@16 → C@20, region@32 → 40, count@36 → 48.
- `GdkEventFocus` L669: in@16 → C@20.
- `GdkEventMotion` L672: time@16 → C@20, x@20 → 24, y@28 → 32, axes@36 → 40,
  state@44 → 48, is_hint@48 → 52, device@52 → 56, x_root@56 → 64, y_root@64 → 72.
- `GdkEventScrollDesc` L689: time@16 → C@20, x@20 → 24, y@28 → 32, state@36 → 40,
  direction@40 → 44, device@44 → 48, x_root@48 → 56, y_root@56 → 64.
- `GdkEventProperty` L697: atom@16 → C@24, time@24 → 32, state@28 → 36.
- `GdkEventProximity` L702: time@16 → C@20, device@20 → 24.
- `GdkEventClient` L706: message_type@16 → C@24, data_format@24 → 32, data@28 → 40.
  Плюс union: в C `long l[5]` = 40 байт (size union 40, записи 80); у нас l:
  ARRAY 5 OF INTEGER, union 20 байт.
- `GdkEventCrossing` L714: subwindow@16 → C@24 (в C это GdkWindow*, не GdkAtom),
  time@24 → 32, x@28 → 40, y@36 → 48, x_root@44 → 56, y_root@52 → 64,
  mode@60 → 72, detail@64 → 76, focus@68 → 80, state@72 → 84.
- `GdkEventSelection` L725: selection@16 → C@24, target@24 → 32, property@32 → 40,
  time@40 → 48, requestor@44 → 56.
- `GdkEventDND` L732: context@16 → C@24, time@24 → 32, x_root@28 → 34, y_root@30 → 36.
- `GdkEventWindowState` L738: changed_mask@16 → C@20, new_window_state@20 → 24.
- `GdkEventSetting` L743: action@16 → C@20, name@20 → 24.
- `GdkEventVisibility` L686 / `GdkEventNoExpose` L684: только база (state@16 → C@20).

### Lin/Mod/Gtk2Gtk.odc.txt
- `GtkSelectionData` L124: data@28 → C@32, length@36 → 40, display@40 → 48.
  АКТИВНО используется: LinClipboard.ConvertCopy/DoPaste читают .target/.data$/.length.
- `GtkAccelGroup` L138: lock_count@20 → C@24, modifier_mask@24 → 28,
  acceleratables@28 → 32, n_accels@36 → 40; priv_accels INTEGER — в C указатель@48.
- `GtkRcStyle` L146, `GtkStyle` L161 — база GObject 20 вместо 24, все поля съеханы
  (name@20 → C@24 и далее; у GtkStyle массивы GdkColor@20 → C@24...).
- `GtkObject` L191: flags@20 → C@24 (база 24 вместо 32).
- `GtkAdjustment` L195: lower@24 → C@32, upper@32 → 40, value@40 → 48,
  step_increment@48 → 56, page_increment@56 → 64, page_size@64 → 72.
- `GtkWidget` L200: private_flags@24 → C@32, state@26 → 34, name@28 → 40,
  style@36 → 48, requisition@44 → 56, allocation@52 → 64, window@68 → 80,
  parent@76 → 88.
- Все наследники GtkWidget (GtkEntry L217, GtkOldEditable L245, GtkText L252,
  GtkContainer L270, GtkBox L280, GtkCombo L294, GtkBin L323, GtkMenuItem L329,
  GtkWindow L376, GtkDialog L426 и т.д.) — смещения полей съеханы из-за базы;
  пример: GtkContainer.focus_child@84 → C@96, GtkBin.child@96 → C@112.

### Lin/Mod/Gtk2Pango.odc.txt
- `PangoAttrClass` L149: copy@4 → C@8, destroy@12 → 16, equal@20 → 24.
- `PangoAttrFloat` L183: в C `PangoAttribute attr` встроен по значению, value@16;
  у нас attr — указатель@16, value@24.
- `PangoAnalysis` L209: language@28 → C@32, extra_attrs@36 → 40 (level: BYTE@24).
- `PangoItem` L218: analysis@12 → C@16 (три gint @0/4/8, дальше запись с указателями).
- `PangoGlyphString` L260: glyphs@4 → C@8, log_clusters@12 → 16, space@20 → 24.
- `PangoLayoutLine` L294: смещения ок, но size 28 → C 32 (в C два guint-битфилда,
  у нас один SET) — критично только для массивов/встраивания.

## (в) Проверено — корректно (компилятор == C)

### Lin/Mod/Libc.odc.txt (после правок; сверено offsetof)
- `stack_t` (ss_sp@0, ss_flags@8, ss_size@16, size 24) — было исправлено ранее ✔
- `sigaction_t` (sa_sigaction@0, sa_mask@8, sa_flags@136, pad0@140, sa_restorer@144,
  size 152) — было исправлено ранее ✔
- `stat_t`/`stat64_t` (rdev@40, size@48, blksize@56, blocks@64, atim@72, mtim@88,
  ctim@104, size 144) ✔
- `timespec_t` (0/8, 16), `rlimit` (0/8, 16), `TVP` (0/16) ✔
- `ucontext_t` (flags@0, link@8, stack@16, mcontext@40, sigmask@296, fpregs@424,
  ssp@936, size 968), `mcontext_t` (gregs@0, fpregs@184, size 256) ✔
- `Dirent` (ino@0, off@8, reclen@16, type@18, name@19; size 275 vs C 280 — неважно,
  используется через указатель readdir) ✔
- `sigset_t` (opaque 128), `sigjmp_buf` (opaque 200 = sizeof(jmp_buf)) ✔
- скалярные VAR-параметры (time_t, off_t, int) ✔

### Остальные файлы
- `LinRt.timespec_t` ✔; `LinDl`, `LinCairo`, `LinCairoPango`, `LinGtk2Util`,
  `LinGui`, `LinGdkPixbuf` — записей на границе ABI нет (только opaque-указатели) ✔
- Gtk2GLib: `GError` (message@8 ✔), `GArray`/`GByteArray`/`GPtrArray`, `GString`,
  `GList`, `GSList`, `GQueue`, `GNode`, `GTuples`, `GMemVTable`, `GMarkupParser`,
  `GSourceFuncs`, `GSourceCallbackFuncs`, `GPollFD` (fd@0, events@4, revents@6),
  `GDateDesc` ✔
- Gtk2GObject: `GTypeClass`, `GTypeInstance`, `GTypeInterface`, `GTypeQuery`,
  `GTypeFundamentalInfo`, `GInterfaceInfo`, `GValueDesc` (g_type@0, data@8),
  `_GTypeCValue`, `GTypeValueTable`, `GParameterDesc`, `GClosureNotifyDataDesc`,
  `GObjectClass` ✔
- Gtk2Gdk: `GdkPoint`/`GdkRectangle`/`GdkSegment`/`GdkSpan`, `GdkColor` (12 байт ✔),
  `GdkFont`, `GdkGCValues` (все указатели случайно на кратных 8 ✔), `GdkKeymapKey`,
  `GdkVisual`, `GdkDeviceKey`, `GdkGeometry` (min_aspect@32 ✔) ✔
- Gtk2Pango: `PangoRectangle`, `PangoColor`, `PangoMatrix`, `PangoAttribute`,
  `PangoAttrString`/`PangoAttrInt`/`PangoAttrLanguage`/`PangoAttrFontDesc`/
  `PangoAttrSize`/`PangoAttrColor`/`PangoAttrShape`, `PangoLogAttr`,
  `PangoGlyphGeometry`, `PangoGlyphVisAttr`, `PangoGlyphInfo` ✔

## Выводы / приоритеты

1. Libc: siginfo_t был активным багом (HandleTrap читал мусор вместо si_addr) —
   исправлено; tmDesc исправлен.
2. GtkSelectionData — следующий по критичности (Clipboard), затем GdkEventDesc
   (все события) и GObject (все виджеты). Формально это задача правки GTK-записей
   (паддинги) — по заданию здесь не выполнялась.
3. Любое поле-указатель/LONGINT/REAL после 4-байтного поля в [untagged]-записи,
  пересекающей C ABI, требует явного pad-поля INTEGER (по образцу stack_t).
