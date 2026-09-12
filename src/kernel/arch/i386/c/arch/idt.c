/* arch/idt.c — 中断描述符表 */
#include <stdint.h>

struct idt_entry {
    uint16_t offset_low;
    uint16_t selector;
    uint8_t  zero;
    uint8_t  type_attr;
    uint16_t offset_high;
} __attribute__((packed));

struct idt_ptr { uint16_t limit; uint32_t base; } __attribute__((packed));

static struct idt_entry idt[256];
static struct idt_ptr   idtp;

void idt_set(int i, uint32_t handler, uint16_t sel, uint8_t flags) {
    idt[i].offset_low  = (uint16_t)(handler & 0xFFFF);
    idt[i].offset_high = (uint16_t)((handler >> 16) & 0xFFFF);
    idt[i].selector    = sel;
    idt[i].zero         = 0;
    idt[i].type_attr    = flags;
}

void idt_init(void) {
    for (int i = 0; i < 256; i++) idt_set(i, 0, 0x08, 0x8E);
    idtp.limit = sizeof(idt) - 1;
    idtp.base  = (uint32_t)&idt;
    __asm__ volatile("lidt %0" : : "m"(idtp));
}
