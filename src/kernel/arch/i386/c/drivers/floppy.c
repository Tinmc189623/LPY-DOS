/* drivers/floppy.c — 软盘子系统（1.44MB，DMA 传输占位） */
#include "../io.h"

#define FDC_DOR 0x3F2
#define FDC_MSR 0x3F4
#define FDC_DATA 0x3F5
#define FDC_DIR 0x3F7

void floppy_reset(void) {
    outb(FDC_DOR, 0x00); io_wait();
    outb(FDC_DOR, 0x0C); io_wait();       /* 启动 FDC，开 DMA */
}

int floppy_wait_irq(void) { return 1; }        /* TODO: 接 IRQ6 */

int floppy_read(uint8_t chs_track, uint8_t head, uint8_t sector, void *buf) {
    (void)chs_track; (void)head; (void)sector; (void)buf;
    return 0;                                 /* TODO: DMA + 指令序列 */
}
