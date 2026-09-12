/* vga.c — VGA 文本模式驱动实现 */
#include "vga.h"
#include "io.h"

#define VGA_ROWS 25
#define VGA_COLS 80
static volatile uint16_t *const VGA_MEM = (uint16_t *)0xB8000;

static size_t vga_row, vga_col;
static uint8_t vga_attr;

static inline uint16_t cell(char ch, uint8_t attr) {
    return (uint16_t)(unsigned char)ch | ((uint16_t)attr << 8);
}

void vga_setcolor(uint8_t fg, uint8_t bg) {
    vga_attr = (uint8_t)((bg << 4) | (fg & 0x0F));
}

static void vga_newline(void) {
    vga_col = 0;
    if (++vga_row >= VGA_ROWS) vga_row = VGA_ROWS - 1;
}

static void vga_scroll(void) {
    for (size_t r = 1; r < VGA_ROWS; r++)
        for (size_t c = 0; c < VGA_COLS; c++)
            VGA_MEM[(r - 1) * VGA_COLS + c] = VGA_MEM[r * VGA_COLS + c];
    for (size_t c = 0; c < VGA_COLS; c++)
        VGA_MEM[(VGA_ROWS - 1) * VGA_COLS + c] = cell(' ', vga_attr);
    vga_row = VGA_ROWS - 1;
}

void vga_clear(void) {
    vga_row = 0; vga_col = 0;
    for (size_t i = 0; i < VGA_ROWS * VGA_COLS; i++)
        VGA_MEM[i] = cell(' ', vga_attr);
}

void vga_init(void) {
    vga_setcolor(VGA_LIGHT_GREY, VGA_BLACK);
    vga_clear();
}

void vga_putc(char c) {
    if (c == '\n') { vga_newline(); return; }
    if (c == '\r') { vga_col = 0; return; }
    if (c == '\b') { if (vga_col) vga_col--; return; }
    VGA_MEM[vga_row * VGA_COLS + vga_col] = cell(c, vga_attr);
    if (++vga_col >= VGA_COLS) vga_newline();
    if (vga_row >= VGA_ROWS) vga_scroll();
}

void vga_write(const char *s) { while (*s) vga_putc(*s++); }
void vga_puts(const char *s) { vga_write(s); vga_write("\n"); }
