/* console/kprintf.c — 内核格式化输出（支持 %s %c %d %x %p %%） */
#include "../vga.h"
#include "../serial.h"

static void emit(char c) { vga_putc(c); serial_putc(c); }

static void print_uint(unsigned int v, unsigned int base, int upper) {
    static const char *d = "0123456789abcdef";
    static const char *D = "0123456789ABCDEF";
    char buf[12]; int i = 0;
    if (!v) { emit('0'); return; }
    while (v) { buf[i++] = (upper ? D : d)[v % base]; v /= base; }
    while (i) emit(buf[--i]);
}

static void print_int(int v) {
    if (v < 0) { emit('-'); print_uint((unsigned int)(-v), 10, 0); }
    else print_uint((unsigned int)v, 10, 0);
}

void kprintf(const char *fmt, ...) {
    __builtin_va_list ap;
    __builtin_va_start(ap, fmt);
    for (; *fmt; fmt++) {
        if (*fmt != '%') { emit(*fmt); continue; }
        fmt++;
        switch (*fmt) {
        case 's': { const char *s = __builtin_va_arg(ap, const char *);
                    while (*s) emit(*s++); break; }
        case 'c': emit((char)__builtin_va_arg(ap, int)); break;
        case 'd': print_int(__builtin_va_arg(ap, int)); break;
        case 'u': print_uint(__builtin_va_arg(ap, unsigned int), 10, 0); break;
        case 'x': print_uint(__builtin_va_arg(ap, unsigned int), 16, 0); break;
        case 'X': print_uint(__builtin_va_arg(ap, unsigned int), 16, 1); break;
        case 'p': emit('0'); emit('x');
                  print_uint((unsigned int)__builtin_va_arg(ap, void *), 16, 0); break;
        case '%': emit('%'); break;
        default: emit(*fmt); break;
        }
    }
    __builtin_va_end(ap);
}
