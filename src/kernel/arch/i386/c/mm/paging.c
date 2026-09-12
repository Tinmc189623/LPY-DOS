/* mm/paging.c — 二级页表（4KB 页，32 位） */
#include "../string.h"

#define PAGE_PRESENT 1
#define PAGE_WRITE   2

typedef uint32_t pde_t;
typedef uint32_t pte_t;

static pde_t page_directory[1024] __attribute__((aligned(4096)));
static pte_t  page_table0[1024] __attribute__((aligned(4096)));

void paging_init(void) {
    memset(page_directory, 0, sizeof(page_directory));
    memset(page_table0, 0, sizeof(page_table0));
    for (int i = 0; i < 1024; i++)
        page_table0[i] = ((i * 4096) | PAGE_PRESENT | PAGE_WRITE);
    page_directory[0] = ((uint32_t)page_table0 | PAGE_PRESENT | PAGE_WRITE);
    /* 其余 PDE 暂留空 */
}

void paging_enable(void) {
    uint32_t cr0;
    __asm__ volatile("mov %%cr0, %0" : "=r"(cr0));
    cr0 |= 0x80000000u;
    __asm__ volatile("mov %0, %%cr0" : : "r"(cr0));
}
