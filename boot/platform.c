/* The part of t-metal's platform T can't write yet: memory
 * (docs/39-freestanding.md, docs/40-extern.md of t-lang). The runtime gets
 * its blocks from `t_platform_alloc`, `t_platform_realloc` and
 * `t_platform_free`, which hand out the heap the linker script sets aside;
 * and the C compiler calls `memcpy`, `memmove`, `memset` and `memcmp` on
 * its own. T's `heap` module reads how the heap is doing through the
 * `heap_*` functions at the end.
 *
 * The heap is a free list per size class: a block of class k is 16 << k
 * bytes, so every block is aligned to 16, which is `_Alignof(max_align_t)`
 * here, the most the runtime asks for. A block that's freed goes on its
 * class's list, to be handed out again; a class with none free takes the
 * next bytes of the heap no block has had yet. The runtime gives back each
 * block's size, so no block needs a header. Nothing here is safe to call
 * from an interrupt: T's `trap` doesn't allocate. */
#include <stddef.h>
#include <stdint.h>

extern unsigned char _heap_start[], _heap_end[];

#define CLASSES 32

/* The blocks of each class that are free: each holds the next. */
static void *free_blocks[CLASSES];
/* Where the heap no block has had yet starts. */
static unsigned char *fresh = _heap_start;
/* Bytes asked for in blocks not given back, the most there ever were,
 * and how many such blocks. */
static size_t used, peak, live;

static unsigned class_of(size_t size) {
    unsigned k = 0;
    while (k < CLASSES && ((size_t)16 << k) < size) k++;
    return k;
}

static void *take(unsigned k) {
    if (k >= CLASSES) return NULL;
    void *p = free_blocks[k];
    if (p) {
        free_blocks[k] = *(void **)p;
        return p;
    }
    size_t n = (size_t)16 << k;
    if ((size_t)(_heap_end - fresh) < n) return NULL;
    p = fresh;
    fresh += n;
    return p;
}

static void give(void *p, unsigned k) {
    *(void **)p = free_blocks[k];
    free_blocks[k] = p;
}

void *t_platform_alloc(size_t size, size_t align) {
    (void)align;
    void *p = take(class_of(size));
    if (!p) return NULL;
    used += size;
    live++;
    if (used > peak) peak = used;
    return p;
}

void *memcpy(void *restrict dst, const void *restrict src, size_t n);

void *t_platform_realloc(void *p, size_t size, size_t align, size_t new_size) {
    (void)align;
    unsigned k = class_of(size), new_k = class_of(new_size);
    void *q = p;
    if (new_k != k) {
        q = take(new_k);
        if (!q) return NULL;
        memcpy(q, p, size < new_size ? size : new_size);
        give(p, k);
    }
    used = used - size + new_size;
    if (used > peak) peak = used;
    return q;
}

void t_platform_free(void *p, size_t size, size_t align) {
    (void)align;
    give(p, class_of(size));
    used -= size;
    live--;
}

size_t heap_size(void) { return (size_t)(_heap_end - _heap_start); }
size_t heap_touched(void) { return (size_t)(fresh - _heap_start); }
size_t heap_used(void) { return used; }
size_t heap_peak(void) { return peak; }
size_t heap_live(void) { return live; }

/* What C compilers call on their own. This file is compiled with
 * -ffreestanding, so these loops stay loops, not calls of themselves. */

void *memcpy(void *restrict dst, const void *restrict src, size_t n) {
    unsigned char *d = dst;
    const unsigned char *s = src;
    for (size_t i = 0; i < n; i++) d[i] = s[i];
    return dst;
}

void *memmove(void *dst, const void *src, size_t n) {
    unsigned char *d = dst;
    const unsigned char *s = src;
    if (d < s) {
        for (size_t i = 0; i < n; i++) d[i] = s[i];
    } else {
        for (size_t i = n; i > 0; i--) d[i - 1] = s[i - 1];
    }
    return dst;
}

void *memset(void *dst, int c, size_t n) {
    unsigned char *d = dst;
    for (size_t i = 0; i < n; i++) d[i] = (unsigned char)c;
    return dst;
}

int memcmp(const void *a, const void *b, size_t n) {
    const unsigned char *x = a, *y = b;
    for (size_t i = 0; i < n; i++) {
        if (x[i] != y[i]) return x[i] < y[i] ? -1 : 1;
    }
    return 0;
}
