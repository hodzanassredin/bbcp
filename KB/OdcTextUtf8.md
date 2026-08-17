# OdcTextU: унификация .odc.txt в UTF-8 (2026-08-18)

## Проблема

Пайплайн `.odc <-> .txt` (OdcText в bbcb2-хосте) использовал
`StdTextConv.ExportText/ImportText` — 8-битный "Windows ANSI" конвертер:
экспорт пишет `WriteSChar(SHORT(ch))` (младший байт символа), импорт мапит
байты 0xA0-0xFF на те же кодпоинты Unicode (Latin-1). Последствия:

- кириллица в .odc.txt лежала в cp1251 (7 файлов);
- наши ручные правки писали UTF-8 → смешанные кодировки, Read/Edit-тулы
  отказывались читать такие файлы;
- UTF-8-байты, прошедшие через ANSI-импорт, превращались в .odc в mojibake
  (двойное кодирование): внутри BlackBox комментарии отображались крякозяброй.

## Решение

В bbcb2-хосте создан модуль **OdcTextU** (`bbcb2/Odc/Mod/TextU.odc`) —
копия OdcText, но импорт/экспорт через `StdTextConv.ImportUtf8/ExportUtf8`
(они уже были в StdTextConv; ImportUtf8 при битом UTF-8 молча фолбэчит
на ANSI-импорт — после нормализации не срабатывает).

Переключены скрипты bbcp:
- `tools64/sync-odc.sh` → `OdcTextU.Import`
- `tools64/build-dev64.sh` → `OdcTextU.Import`

## Нормализация (разовая, сделана 2026-08-18)

- 6 файлов с cp1251-комментариями сконвертированы в UTF-8:
  System/Mod/{Meta,Math,Controls}, Dev/Mod/CPM, Lin/Mod/{Gtk2Gtk,Gtk2Gdk}.
- `System/Mod/Dialog.odc.txt`: сырой байт 0xC0 был **в коде** (char-литерал
  `"À"` в тесте `("À" <= ch) & (ch <= 0FFX)`). НЕ cp1251! Заменён на
  hex-литерал `0C0X` — семантика сохранена, зависимости от кодировки нет.
  Правило: не-ASCII литералы в коде писать hex-константами (0C0X), не буквами.
- Все 40 не-ASCII .odc.txt переимпортированы через OdcTextU → в .odc теперь
  настоящая Unicode-кириллица (раньше был mojibake).

## Правила на будущее

- Все `*.odc.txt` в bbcp — **только UTF-8**. cp1251 не писать никуда.
- Экспорт (`OdcTextU.Export`) пишет LF (не CRLF) и переписывает w/h во
  view-тегах заголовка (косметический дрейф 169000->359850 и т.п. — на
  содержимое не влияет, стор у views тот же).
- Round-trip проверен: Meta.odc -> export -> diff с .txt = только w/h строки.

## Проверка кодировки всех .odc.txt

```bash
find . -name '*.odc.txt' -not -path './.git/*' | while read f; do
  iconv -f utf-8 -t utf-8 "$f" >/dev/null 2>&1 || echo "BAD: $f"
done
```
