/* string.c — 内存/字符串运行时实现 */
#include "string.h"

void *memset(void *d, int c, size_t n) {
    unsigned char *p = (unsigned char *)d;
    while (n--) *p++ = (unsigned char)c;
    return d;
}

void *memcpy(void *d, const void *s, size_t n) {
    unsigned char *pd = (unsigned char *)d;
    const unsigned char *ps = (const unsigned char *)s;
    while (n--) *pd++ = *ps++;
    return d;
}

int strlen(const char *s) {
    int n = 0;
    while (s[n]) n++;
    return n;
}

int strcmp(const char *a, const char *b) {
    while (*a && (*a == *b)) { a++; b++; }
    return (unsigned char)*a - (unsigned char)*b;
}

char *strcpy(char *d, const char *s) {
    char *o = d;
    while ((*d++ = *s++)) { }
    return o;
}
