/* A circular buffer of fixed capacity: writes wrap around, reads follow. */

#include <stdio.h>
#include <stdbool.h>
#include <stddef.h>

#define CAPACITY 8

typedef struct {
    int items[CAPACITY];
    size_t head;  /* next slot to read */
    size_t count; /* how many slots hold a value */
} RingBuffer;

static bool ring_push(RingBuffer *ring, int value)
{
    if (ring->count == CAPACITY) {
        return false;
    }
    ring->items[(ring->head + ring->count) % CAPACITY] = value;
    ring->count++;
    return true;
}

static bool ring_pop(RingBuffer *ring, int *out)
{
    if (ring->count == 0) {
        return false;
    }
    *out = ring->items[ring->head];
    ring->head = (ring->head + 1) % CAPACITY;
    ring->count--;
    return true;
}

int main(void)
{
    RingBuffer ring = {{0}, 0, 0};

    for (int i = 1; i <= 10; i++) {
        printf("push %2d -> %s\n", i, ring_push(&ring, i) ? "ok" : "full");
    }

    int value = 0;
    while (ring_pop(&ring, &value)) {
        printf("pop %d\n", value);
    }
    return 0;
}
