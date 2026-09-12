/* arch/gdt.c — 全局描述符表加载 */
#include <stdint.h>

struct gdt_entry {
    uint16_t limit_low;
    uint16_t base_low;
    uint8_t  base_mid;
    uint8_t  access;
    uint8_t  granularity;
    uint8_t  base_high;
} __attribute__((packed));

struct gdt_ptr {
    uint16_t limit;
    uint32_t base;
} __attribute__((packed));

static struct gdt_entry gdt[5];
static struct gdt_ptr   gdtp;

static void gdt_set(int i, uint32_t base, uint32_t limit, uint8_t access, uint8_t gran) {
    gdt[i].base_low  = (uint16_t)(base & 0xFFFF);
    gdt[i].base_mid  = (uint8_t)((base >> 16) & 0xFF);
    gdt[i].base_high = (uint8_t)((base >> 24) & 0xFF);
    gdt[i].limit_low = (uint16_t)(limit & 0xFFFF);
    gdt[i].granularity = (uint8_t)(((limit >> 16) & 0x0F) | (gran & 0xF0));
    gdt[i].access = access;
}

void gdt_init(void) {
    gdt_set(0, 0, 0, 0, 0);                 /* null */
    gdt_set(1, 0, 0xFFFFF, 0x9A, 0xCF);     /* code 32 */
    gdt_set(2, 0, 0xFFFFF, 0x92, 0xCF);     /* data 32 */
    gdt_set(3, 0, 0xFFFFF, 0xFA, 0xCF);     /* user code */
    gdt_set(4, 0, 0xFFFFF, 0xF2, 0xCF);     /* user data */
    gdtp.limit = sizeof(gdt) - 1;
    gdtp.base  = (uint32_t)&gdt;
    __asm__ volatile("lgdt %0" : : "m"(gdtp));
}
