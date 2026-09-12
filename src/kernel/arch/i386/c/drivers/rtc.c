/* drivers/rtc.c — CMOS/RTC 实时时钟读取 */
#include "../io.h"

#define CMOS_ADDR 0x70
#define CMOS_DATA 0x71

static uint8_t cmos_read(uint8_t reg) {
    outb(CMOS_ADDR, reg);
    return inb(CMOS_DATA);
}

static uint8_t bcd2bin(uint8_t v) { return (v & 0x0F) + ((v >> 4) * 10); }

void rtc_read(uint16_t *year, uint8_t *mon, uint8_t *day,
              uint8_t *hour, uint8_t *min, uint8_t *sec) {
    while (cmos_read(0x0A) & 0x80) { }   /* 更新中 */
    *sec  = bcd2bin(cmos_read(0x00));
    *min  = bcd2bin(cmos_read(0x02));
    *hour = bcd2bin(cmos_read(0x04));
    *day  = bcd2bin(cmos_read(0x07));
    *mon  = bcd2bin(cmos_read(0x08));
    *year = 2000 + bcd2bin(cmos_read(0x09));
}
