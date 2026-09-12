/* drivers/pci.c — 配置空间访问与枚举 */
#include "../io.h"
#include "../vga.h"

#define PCI_CONF_ADDR 0xCF8
#define PCI_CONF_DATA  0xCFC

static uint32_t pci_addr(uint8_t bus, uint8_t dev, uint8_t func, uint8_t off) {
    return 0x80000000u | ((uint32_t)bus << 16) | ((uint32_t)(dev & 0x1F) << 11) |
           ((uint32_t)(func & 0x07) << 8) | (off & 0xFC);
}

uint32_t pci_read(uint8_t bus, uint8_t dev, uint8_t func, uint8_t off) {
    outl(PCI_CONF_ADDR, pci_addr(bus, dev, func, off));
    return inl(PCI_CONF_DATA);
}

void pci_write(uint8_t bus, uint8_t dev, uint8_t func, uint8_t off, uint32_t v) {
    outl(PCI_CONF_ADDR, pci_addr(bus, dev, func, off));
    outl(PCI_CONF_DATA, v);
}

void pci_scan(void) {
    vga_puts("PCI bus scan:");
    for (uint8_t bus = 0; bus < 8; bus++)
        for (uint8_t dev = 0; dev < 32; dev++) {
            uint32_t id = pci_read(bus, dev, 0, 0);
            if (id == 0xFFFFFFFFu) continue;
            vga_write("  dev "); vga_putc('0' + dev); vga_putc('\n');
        }
}
