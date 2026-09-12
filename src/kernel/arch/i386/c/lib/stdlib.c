/* lib/stdlib.c — 简易标准库：atoi / itoa / rand */
#include <stdint.h>

static uint32_t rng = 12345;

int atoi(const char *s) {
    int n = 0, sign = 1;
    while (*s == ' ' || *s == '\t') s++;
    if (*s == '-') { sign = -1; s++; }
    while (*s >= '0' && *s <= '9') { n = n * 10 + (*s - '0'); s++; }
    return n * sign;
}

char *itoa(int v, char *buf, int base) {
    static const char *d = "0123456789abcdef";
    char tmp[16]; int i = 0, neg = 0;
    if (v < 0 && base == 10) { neg = 1; v = -v; }
    if (!v) tmp[i++] = '0';
    while (v) { tmp[i++] = d[v % base]; v /= base; }
    char *o = buf;
    if (neg) *o++ = '-';
    while (i) *o++ = tmp[--i];
    *o = 0;
    return buf;
}

int rand(void) {
    rng = rng * 1103515245u + 12345u;
    return (int)((rng >> 16) & 0x7FFF);
}

void srand(uint32_t seed) { rng = seed; }
