/* string.h — 内存/字符串运行时 */
#ifndef LPYDOS_STRING_H
#define LPYDOS_STRING_H
#include <stddef.h>

void  *memset(void *d, int c, size_t n);
void  *memcpy(void *d, const void *s, size_t n);
int    strlen(const char *s);
int    strcmp(const char *a, const char *b);
char  *strcpy(char *d, const char *s);

#endif
