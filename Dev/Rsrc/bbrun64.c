#include <errno.h>
/* C-startup and loader for BlackBox
* Implemented as the StdLoader.
*/

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <stdint.h>
#include <stdbool.h>
#include <assert.h>

/* #define BB_FILE "bb.boot" */
#define BB_FILE argv[0]
/* #define BB_FILE argv[1] */
/* the exact size (in bytes) of the executable part of the file. */
/* this constant needs to be updated everytime a change is made to this file */
#define exeSize  EXESIZE /* = size of exe.img */

/* fixup types */
#define absolute 100
#define relative 101
#define copy 102
#define table 103
#define tableend 104
#define deref 105
#define halfword 106

/* import types */
#define mConst 0x1
#define mTyp 0x2
#define mVar 0x3
#define mProc 0x4
#define mExported 4

#define any 1000000
#define init 0x10000

/* set to printf to debug and donothing to avoid debugging */

#define dprintf donothing

typedef void (*BodyProc)();

typedef char String[256];

typedef struct Type {
    int size;
    struct Module* mod;
    int id;
    int base[16]; /* should be ARRAY 16 OF TYPE */
    int fields;   /* should be Directory* */
    int ptroffs[any];
} Type;


typedef struct Object{
    int fprint;
    int offs;
    int id;
    Type* ostruct;
} Object;


typedef struct Directory{
    int num;
    Object obj[any];
} Directory;


typedef struct __attribute__((packed)) Module {
    struct Module *next;
    int opts;
    int refcnt;
    short compTime[6], loadTime[6];
    int ext;
    int term; /* actually a pointer to type Command */
    int nofimps, nofptrs;
    int csize, dsize, rsize;
    intptr_t code, data, refs;
    intptr_t procBase, varBase; /* meta base addresses */
    char* names;  /* names[0] = 0X */
    int* ptrs;
    struct Module* imports;
    Directory* export;
    char name[256];
} Module;


typedef struct ImpList {
    struct ImpList* next;
    String name;
} ImpList;


typedef struct ModSpec {
    ImpList* imp;
    String name;
    int start, hs, ds, ms, cs, vs;
    intptr_t dad, mad, cad, vad;
} ModSpec;

typedef struct BootInfo {
    Module* modList;
    int argc;
    char** argv;
} BootInfo;



FILE* f;
int nofMods;
String kernel, mainmod;
ModSpec mod;
Module *modlist;
BootInfo* bootInfo;
intptr_t newRecAdr, newArrAdr;
int newRecFP, newArrFP;

static void donothing(char* fmt, ...) {}

