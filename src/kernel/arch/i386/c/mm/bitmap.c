/* mm/bitmap.c — 位图操作实现 */
#include "bitmap.h"

void bitmap_set(uint8_t *map, uint32_t bit)   { map[bit / 8] |=  (1 << (bit % 8)); }
void bitmap_clear(uint8_t *map, uint32_t bit) { map[bit / 8] &= ~(1 << (bit % 8)); }
int  bitmap_test(const uint8_t *map, uint32_t bit) { return (map[bit / 8] >> (bit % 8)) & 1; }
