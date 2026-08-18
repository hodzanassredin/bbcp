# Быстрый старт: рабочий 64-битный BlackBox из клона

Проверено на Debian/Ubuntu amd64. Время сборки мира: ~10–20 минут.

## 0. Зависимости

```bash
# 32-битная libc — для dev0Linux (bootstrap-компилятор, консольный)
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install libc6:i386 gcc make

# 64-битный GTK2 — для GUI (bbrun64 грузит его через dlopen)
sudo apt install libgtk2.0-0 gtk2-engines gtk2-engines-murrine
```

## 1. Клон

```bash
git clone <url-форка> bbcp
cd bbcp
```

Каталог клона любой: скрипты вычисляют корень репо по собственному пути
(`tools64/env64.sh`). Мир по умолчанию создаётся рядом с репо как
`../bbcp64use`; другое место — переменная `BBCP64USE=/путь/к/миру`.

## 2. Загрузчик bbrun64

```bash
make -C Dev/Rsrc -f Makefile64
```

## 3. Мир и полная сборка

```bash
tools64/mkworld64.sh                            # скелет ~/sources/bbcp64use
tools64/test64.sh System Lin Std Text Form Cons Obx
```

Что происходит: dev0 (32-битный bootstrap) компилирует все подсистемы
кросс-компилятором в 64-битные `.ocf`, затем консольная BB64 добирает
Kernel64, OdcTextU, Fig и Dev-пайплайн (компилятор для работы внутри
среды). В конце: `failed=0`, `== DevCompiler64 ... ok`.

Проверка регресса (22 пробника, включая кучу >4 ГБ и GC):

```bash
tools64/probes.sh        # ожидается 22/22 PASS
```

## 4. Запуск

```bash
./run-bb64                                  # GUI
echo 'ObxTestBig.Go' | ./run-bb64 --console # консольная команда
```

## Если что-то пошло не так

- `code file for DevCommanders not found` — мир собран не до конца,
  перезапустите `tools64/test64.sh System Lin Std Text Form Cons Obx`.
- Краш/зависание — `tools64/crash.sh` (автолокализация), логи в /tmp.
- Правка исходников: только `*/Mod/*.odc.txt` (UTF-8), затем
  `tools64/sync-odc.sh` и пересборка модуля `tools64/go64.sh <Имя>`
  (для Dev* — `tools64/build-dev64.sh`). Подробности — `AGENTS.md`,
  журнал — `tasks/task-64bits.md`, база знаний — `KB/`.
