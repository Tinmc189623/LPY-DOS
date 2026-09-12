/* mm/kheap.c — 内核堆（空闲链表 first-fit） */
#include "../string.h"

typedef struct block {
    struct block *next;
    uint32_t size;
    int used;
} block_t;

static block_t *heap_head;

void kheap_init(void *start, uint32_t size) {
    heap_head = (block_t *)start;
    heap_head->next = 0;
    heap_head->size = size - sizeof(block_t);
    heap_head->used = 0;
}

void *kmalloc(uint32_t bytes) {
    block_t *b = heap_head;
    while (b) {
        if (!b->used && b->size >= bytes) {
            b->used = 1;
            return (void *)((char *)b + sizeof(block_t));
        }
        b = b->next;
    }
    return 0;
}

void kfree(void *p) {
    block_t *b = (block_t *)((char *)p - sizeof(block_t));
    b->used = 0;
}
