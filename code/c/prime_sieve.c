/* The sieve of Eratosthenes: cross out the multiples, keep what is left. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LIMIT 200

int main(void)
{
    char *is_composite = calloc(LIMIT + 1, sizeof(char));

    if (is_composite == NULL) {
        fprintf(stderr, "out of memory\n");
        return 1;
    }

    for (int candidate = 2; (long)candidate * candidate <= LIMIT; candidate++) {
        if (is_composite[candidate]) {
            continue;
        }
        for (int multiple = candidate * candidate; multiple <= LIMIT; multiple += candidate) {
            is_composite[multiple] = 1;
        }
    }

    int found = 0;
    for (int number = 2; number <= LIMIT; number++) {
        if (!is_composite[number]) {
            printf("%4d%s", number, ++found % 10 == 0 ? "\n" : "");
        }
    }
    printf("\n%d primes up to %d\n", found, LIMIT);

    free(is_composite);
    return 0;
}
