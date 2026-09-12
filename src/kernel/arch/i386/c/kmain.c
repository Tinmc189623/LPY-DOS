/* ============================================================================
 *  kmain.c — 386 保护模式扩展 C 运行时入口
 *  由 ext32.asm 在进入 32 位 flat 保护模式后调用。
 *  职责：初始化 VGA/串口，打印横幅与探测信息。
 *  仅运行于 32 位保护模式；16 位实模式内核不链接本文件。
 * ==========================================================================*/
#include "vga.h"
#include "serial.h"

extern char _kernel_start[];   /* 链接脚本提供：扩展加载起始地址 */

static void put_uint(unsigned int v, unsigned int base) {
    static const char *dig = "0123456789abcdef";
    char buf[12]; int i = 0;
    if (v == 0) { vga_putc('0'); return; }
    while (v) { buf[i++] = dig[v % base]; v /= base; }
    while (i) vga_putc(buf[--i]);
}

void kmain(void) {
    vga_init();
    serial_init();

    vga_setcolor(VGA_LIGHT_GREEN, VGA_BLACK);
    vga_puts("LPY-DOS 386 Protected-Mode Extension");
    vga_setcolor(VGA_WHITE, VGA_BLACK);
    vga_puts("Running in 32-bit flat protected mode.");
    vga_write("Extension base: 0x");
    put_uint((unsigned int)(unsigned long)_kernel_start, 16);
    vga_puts("");
    vga_puts("C runtime: VGA + serial ready.");

    serial_write("[lpy32] kmain entered\n");

    for (;;) { __asm__ volatile ("hlt"); }
}
