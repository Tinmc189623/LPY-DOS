/* console/tty.c — 虚拟终端（封装 VGA，行缓冲 + 回显） */
#include "../vga.h"

void tty_init(void) { vga_init(); vga_puts("LPY32 TTY ready\n"); }
void tty_putc(char c) { vga_putc(c); }
void tty_puts(const char *s) { vga_puts(s); }
void tty_clear(void) { vga_clear(); }
void tty_setcolor(uint8_t fg, uint8_t bg) { vga_setcolor(fg, bg); }
