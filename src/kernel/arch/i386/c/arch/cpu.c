/* arch/cpu.c — CPU 特性识别（CPUID） */
#include "../vga.h"
#include "../string.h"

uint32_t cpu_edx_features;

void cpu_detect(void) {
    uint32_t eax, ebx, ecx, edx;
    char vendor[13];
    __asm__ volatile("cpuid"
        : "=a"(eax), "=b"(ebx), "=c"(ecx), "=d"(edx) : "a"(0));
    *(uint32_t *)(vendor + 0) = ebx;
    *(uint32_t *)(vendor + 4) = edx;
    *(uint32_t *)(vendor + 8) = ecx;
    vendor[12] = 0;
    vga_write("CPU vendor: ");
    vga_write(vendor);
    vga_puts("");

    __asm__ volatile("cpuid"
        : "=d"(cpu_edx_features) : "a"(1) : "ebx", "ecx");
    vga_write("EDX features: 0x");
    for (int i = 28; i >= 0; i -= 4)
        vga_putc("0123456789ABCDEF"[(cpu_edx_features >> i) & 0xF]);
    vga_puts("");
}
