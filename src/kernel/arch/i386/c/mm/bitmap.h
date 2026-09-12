/* mm/bitmap.h — 位图操作辅助 */
#ifndef LPYDOS_MM_BITMAP_H
#define LPYDOS_MM_BITMAP_H
#include <stdint.h>

void bitmap_set(uint8_t *map, uint32_t bit);
void bitmap_clear(uint8_t *map, uint32_t bit);
int  bitmap_test(const uint8_t *map, uint32_t bit);

#endif
