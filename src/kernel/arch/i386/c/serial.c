/* serial.c — COM1 (0x3F8) 115200 8N1 调试串口 */
#include "serial.h"
#include "io.h"

void serial_init(void) {
    outb(COM1 + 1, 0x00);   /* 关闭中断 */
    outb(COM1 + 3, 0x80);   /* 开启 DLAB */
    outb(COM1 + 0, 0x03);   /* 除数锁存低：3 = 38400 */
    outb(COM1 + 1, 0x00);   /* 高字节 0 */
    outb(COM1 + 3, 0x03);   /* 8N1 */
    outb(COM1 + 2, 0xC7);   /* FIFO，14 字节触发 */
    outb(COM1 + 4, 0x0B);   /* RTS/DSR，开 OUT2 */
    (void)inb(COM1);        /* 清空接收 */
}

static int tx_ready(void) { return inb(COM1 + 5) & 0x20; }

void serial_putc(char c) {
    while (!tx_ready()) { }
    outb(COM1, (uint8_t)c);
}

void serial_write(const char *s) {
    while (*s) {
        if (*s == '\n') serial_putc('\r');
        serial_putc(*s++);
    }
}
