/* A growable array of integers: the capacity doubles when it runs out. */

#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int *items;
    size_t length;
    size_t capacity;
} IntArray;

static int array_push(IntArray *array, int value)
{
    if (array->length == array->capacity) {
        size_t capacity = array->capacity == 0 ? 4 : array->capacity * 2;
        int *grown = realloc(array->items, capacity * sizeof(int));

        if (grown == NULL) {
            return 0; /* the old buffer is still valid and still owned */
        }
        array->items = grown;
        array->capacity = capacity;
    }
    array->items[array->length++] = value;
    return 1;
}

static void array_free(IntArray *array)
{
    free(array->items);
    array->items = NULL;
    array->length = 0;
    array->capacity = 0;
}

int main(void)
{
    IntArray array = {NULL, 0, 0};

    for (int i = 0; i < 10; i++) {
        if (!array_push(&array, i * i)) {
            fprintf(stderr, "out of memory\n");
            array_free(&array);
            return 1;
        }
    }

    printf("length %zu, capacity %zu\n", array.length, array.capacity);
    for (size_t i = 0; i < array.length; i++) {
        printf("%d ", array.items[i]);
    }
    printf("\n");

    array_free(&array);
    return 0;
}
