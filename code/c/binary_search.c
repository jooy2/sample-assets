/* Iterative binary search over a sorted array of integers. */

#include <stdio.h>
#include <stddef.h>

/* Returns the index of `needle`, or -1 when it is not in the array. */
static int binary_search(const int *values, size_t length, int needle)
{
    size_t low = 0;
    size_t high = length;

    while (low < high) {
        size_t middle = low + (high - low) / 2; /* avoids overflow */

        if (values[middle] == needle) {
            return (int)middle;
        }
        if (values[middle] < needle) {
            low = middle + 1;
        } else {
            high = middle;
        }
    }
    return -1;
}

int main(void)
{
    const int sorted[] = {2, 5, 8, 12, 16, 23, 38, 56, 72, 91};
    const size_t length = sizeof(sorted) / sizeof(sorted[0]);
    const int wanted[] = {23, 2, 91, 42};

    for (size_t i = 0; i < sizeof(wanted) / sizeof(wanted[0]); i++) {
        int found = binary_search(sorted, length, wanted[i]);

        if (found < 0) {
            printf("%2d is not in the array\n", wanted[i]);
        } else {
            printf("%2d is at index %d\n", wanted[i], found);
        }
    }
    return 0;
}