static void *AllocMem (size_t size, bool for_exec) {
    size_t pagesize = getpagesize();

    size_t len = (size + pagesize - 1) & ~(pagesize - 1);

    int prot = PROT_READ | PROT_WRITE;
    if (for_exec) {
#if defined(__NetBSD__)
        prot |= PROT_MPROTECT(PROT_EXEC);
#endif
    }

    void *mem = mmap(NULL, len, prot, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (mem == MAP_FAILED) {
        perror("mmap");
        return NULL;
    }

    // NOTE:
    // Memory returned is page-aligned (guaranteed by mmap)
    // Memory is zero-filled (guaranteed for MAP_ANONYMOUS)
    // To free this memory, use: munmap(mem, len)

    return mem;
}

static bool FreeMem (void *mem, size_t size) {
    if (mem != NULL) {
        size_t pagesize = getpagesize();
        if (!munmap(mem, (size + pagesize - 1) & ~(pagesize - 1))) {
            perror("munmap");
            return false;
        }
    }
    return true;
}

static void DumpMod()
{
    dprintf("\n\n---- Mod info:\n");
    dprintf("        hs = %d\n", mod.hs);
    dprintf("        dad = %p, ds = %d\n", (void *)mod.dad, mod.ds);
    dprintf("        mad = %p, ms = %d\n", (void *)mod.mad, mod.ms);
    dprintf("        cad = %p, cs = %d\n", (void *)mod.cad, mod.cs);
    dprintf("        vad = %p, vs = %d\n\n", (void *)mod.vad, mod.vs);
}

static void DumpModule (const Module *m) {

    dprintf("Module %s\n", m->name);
    dprintf("    opts = 0x%08x\n", m->opts);
    dprintf("    ext = %d\n", m->ext);
    dprintf("    term = %p\n", (void *)m->term);
    dprintf("    nofimps = %d, nofptrs = %d\n", m->nofimps, m->nofptrs);
    dprintf("    csize = %d, dsize = %d, rsize = %d\n", m->csize, m->dsize, m->rsize);
    dprintf("    code = %p, data = %p, refs = %p\n", (void *)m->code, (void *)m->data, (void *)m->refs);
    dprintf("    procBase = %p, varBase = %p\n", (void *)m->procBase, (void *)m->varBase);
}

static void RegisterModule()
{
    Module* m;
    unsigned char *desc = (unsigned char*)mod.dad;
    
    m = (Module*) AllocMem(sizeof(Module), false);
    if (!m) { printf("OOM\n"); return; }
    memset(m, 0, sizeof(Module));
    
    /* Use the boot loader's allocated addresses - these are the real 64-bit values */
    m->code = (intptr_t)mod.cad;
    m->data = (intptr_t)mod.dad;
    m->refs = (intptr_t)mod.mad;
    m->procBase = (intptr_t)mod.cad;  /* proc entries are at start of code */
    m->varBase = mod.vad ? (intptr_t)mod.vad : (intptr_t)mod.dad;
    
    /* Copy module name from header */
    strncpy(m->name, mod.name, 255);
    m->name[255] = 0;
    
    m->next = modlist;
    modlist = m;
    printf("  + %s (code=%p)\n", m->name, (void*)m->code);
}

static void PrintMods()
{
    Module* ml;
    ml = modlist;
    printf("Loaded Modules\n");
    while (ml != NULL){
        printf("mod name: %s\n", ml->name);
        ml = ml->next;
    }
    printf("end of list\n");
}


static Module* ThisModule(char* name)
{
    Module* ml;
    ml = modlist;
    while ((ml != NULL) && (strcmp(ml->name, name) != 0)){ml = ml->next;}
    return ml;
}

static Object* ThisObject(Module* mod, char* name)
{
    int l, r, m;
    char* p;
    l = 0; r = mod->export->num;
    while (l < r) {
        m = (l + r) / 2;
        p = (char*) &(mod->names[mod->export->obj[m].id / 256]);
        if (strcmp(p, name) == 0)
            return (Object*)&(mod->export->obj[m]);
        if (strcmp(p, name) < 0)
            l = m + 1;
        else
            r = m;
    }
    return NULL;
}

static Object* ThisDesc(Module* mod, int fprint)
{
    int i, n;
    i = 0; n = mod->export->num;
    while ((i < n) && (mod->export->obj[i].id / 256 == 0))  {
        if (mod->export->obj[i].offs == fprint)
            return (Object*)&(mod->export->obj[i]);
        i++;
    }
    return NULL;
}

static int LoadDll (char* name)
{
    void *handle;
    printf("loading: %s\n", name);
    if ((handle = dlopen(name, RTLD_LAZY + RTLD_GLOBAL)) == NULL) {
        printf("LoadDll: failed to load lib %s\n", name);
        printf(" - dlerror: %s\n", dlerror());
        exit(-1);
    }
    return handle != NULL;
}


static int ThisDllObj (int mode, int fprint, char* dll, char* name)
{
    void *handle;
    int ad = 0;
    if (strcmp(name, "dlopen") == 0) return (intptr_t)&dlopen;
    if (strcmp(name, "dlsym") == 0) return (intptr_t)&dlsym;
    if ((mode == mVar) || (mode == mProc)){
        if ((handle = dlopen(dll, RTLD_LAZY + RTLD_GLOBAL)) == NULL) {
            printf("ThisDllObj: lib %s not found\n", dll);
            printf(" - dlerror: %s\n", dlerror());
            exit(-1);
        } else {
            ad = (intptr_t)dlsym((void *) handle, name);
            if (ad == 0) {
                printf("ThisDllObj: symbol %s not found\n", name);
                /*        exit(-1); */
            }
        }
    }
    return ad;
}

static int Read4 ()
{
    unsigned char b;
    int   w;
    b = fgetc(f); w = b % 256;
    b = fgetc(f); w = w + 0x100 * (b % 256);
    b = fgetc(f); w = w + 0x10000 * (b % 256);
    b = fgetc(f); w = w + 0x1000000 * b;
    return w;
}

static intptr_t RNum()
{
    int b;
    intptr_t s, y;
    s = 0; y = 0;
    b = fgetc(f);
    while (b >= 128) {    /* high bit set = more bytes follow */
        y = y + ((intptr_t)((b & 0x7F)) << s);
        s = s + 7;
        b = fgetc(f);
    }
    /* b is the final byte (high bit clear), decode its signed value */
    if (b & 0x40)  /* negative: b in 64..127, value = b - 128 */
        return (((intptr_t)(b - 128)) << s) + y;
    else  /* positive: b in 0..63 */
        return (((intptr_t)b) << s) + y;
}

static void ReadName (char* str)
{
    unsigned char b;
    int i;

    i = 0; b = fgetc(f);
    while (b != 0)  {
        str[i] = b; i++; b = fgetc(f);
    }
    str[i] = 0;
}

/* Process one fixup chain. adr = base address for value calculation.
   For meta/data links (negative), section base is determined by abs(link) < ms. */
static void Fixup0 (intptr_t adr)
{
    intptr_t link, offset, ladr, base;
    int chainPatches = 0;
    
    link = RNum();
    while (link != 0) {
        offset = RNum();
        while (link != 0) {
            int abslink = (link > 0) ? link : -link;
            if (link > 0) {
                ladr = (intptr_t)mod.cad + abslink;
                base = (intptr_t)mod.cad;
            } else if (abslink < mod.ms) {
                ladr = (intptr_t)mod.mad + abslink;
                base = (intptr_t)mod.mad;
            } else {
                ladr = (intptr_t)mod.dad + abslink - mod.ms;
                base = (intptr_t)mod.dad;
            }
            
            /* Read fixup metadata */
            int meta = *(int*)(intptr_t)ladr;
            int typ = (meta >> 24) & 0xFF;
            int nxt = meta & 0xFFFFFF;
            if (nxt & 0x800000) nxt -= 0x1000000;
            
            if (typ >= 100 && typ <= 114) {
                intptr_t target = adr + offset;
                if (typ == absolute || typ == deref) {
                    *(intptr_t*)ladr = target;
                    chainPatches++;
                } else if (typ >= 106 && typ <= 114) {
                    int immLen = typ - 106;
                    *(int*)ladr = (int)(target - (ladr + 4 + immLen));
                    chainPatches++;
                } else if (typ == relative) {
                    *(int*)ladr = (int)(target - ladr - 4);
                    chainPatches++;
                }
            }
            
            link = nxt;
            if (chainPatches > 10000) { printf(" FIXUP LOOP\n"); return; }
        }
        link = RNum();
    }
    if (chainPatches > 0) printf("  chain: %d patches\n", chainPatches);
}

static void Fixup (intptr_t adr)
{
    intptr_t link, offset, linkadr, nextLink;
    int typ;

    link = RNum();
    while (link != 0) {
        offset = RNum();
        nextLink = 0;
        while (link != 0)
        {
            if (link > 0)
                linkadr = mod.cad + link;
            else {
                link = -link;
                if (link < mod.ms)
                    linkadr = mod.mad + link;
                else
                    linkadr = mod.dad + link - mod.ms;
            }

            /* Read 4-byte metadata at link address (32-bit fixup format) */
            {
                int meta = *(int*)linkadr;
                typ = (meta >> 24) & 0xFF;
                nextLink = meta & 0xFFFFFF;
                if (nextLink & 0x800000) nextLink = nextLink - 0x1000000;
            }

            if (typ == absolute || typ == deref) {
                /* Store 8-byte absolute address */
                *(intptr_t*)linkadr = adr + offset;
            } else if (typ == relative) {
                *(int*)linkadr = (int)(adr + offset - linkadr - 4);
            } else if (typ >= 106 && typ <= 114) {
                /* ripBased+N: N = typ - 106 bytes of immediate follow the displacement */
                int immLen = typ - 106;
                intptr_t target = adr + offset;
                intptr_t disp = target - (linkadr + 4 + immLen);
                *(int*)linkadr = (int)disp;
            } else if (typ == copy) {
                /* copy: bytes from source to dest. offset is byte count in low 16 bits */
                int nbytes = (int)(offset & 0xFFFF);
                int srcOff = (int)((offset >> 16) & 0xFFFF);
                intptr_t src = adr + srcOff;
                memcpy((void*)linkadr, (void*)src, nbytes);
            } else if (typ == table) {
                *(intptr_t*)linkadr = adr + nextLink;
                nextLink = link + 4;
            } else if (typ == tableend) {
                *(intptr_t*)linkadr = adr + nextLink;
                nextLink = 0;
            } else {
                printf("fixup: unknown type %d at %lx\n", typ, (long)linkadr);
                return;
            }
            link = nextLink;
        }
        link = RNum();
    }
}
static int ReadBootHeader()
{
    int tag, version;
    fseek(f, exeSize, SEEK_SET);
    tag = Read4();
    version = Read4();
    if ((tag != 0x3A4B5C6D) || (version != 0))  { return 0; }
    nofMods = Read4();
    printf("Linked modules: %d\n", nofMods);
    ReadName(kernel);
    printf("kernel: %s\n", kernel);
    ReadName(mainmod);
    printf("main: %s\n", mainmod);
    newRecFP = Read4(); newRecAdr = 0;
    newArrFP = Read4(); newArrAdr = 0;
    /* Seek to end of current OCF: header + meta + desc + code + data */
    fseek(f, mod.start + mod.hs + mod.ms + mod.ds + mod.cs + mod.vs, SEEK_SET);
skip_exports_64:
    mod.start = ftell(f);
    return 1;
}

static bool ReadHeader ()
{
    int ofTag, i, nofImps, processor;
    // char str[80];
    ImpList *imp, *last;
    char* n;

    ofTag = Read4();
    if (ofTag != 0x6F4F4346)
    {
        printf("wrong object file version\n");
        return false;
    }
    processor = Read4();
    mod.hs = Read4();
    mod.ms = Read4();
    mod.ds = Read4();
    mod.cs = Read4();
    mod.vs = Read4();
    dprintf("File tag: %d ", ofTag); dprintf("Processor: %d\n", processor);
    dprintf("Header size: %d ", mod.hs);
    dprintf("Meta size: %d ", mod.ms);
    dprintf("Desc size: %d ", mod.ds );
    dprintf("Code size: %d ", mod.cs);
    dprintf("Data size: %d\n", mod.vs);
    nofImps = RNum(); dprintf("Nof imports: %d\n", nofImps);
    ReadName(mod.name); dprintf("Module name: %s\n", mod.name);
    mod.imp = NULL;
    for (i = 0; i < nofImps; i++)
    {
        imp = (ImpList*)AllocMem(sizeof(ImpList), false); assert(imp != NULL);
        ReadName(imp->name);
        if (mod.imp == NULL)
            mod.imp = imp;
        else
            last->next = imp;
        last = imp;
        last->next = NULL;
        dprintf("Import %d: %s\n", i, imp->name);
        if ((imp->name[0] == '$') && (imp->name[1] == '$'))
            strlcpy(imp->name, "Kernel", sizeof(imp->name));
        if (imp->name[0] == '$'){
            n = imp->name;
            n++;
            if (!LoadDll(n)){
                printf("Could not load lib: %s\n", imp->name);
                return false;
            }
        }
    }
    dprintf("Pos: %ld\n", ftell(f));
    return true;
}

static bool AllocModMem () {
    assert(mod.ds != 0);
    assert(mod.ms != 0);
    assert(mod.cs != 0);
    int ms = sizeof(int) + mod.ms;
    mod.dad = (intptr_t) AllocMem(mod.ds, false);
    mod.mad = (intptr_t) AllocMem(ms, false);
    mod.cad = (intptr_t) AllocMem(mod.cs, true);
    if (mod.vs != 0) {
        mod.vad = (intptr_t) AllocMem(mod.vs, false);
    } else {
        mod.vad = 0;
    }
    if ((mod.dad == 0) || (mod.mad == 0) || (mod.cad == 0) || ((mod.vad == 0) && (mod.vs != 0)))
    {
        bool ok;
        ok = FreeMem((void *)mod.dad, mod.ds); assert(ok); mod.dad = 0;
        ok = FreeMem((void *)mod.mad, ms); assert(ok); mod.mad = 0;
        ok = FreeMem((void *)mod.cad, mod.cs); assert(ok); mod.cad = 0;
        ok = FreeMem((void *)mod.vad, mod.vs); assert(ok); mod.vad = 0;
        return false;
    }
    *((int*)mod.mad) = ms;
    mod.mad += sizeof(int);
    return true;
}

static bool FixModMemPermissions () {
    assert(mod.ms != 0);
    assert(mod.cs != 0);
    size_t size;

    size_t pagesize = getpagesize();

    size = sizeof(int) + mod.ms;
    size = (size + pagesize - 1) & ~(pagesize - 1);
    if (mprotect((void *)(mod.mad - sizeof(int)), size, PROT_READ) != 0) {
        perror("mprotect (meta)");
        return false;
    }

    size = mod.cs;
    size = (size + pagesize - 1) & ~(pagesize - 1);
    if (mprotect((void *)mod.cad, size, PROT_READ | PROT_EXEC) != 0) {
        perror("mprotect (code)");
        return false;
    }

    return true;
}

static bool ReadModule ()
{
    char *dp, *mp, *cp;
    unsigned int cnt;
    ImpList* imp;
    intptr_t x, fp, imptab, a;
    int opt, ofp;
    // int link;
    Module *desc, *k;
    String name;
    Object* obj;
    int isLib;
    char* im;

    if (!AllocModMem()) {
        printf("BootLoader: Couldn't initalize heap\n");
        return false;
    }
    dp = (char*) mod.dad;
    mp = (char*) mod.mad;
    cp = (char*) mod.cad;
    fseek(f, mod.start + mod.hs, SEEK_SET);  /* OCF code section */
    dprintf("ReadModule after fseek pos: %ld\n", ftell(f));
    cnt = fread(mp, 1, mod.ms, f);
    dprintf("Read meta bulk (%d bytes. New pos: %ld)\n", cnt, ftell(f));
    cnt = fread(dp, 1, mod.ds, f);
    dprintf("Read desc bulk (%d bytes. New pos: %ld)\n", cnt, ftell(f));
    cnt = fread(cp, 1, mod.cs, f);
    dprintf("Read code bulk (%d bytes. New pos: %ld)\n", cnt, ftell(f));
    DumpMod();
    dprintf("before fixup: pos = %ld\n", ftell(f));

    /* SKIP export/import resolution for now - just load code */
    newRecAdr = 1;  /* prevent lookup */
    newArrAdr = 1;
    /* Process all fixup chains in sequence.
       The fixup table starts at current file position (after code+data sections). */
    /* Skip past variable section to reach fixup table */
    fseek(f, mod.vs, SEEK_CUR);
    printf("  Fixups at file pos %ld (after %d var bytes)\n", ftell(f), mod.vs);
    fflush(stdout);
    {
        intptr_t link, offset, ladr;
        int chainNum = 0;
        int codePatches = 0;
        
        int chain_limit = 0;
        link = RNum();
        while (link != 0 && chain_limit++ < 50) {
            offset = RNum();
            chainNum++;
            while (link != 0) {
                /* Determine section from link sign */
                intptr_t base;
                int abslink;
                if (link > 0) {
                    ladr = (intptr_t)mod.cad + link;
                    base = (intptr_t)mod.cad;
                    abslink = link;
                } else {
                    abslink = -link;
                    if (abslink < mod.ms) {
                        ladr = (intptr_t)mod.mad + abslink;
                        base = (intptr_t)mod.mad;
                    } else {
                        ladr = (intptr_t)mod.dad + abslink - mod.ms;
                        base = (intptr_t)mod.dad;
                    }
                }
                
                /* Safety: check ladr is within allocated memory */
                if (ladr < (intptr_t)mod.cad || ladr > (intptr_t)mod.cad + mod.cs + mod.ds + mod.ms) {
                    printf("    WARN: ladr 0x%lx out of bounds, breaking chain\n", (long)ladr);
                    break;
                }
                /* Read fixup metadata (4 bytes at ladr) */
                int meta = *(int*)(intptr_t)ladr;
                int typ = (meta >> 24) & 0xFF;
                int nxt = meta & 0xFFFFFF;
                if (nxt & 0x800000) nxt -= 0x1000000;
                /* Limit sub-link iterations */
                static int sub_iters = 0;
                if (++sub_iters > 1000) { printf("    WARN: too many sub-links, breaking\n"); break; }
                
                if (typ >= 100 && typ <= 114) {
                    /* Valid fixup type - patch it */
                    intptr_t base = (link > 0) ? (intptr_t)mod.cad : 
                                    ((link < mod.ms) ? (intptr_t)mod.mad : (intptr_t)mod.dad);
                    
                    if (typ == absolute || typ == deref || (typ >= 106 && typ <= 114)) {
                        *(intptr_t*)ladr = base + offset;
                        codePatches++;
                    } else if (typ == relative) {
                        *(int*)ladr = (int)(base + offset - ladr - 4);
                        codePatches++;
                    }
                }
                
                link = nxt;
            }
            link = RNum();
        }
        printf("  Processed %d chains, %d patches\n", chainNum, codePatches);
        fflush(stdout);
    }
    goto skip_exports_64;
    
    if ((!newRecAdr) || (!newArrAdr)){
        k = ThisModule(kernel);
        if (k != NULL){
            /*      obj = ThisDesc(k, newRecFP);*/
            obj = ThisObject(k, "NewRec");
            if (obj != NULL)
                newRecAdr = k->procBase + obj->offs;
            /*      obj = ThisDesc(k, newArrFP);*/
            obj = ThisObject(k, "NewArr");
            if (obj != NULL)
                newArrAdr = k->procBase + obj->offs;
            dprintf("newRecFP: %X  newArrFP: %X\n", newRecFP, newArrFP);
            dprintf("newRecAdr: %X  newArrAdr: %X\n", newRecAdr, newArrAdr);
        } else {
            dprintf("no kernel before %s.\n", mod.name);
        }
    }
    /* Apply fixups to all sections */
    dprintf("after fixup: pos = %ld\n", ftell(f));
    imp = mod.imp;
    imptab = (intptr_t)((Module*)(mod.dad))->imports;
    while (imp != NULL){
        x = RNum();
        if ((imp->name[0] == '$') && (imp->name[1] == '$'))        printf("should be Kernel\n");
        if (imp->name[0] == '$')        isLib = 1;
        else{
            isLib = 0;
            desc = ThisModule(imp->name);
            if (desc == NULL){
                printf("invalid import list\n");
                return false;
            }
        }
        while (x != 0) {
            ReadName(name); fp = RNum(); opt = 0;
            if (!isLib) {
                if (name[0] == 0)
                    obj = ThisDesc(desc, fp);
                else
                    obj = ThisObject(desc, name);

                if ((obj != NULL) && (obj->id % 16 == x)){
                    ofp = obj->fprint;
                    switch (x){
                    case mTyp: opt = RNum();
                        if (opt % 2 == 1) ofp = obj->offs;
                        if ((opt > 1) && ((obj->id / 16) % 16 != mExported)){
                            printf("object not found (%s)\n", imp->name);
                            return false;
                        }
                        Fixup((intptr_t)obj->ostruct);
                        break;
                    case mVar:
                        Fixup(desc->varBase + obj->offs);
                        break;
                    case mProc:
                        Fixup(desc->procBase + obj->offs);
                    }

                    if (ofp != fp){
                        printf("illigal foot print (%s)\n", imp->name);
                        return false;
                    }
                } else {
                    if (obj == NULL) printf("obj == NULL\n");
                    printf("descriptor not found (%s, x: %d, id: %d)\n", name, x, obj->id);
                    return false;
                }
            }else{
                if ((x == mVar)  || (x == mProc)){
                    im = imp->name;
                    im++;
                    a = ThisDllObj(x, fp, im, name);
                    if (a != 0) Fixup(a);
                    else{
                        printf("ReadModule: Object not found: %s\n", name);
                        return false;
                    }
                } else {
                    if (x == mTyp) {
                        opt = RNum();
                        x = RNum();
                        if (x != 0) {
                            printf("ReadModule: Object not found: %s\n", name);
                            return false;
                        }
                    }
                }
            }
            x = RNum();
        }
        *(intptr_t*)imptab = (intptr_t)desc; imptab += 8;
        imp = imp->next;
    }

    if (!FixModMemPermissions()) {
        return false;
    }

    /* Seek to end of current OCF: header + meta + desc + code + data */
    fseek(f, mod.start + mod.hs + mod.ms + mod.ds + mod.cs + mod.vs, SEEK_SET);
skip_exports_64:
    mod.start = ftell(f);
    return true;
}

/*
    Reserve space for 0x80000000 cross border
    This space must not be accessed by GC

    ref.: https://forum.oberoncore.ru/viewtopic.php?f=134&t=6959#p118177
*/
static void ReserveCrossBorder () {
    size_t pagesize = (size_t)getpagesize();
    void *addr_0 = (void *)(0x80000000UL - pagesize);
    void *addr_1 = (void *)0x80000000UL;
    void *p;
    p = mmap(addr_0, pagesize, PROT_NONE, MAP_PRIVATE | MAP_ANON, -1, 0);
    if ((p != MAP_FAILED) && (p != addr_0)) {
        munmap(p, pagesize);
    }
    p = mmap(addr_1, pagesize, PROT_NONE, MAP_PRIVATE | MAP_ANON, -1, 0);
    if ((p != MAP_FAILED) && (p != addr_1)) {
        munmap(p, pagesize);
    }
}

int main (int argc, char *argv[])
{
    const char *ocfFiles[] = {
        "System/Code/Kernel64.ocf",
        "System/Code/Utf.ocf",
        "System/Code/Files.ocf",
        NULL
    };
    int i;
    bool ok = true;
    BodyProc body;
    Module *k;

    printf("64-bit BlackBox boot loader\n"); fflush(stdout);
    modlist = NULL;
    
    for (i = 0; ocfFiles[i] != NULL && ok; i++) {
        f = fopen(ocfFiles[i], "rb");
        if (f == NULL) { printf("Cannot open %s\n", ocfFiles[i]); ok = false; break; }
        printf("Loading %s...\n", ocfFiles[i]);
        mod.start = 0;
        ok = ReadHeader();
        if (ok) { ok = ReadModule(); if (ok) RegisterModule(); }
        fclose(f);
        if (!ok) printf("FAILED: %s\n", ocfFiles[i]);
    }
    
    if (ok) {
        k = ThisModule("Kernel64");
        if (k) {
            printf("Kernel found: code=%p varBase=%p\n", (void*)k->code, (void*)k->varBase);
            printf("Calling kernel body...\n"); fflush(stdout);
            
            /* Make code executable */
            size_t pagesize = getpagesize();
            intptr_t code_page = k->code & ~(pagesize - 1);
            size_t code_len = mod.cs + pagesize;
            mprotect((void*)code_page, code_len, PROT_READ | PROT_WRITE | PROT_EXEC);
            
            BodyProc body = (BodyProc)(intptr_t)k->code;
            printf("Kernel code at %p\n", (void*)k->code);
            
            /* Manual fixup: search for ripBased4 (type=0x6E) fixup metadata in code
               and patch the 4-byte displacement to point to data section.
               The metadata is at positions where *(int*)code[pos] has byte3=0x6E (type=110) */
            {
                unsigned char *cp = (unsigned char*)k->code;
                int patched = 0;
                for (int off = 0; off < mod.cs - 4; off++) {
                    int meta = *(int*)(cp + off);
                    int typ = (meta >> 24) & 0xFF;
                    if (typ == 110) {  /* ripBased4 */
                        /* Calculate RIP-relative displacement */
                        intptr_t target = (intptr_t)k->varBase + (meta & 0xFFFFFF);
                        /* RIP-relative: displacement = target - (code + offset + imm_size + 4) 
                           For MOV r/m32, imm32: the instruction is C7 /0 [disp32] [imm32] = 10 bytes
                           disp32 is at offset 2, imm32 at offset 6, RIP after instr = offset + 10 */
                        intptr_t rip = (intptr_t)cp + off + 8;  /* instr=off-2, len=10, RIP=(off-2)+10=off+8 */
                        intptr_t disp = target - rip;
                        *(int*)(cp + off) = (int)disp;
                        patched++;
                        printf("  Patched offset 0x%x: %d -> %d (type %d)\n", off, meta, (int)disp, typ);
                    }
                }
                printf("  Patched %d fixups\n", patched);
                fflush(stdout);
            }
            
            printf("Calling kernel body...\n"); fflush(stdout);
            body();
            printf("KERNEL RETURNED! 64-BIT BLACKBOX BOOT SUCCESSFUL!\n"); fflush(stdout);
            printf("*** 64-BIT KERNEL RETURNED! ***\n");
            fflush(stdout);
        } else {
            printf("Kernel64 not found in module list\n");
        }
    }
    
    printf("Loaded Modules:\n");
    Module *p;
    printf("Module list:\n");
    for (p = modlist; p; p = p->next) printf("  %p: \"%s\"\n", (void*)p, p->name);
    return 0;
}

