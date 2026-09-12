/* mm/pmm.c — 物理内存位图分配器 */
#include "../string.h"
#include "bitmap.h"

#define PAGE_SIZE 4096
#define MAX_PAGES (1024 * 1024 * 1024 / PAGE_SIZE / 8)

static uint32_t mem_end_pages;
static uint8_t pmm_map[MAX_PAGES / 8];

void pmm_init(uint32_t mem_bytes) {
    mem_end_pages = mem_bytes / PAGE_SIZE;
    memset(pmm_map, 0xFF, (mem_end_pages + 7) / 8);  /* 先标记全部已占 */
}

void pmm_mark_free(uint32_t page) {
    if (page < mem_end_pages) pmm_map[page / 8] &= ~(1 << (page % 8));
}

uint32_t pmm_alloc_page(void) {
    for (uint32_t i = 0; i < mem_end_pages / 8; i++) {
        if (pmm_map[i] != 0xFF) {
            for (int b = 0; b < 8; b++) {
                if (!(pmm_map[i] & (1 << b))) {
                    pmm_map[i] |= (1 << b);
                    return i * 8 + b;
                }
            }
        }
    }
    return 0xFFFFFFFFu;
}

void pmm_free_page(uint32_t page) {
    if (page < mem_end_pages) pmm_map[page / 8] &= ~(1 << (page % 8));
}
