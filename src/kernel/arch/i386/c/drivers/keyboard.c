/* drivers/keyboard.c — PS/2 键盘驱动（IRQ1） */
#include "../io.h"
#include "../vga.h"

#define KBD_DATA 0x60
#define KBD_STAT 0x64

static const char keymap[128] = {
    0,  27, '1','2','3','4','5','6','7','8','9','0','-','=', '\b',
    '\t','q','w','e','r','t','y','u','i','o','p','[',']','\n',
    0, 'a','s','d','f','g','h','j','k','l',';','\'','`',
    0, '\\','z','x','c','v','b','n','m',',','.','/', 0, '*',
    0, ' ', 0
};

static char kbd_last;

char keyboard_getchar(void) {
    if (!(inb(KBD_STAT) & 0x01)) return 0;
    uint8_t sc = inb(KBD_DATA);
    if (sc & 0x80) { kbd_last = 0; return 0; }
    kbd_last = keymap[sc & 0x7F];
    return kbd_last;
}

void keyboard_init(void) { kbd_last = 0; }
