#!/bin/bash
# gdb-gui.sh — запуск bbrun64 GUI под gdb с управлением через FIFO /tmp/gdbin.
# Команды gdb:  echo 'bt' > /tmp/gdbin
# Прерывание inferior: kill -INT $(cat /tmp/inferior.pid)
rm -f /tmp/gdbin /tmp/gdbout /tmp/bb64gui_gdb.log /tmp/inferior.pid
mkfifo /tmp/gdbin
# вечный писатель, чтобы gdb не видел EOF
(while true; do sleep 3600; done > /tmp/gdbin &)
echo $! > /tmp/fifo_holder.pid
cd "$HOME/sources/bbcp64use"
(BB_ARENA_BASE=0x40000000 BB_STANDARD_DIR=$PWD gdb -q "$HOME/sources/bbcp/Dev/Rsrc/bbrun64" < /tmp/gdbin > /tmp/gdbout 2>&1 &)
sleep 2
printf 'set pagination off\n' > /tmp/gdbin
printf 'run > /tmp/bb64gui_gdb.log 2>&1\n' > /tmp/gdbin
sleep 8
pid=$(ps -eo pid,comm | awk '$2=="bbrun64"{print $1}' | head -1)
echo "$pid" > /tmp/inferior.pid
echo "inferior pid: $pid"
tail -1 /tmp/bb64gui_gdb.log
