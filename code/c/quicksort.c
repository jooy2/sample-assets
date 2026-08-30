/* Quicksort with Lomuto partitioning, sorting in place. */

#include <stdio.h>
#include <stddef.h>

static void swap(int *a, int *b)
{
    int held = *a;
    *a = *b;
    *b = held;
}

/* Moves everything below the pivot to its left and returns the pivot's index. */
static int partition(int *values, int low, int high)
{
    int pivot = values[high];
    int boundary = low - 1;

    for (int i = low; i < high; i++) {
        if (values[i] <= pivot) {
            boundary++;
            swap(&values[boundary], &values[i]);
        }
    }
    swap(&values[boundary + 1], &values[high]);
    return boundary + 1;
}

static void quicksort(int *values, int low, int high)
{
    if (low >= high) {
        return;
    }
    int pivot = partition(values, low, high);
    quicksort(values, low, pivot - 1);
    quicksort(values, pivot + 1, high);
}

int main(void)
{
    int values[] = {29, 10, 14, 37, 13, 5, 91, 42, 8};
    const int length = (int)(sizeof(values) / sizeof(values[0]));

    quicksort(values, 0, length - 1);

    for (int i = 0; i < length; i++) {
        printf("%d%s", values[i], i + 1 == length ? "\n" : " ");
    }
    return 0;
}
