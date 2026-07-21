#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

static int Read4() {
    unsigned char b; int w;
    b = getchar(); w = b % 256;
    b = getchar(); w += 0x100 * (b % 256);
    b = getchar(); w += 0x10000 * (b % 256);
    b = getchar(); w += 0x1000000 * b;
    return w;
}

static void ReadName(char* str) {
    for(int i=0; i<256; i++) {
        int ch = getchar();
        str[i] = ch;
        if(ch == 0) return;
    }
}

int main() {
    printf("START\n"); fflush(stdout);
    
    // Read boot header from stdin
    int tag = Read4();
    printf("tag: 0x%08X\n", tag);
    if(tag != 0x3A4B5C6D) { printf("BAD TAG\n"); return 1; }
    
    int ver = Read4();
    printf("ver: %d\n", ver);
    
    int nof = Read4();
    printf("mods: %d\n", nof);
    
    char kernel[256]={0}, mainmod[256]={0};
    ReadName(kernel);
    printf("kernel: %s\n", kernel);
    ReadName(mainmod);
    printf("main: %s\n", mainmod);
    
    int fp1=Read4(), fp2=Read4();
    printf("fp: %d %d\n", fp1, fp2);
    
    // Read OCF header
    int ofTag = Read4();
    printf("ofTag: 0x%08X %s\n", ofTag, ofTag==0x6F4F4346?"OK":"BAD");
    
    int processor = Read4();
    printf("processor: %d\n", processor);
    
    return 0;
}
