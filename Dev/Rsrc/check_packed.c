#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
typedef struct __attribute__((packed)) Module {
    struct Module *next; int opts, refcnt; short compTime[6], loadTime[6];
    int ext; int termLo, termHi; int nofimps, nofptrs, csize, dsize, rsize;
    intptr_t code, data, refs, procBase, varBase;
    char* names; intptr_t* ptrs; struct Module* imports; void* export; char name[256];
} Module;
int main() {
    printf("Module: %zu bytes\n", sizeof(Module));
    printf("  code off: %zu\n", offsetof(Module, code));
    printf("  data off: %zu\n", offsetof(Module, data));
    printf("  refs off: %zu\n", offsetof(Module, refs));
    printf("  procBase off: %zu\n", offsetof(Module, procBase));
    printf("  varBase off: %zu\n", offsetof(Module, varBase));
    printf("  names off: %zu\n", offsetof(Module, names));
    printf("  ptrs off: %zu\n", offsetof(Module, ptrs));
    printf("  imports off: %zu\n", offsetof(Module, imports));
    printf("  export off: %zu\n", offsetof(Module, export));
    printf("  name off: %zu\n", offsetof(Module, name));
    return 0;
}
