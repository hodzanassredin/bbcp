# Серый квадрат с крестом вместо встроенной вьюшки (Fig)

Симптом: в Tut-2 (и др. документах) схемы рисуются серым боксом с X.

Причина: это штатный плейсхолдер BlackBox «view не смогла загрузиться».
Схемы в Tut-доках — встроенные `FigViews.StdView` (данные рисунка прямо в
.odc, НЕ внешний ресурс). Подсистема Fig не входила в 64-битный мир
(bbcp64use/Fig отсутствовал): стандартная пересборка `test64.sh System Lin
Std Text Form Cons Obx` её не строит.

Диагностика типа встроенной вьюшки (на хосте bbcb2):
```
echo 'OdcText.Export "<abs>/Docu/Tut-2.odc" "/tmp/Tut-2.odc.txt"' | ./run-BlackBoxInterp
grep -o 'odc-view type="[^"]*"' /tmp/Tut-2.odc.txt | sort | uniq -c
```
(odcey text встроенные вьюшки НЕ показывает.)

Порядок компиляции Fig (по IMPORT): FigModels → FigViews → FigPoints,
FigBasic → FigCmds. Все зависимости (Stores/Ports/Models/Views/Controllers/
Properties/Containers/Services/Dialog/Fonts/Math/StdCmds) — модули System/Std,
в мире уже есть.

```
cd ~/sources/bbcp64use && mkdir -p Fig/Code Fig/Sym
ln -sfn ~/sources/bbcp/Fig/Mod Fig/Mod   # + Docu, Rsrc
~/sources/bbcp/tools64/go64.sh FigModels FigViews FigPoints FigBasic FigCmds
```

ЛОВУШКА: test64.sh стирает `*/Sym/*.osf */Code/*.ocf` ВСЕХ подсистем мира,
даже не входящих в список сборки — Fig добирается в конце test64.sh
автоматически (см. комментарий в скрипте).

Урок для диагностики документов: X-бокс = тип вьюшки не резолвится/модуль
не грузится — первым делом смотреть, собран ли подсистема в мире.
