# gdb-хелперы для отладки bbrun64

Запуск: gdb -batch -ex run -ex 'source tools64/gdb/findmod.py' -ex findmod bbrun64

- findmod.py  — команда `findmod`: модуль+offset по $rip
- addr2mod.py — команда `a2m EXPR`: модуль+offset для произвольного адреса (напр. `a2m 0x7fff...`)
- stackscan.py — команда `stackscan`: скан стека на ret-адреса в модулях

ВАЖНО: ASLR — адреса валидны только внутри одного прогона. Брейкпоинты ставить
через ThisModule: break *(char*)ThisModule("LinFiles")->code+0x990
