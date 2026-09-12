/* lib/vsnprintf.c — 受限版本号到缓冲（无浮点） */
#include <stddef.h>
#include <stdint.h>

int vsnprintf(char *buf, size_t n, const char *fmt, __builtin_va_list ap) {
    size_t i = 0;
    for (; *fmt && i + 1 < n; fmt++) {
        if (*fmt != '%') { buf[i++] = *fmt; continue; }
        fmt++;
        switch (*fmt) {
        case 'd': { int v = __builtin_va_arg(ap, int);
                   if (v < 0) { buf[i++] = '-'; v = -v; }
                   char tmp[12]; int j = 0;
                   if (!v) tmp[j++] = '0';
                   while (v) { tmp[j++] = '0' + v % 10; v /= 10; }
                   while (j && i + 1 < n) buf[i++] = tmp[--j];
                   break; }
        case 'x': { unsigned v = __builtin_va_arg(ap, unsigned);
                   char tmp[8]; int j = 0;
                   static const char *d = "0123456789abcdef";
                   while (v) { tmp[j++] = d[v & 0xF]; v >>= 4; }
                   while (j && i + 1 < n) buf[i++] = tmp[--j];
                   break; }
        case 's': { const char *s = __builtin_va_arg(ap, const char *);
                   while (*s && i + 1 < n) buf[i++] = *s++;
                   break; }
        default: buf[i++] = *fmt; break;
        }
    }
    buf[i] = 0;
    return (int)i;
}
