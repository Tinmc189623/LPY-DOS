/* ============================================================================
 *  c/string.c — LPY-DOS 32 位内核 C 运行时辅助（脚手架）
 *  主体仍为 FASM 汇编；C 仅用于 386 保护模式下的薄运行时辅助
 *  （字符串/内存搬运），由汇编入口调用。
 *
 *  工具链（任选其一，未安装时不参与 build.ps1）：
 *    i386-elf-gcc -ffreestanding -m32 -c string.c -o string.o
 *    或 OpenWatcom: wcc386 string.c
 *  产出 .o 后由 FASM/include 链接进 32 位内核镜像。
 * ==========================================================================*/

void *memset(void *d, int c, unsigned long n) {
    unsigned char *p = (unsigned char *)d;
    while (n--) *p++ = (unsigned char)c;
    return d;
}

void *memcpy(void *d, const void *s, unsigned long n) {
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
