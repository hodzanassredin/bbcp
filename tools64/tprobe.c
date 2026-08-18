/* libtprobe.so — тестовая библиотека для ObxProbe18 (FFI: ccall с OUT [nil]
   рекордами). probes.sh собирает её в /tmp/libtprobe.so, если там нет.
   Семантика: probe3 запоминает аргументы (указатели должны дойти без
   усечения!) и пишет через ненулевые; probe_at(i) возвращает сохранённое. */
#include <stdint.h>

typedef struct { int32_t x, y, w, h; } Rec;

static int64_t saved[3];

void probe3 (int64_t a, Rec* b, Rec* c) {
    saved[0] = a; saved[1] = (int64_t)(intptr_t)b; saved[2] = (int64_t)(intptr_t)c;
    if (b != 0) b->y = b->x + 1;
    if (c != 0) c->y = c->x + 1;
}

int64_t probe_at (int64_t i) {
    return saved[i];
}
