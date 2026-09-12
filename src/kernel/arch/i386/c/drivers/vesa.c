/* drivers/vesa.c — VESA BIOS 显示模式切换（保护模式下经 INT 10H 占位） */
#include "../vga.h"

static uint16_t vesa_mode;

void vesa_set_mode(uint16_t mode) {
    vesa_mode = mode;
    /* TODO: 在实模式跳板中调用 INT 10H AX=4F02H；此处先清屏提示 */
    vga_clear();
    vga_write("VESA mode requested: ");
    for (int i = 12; i >= 0; i -= 4)
        vga_putc("0123456789ABCDEF"[(mode >> i) & 0xF]);
    vga_puts(" (needs real-mode call)");
}

uint16_t vesa_get_mode(void) { return vesa_mode; }
