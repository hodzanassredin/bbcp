# Paket: NIL-guards ушли в upstream (bbext/Paket)

2026-08-19. Коммит `00f477d` в https://github.com/bbext/Paket (`fixed nre on unresolved
dependencies`). Веб-хук раскатывает новую версию пакета на сервер — после этого
локальные патчи в `~/sources/bbcp64use/Paket/Mod/` можно выкинуть (Paket self-update
перезапишет их апстримными).

## Что исправлено

При установке пакета со строкой `Depends: System Lin Std` (напр. Cuda) базовые
подсистемы не являются пакетами репозитория → `PaketModel.FindPackageBy` = NIL:

1. `PaketFiles.SetDependencies` — `AddToList(selected.depends, NIL, ...)` клал NIL
   в список → далее TRAP 203 (дереф p.data). Теперь `IF dependency # NIL THEN`.
2. `PaketController.InstallPackage` — цикл по `downloading.depends` дерефил
   `deps.package.isInstalled` → guard `(deps.package # NIL) &`.
3. `PaketController.Download` — `ASSERT(downloading # NIL)` → `ASSERT(..., 21)`,
   чтобы вместо анонимного TRAP 0 был читаемый код ловушки.

## Воркфлоу правки Paket (только .odc в репо, без .txt)

```bash
# экспорт в txt (32-битный OdcText из bbcb2, UTF-8 ок)
cd ~/sources/bbcb2-2.0~a1.build332
echo 'OdcText.Export "'$HOME'/sources/bbext/Paket/Mod/Files.odc" "/tmp/f.txt"' | ./run-BlackBoxInterp
# правим /tmp/f.txt, затем обратно:
echo 'OdcText.Import "/tmp/f.txt" "'$HOME'/sources/bbext/Paket/Mod/Files.odc"' | ./run-BlackBoxInterp
```

- Round-trip проверять ре-экспортом: код должен совпасть; отличия только во вьюшке
  StdStamps (пересоздаётся при импорте) и косметической ширине commander'а — норма.
- Пуш: remote SSH `git@github.com:bbext/Paket.git` (https без credential helper
  не пушит; ключ пользователя работает, аккаунт hodzanassredin).

## Cuda: Coder-List (2026-08-19, bbext/Cuda ec9d441, ветка main!)

Cuda/Docu/Coder-List.odc содержал локальные пути `Mod/Rt.odc.txt` — StdCoder
ждёт пакетно-относительные пути с `.odc`, как у Paket (`Cuda/Mod/Rt.odc`).
Исправлено: префикс `Cuda/`, имена `.odc`, порядок Docu затем Mod. В репо Cuda
лежат и .odc, и .odc.txt — оба закоммичены. Ветка Cuda — `main` (не master).
