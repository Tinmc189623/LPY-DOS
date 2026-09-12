/* arch/isr.c — CPU 异常中断服务例程（C 部分） */
#include "../vga.h"
#include "../serial.h"

static const char *exc_msgs[] = {
    "Divide-by-zero", "Debug", "NMI", "Breakpoint",
    "Overflow", "BOUND range", "Invalid opcode", "Device unavailable",
    "Double fault", "Coprocessor segment", "Invalid TSS", "Segment not present",
    "Stack fault", "General protection", "Page fault", "Reserved"
};

void isr_handler(int exc_no, uint32_t error_code) {
    vga_setcolor(0x04, 0);
    vga_puts("\n*** EXCEPTION ***");
    if (exc_no >= 0 && exc_no < 16)
        vga_write(exc_msgs[exc_no]);
    vga_putc(' ');
    vga_write("err=");
    for (int i = 28; i >= 0; i -= 4)
        vga_putc("0123456789ABCDEF"[(error_code >> i) & 0xF]);
    serial_write("\n[kpanic] exception\n");
    for (;;) __asm__ volatile ("hlt");
}
