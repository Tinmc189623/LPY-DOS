/* arch/irq.c — 8259A 中断控制器重映射与 EOI */
#include "../io.h"

#define PIC1_CMD 0x20
#define PIC1_DAT 0x21
#define PIC2_CMD 0xA0
#define PIC2_DAT 0xA1

void irq_remap(void) {
    outb(PIC1_CMD, 0x11); io_wait();
    outb(PIC2_CMD, 0x11); io_wait();
    outb(PIC1_DAT, 0x20); io_wait();   /* 主片基 0x20 */
    outb(PIC2_DAT, 0x28); io_wait();   /* 从片基 0x28 */
    outb(PIC1_DAT, 0x04); io_wait();
    outb(PIC2_DAT, 0x02); io_wait();
    outb(PIC1_DAT, 0x01); io_wait();
    outb(PIC2_DAT, 0x01); io_wait();
    outb(PIC1_DAT, 0x00);
    outb(PIC2_DAT, 0x00);
}

void irq_eoi(int irq) {
    if (irq >= 8) outb(PIC2_CMD, 0x20);
    outb(PIC1_CMD, 0x20);
}

void irq_enable(void) { __asm__ volatile ("sti"); }
void irq_disable(void) { __asm__ volatile ("cli"); }
