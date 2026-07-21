#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

static int Read4(unsigned char *b) {
    return b[0] | (b[1] << 8) | (b[2] << 16) | (b[3] << 24);
}

int main() {
    printf("BlackBox 64-bit boot loader v2\n");
    
    FILE* ocf = fopen("System/Code/Kernel64.ocf", "rb");
    if (!ocf) { printf("Cannot open Kernel64.ocf\n"); return 1; }
    
    fseek(ocf, 0, SEEK_END);
    long sz = ftell(ocf);
    fseek(ocf, 0, SEEK_SET);
    printf("OCF: %ld bytes\n", sz);
    
    unsigned char buf[256];
    fread(buf, 1, 16, ocf);
    int tag = Read4(buf);
    int proc = Read4(buf+4);
    int hs = Read4(buf+8);
    int ms = Read4(buf+12);
    
    printf("Tag:       0x%08X %s\n", tag, tag==0x6F4F4346 ? "OK" : "BAD");
    printf("Processor: %d (i386=10, amd64=12)\n", proc);
    printf("Header sz: %d\n", hs);
    printf("Meta sz:   %d\n", ms);
    
    fclose(ocf);
    return 0;
}
