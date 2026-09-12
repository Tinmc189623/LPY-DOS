/* drivers/timer.c — PIT 8253 系统节拍定时器（IRQ0） */
#include "../io.h"

#define PIT_CH0 0x40
#define PIT_CMD  0x43

static volatile uint32_t ticks;
static uint32_t hz;

void timer_init(uint32_t hz_) {
    hz = hz_ ? hz_ : 100;
    uint32_t divisor = 1193182 / hz;
    outb(PIT_CMD, 0x36);
    outb(PIT_CH0, (uint8_t)(divisor & 0xFF));
    outb(PIT_CH0, (uint8_t)((divisor >> 8) & 0xFF));
    ticks = 0;
}

void timer_tick(void) { ticks++; }

uint32_t timer_ticks(void) { return ticks; }
uint32_t timer_hz(void)    { return hz; }

void timer_sleep_ms(uint32_t ms) {
    uint32_t target = ticks + (ms * hz / 1000);
    while (ticks < target) { __asm__ volatile ("hlt"); }
}
