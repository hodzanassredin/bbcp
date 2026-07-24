# GTK64: этапы A–B выполнены (2026-07-24)

По минимальному пути из KB/Gtk64-Audit.md. Правки только в Lin/Mod/*.odc.txt
(.odc регенерируются tools64/sync-odc.sh).

## Сделано

1. **ccall16 → ccall** (массовая замена, SysV ABI):
   Gtk2GLib (736), Gtk2Gdk (491), Gtk2Gtk (301), Gtk2Pango (247),
   Gtk2GObject (164), Cairo (15), GdkPixbuf (10), CairoPango (2).
   Gtk2Keysyms/Gtk2Util/Clipboard ccall16 не имели. Итого ~1966 деклараций.

2. **Базовые алиасы → LONGINT**:
   - Gtk2GLib: `gsize*`, `gssize*` (заодно добавлены export-метки — иначе
     LinGdkPixbuf не видит Glib.gsize), `glong*`, `gulong*`, `gpointer*`,
     `gconstpointer*`.
   - Gtk2GObject: `GType*`.
   - Gtk2Gdk: `GdkAtom*`, `GdkNativeWindow`.
   - Gtk2Gtk: `ADDRESS`, `GtkClipboard*`.

3. **Этап A (LinGui)**: `InitCheckType(argc, argv: INTEGER)` → LONGINT
   (это int*/char*** — принимает SYSTEM.ADR). Остальное в LinGui уже было
   портировано ранее (dlg/adr LONGINT, [ccall]). LinDl уже LONGINT.

4. **Точечные потребители**:
   - Gtk2Util: `func_data`/`data` INTEGER → LONGINT (gpointer по смыслу).
   - LinClipboard: `bbAtom-, targetUTF8_STRING, targetTEXT` → Gdk.GdkAtom;
     `AtoD(type:)` → Gdk.GdkAtom; `gtk_selection_add_target(..., info)` —
     раньше передавал атом как guint-info; info в ConvertCopy не используется,
     заменено на константы 1/2/3 (0 для STRING неявно).
   - LinGdkPixbuf: `g_bytes_new_with_free_func(size:)` INTEGER → Glib.gsize.

## Проверка

`tools64/test64.sh System Std Text Form Lin Cons` — 0 ошибок, 113 модулей.

## Замечания / открытые вопросы

- **`SHORTINTINTEGER` в GtkWindow** — НЕ баг: это StdFolds.Fold (свёртка с
  текстом-подсказкой "SHORTINT") перед типом поля `configure_request_count: INTEGER`.
  Компилятор view игнорирует.
- **`GdkImage = POINTER TO LIMITED RECORD (GObject.GObject)`** — синтаксис
  валиден (limited record с базовым типом), модуль компилируется.
- `GTime = INTEGER` в GLib (glong по C) — сознательно НЕ тронут (не в списке
  задачи, используется только в g_date_set_time); кандидат на этап C.
- Колбэки LinClipboard (`Clear/ConvertCopy/DoPaste`: event_, user_data_, data_
  INTEGER) — оставлены на этап C (вместе с SysV Enter и раскладками записей).
- LinGui НЕ входит в CompileSubs Lin — отдельно проверять компиляцию
  (gtk_init_check вызов с SYSTEM.ADR → LONGINT формальным параметрам).
- Gtk2Gdk.odc.txt и Gtk2Gtk.odc.txt содержат байты windows-1251 (0x97 —
  тире в комментариях): НЕ UTF-8, править только sed/байтово или аккуратно;
  Edit-инструменты с UTF-8-валидацией их отвергают. OdcText round-trip
  кодировку сохраняет.
