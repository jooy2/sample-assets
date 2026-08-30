/* A dispatch table: names mapped to the functions that implement them. */

#include <stdio.h>
#include <string.h>

typedef double (*BinaryOperation)(double, double);

static double add(double a, double b)      { return a + b; }
static double subtract(double a, double b) { return a - b; }
static double multiply(double a, double b) { return a * b; }
static double divide(double a, double b)   { return b == 0.0 ? 0.0 : a / b; }

typedef struct {
    const char *name;
    BinaryOperation apply;
} Operation;

static const Operation OPERATIONS[] = {
    {"add",      add},
    {"subtract", subtract},
    {"multiply", multiply},
    {"divide",   divide},
};

static const Operation *find_operation(const char *name)
{
    const size_t count = sizeof(OPERATIONS) / sizeof(OPERATIONS[0]);

    for (size_t i = 0; i < count; i++) {
        if (strcmp(OPERATIONS[i].name, name) == 0) {
            return &OPERATIONS[i];
        }
    }
    return NULL;
}

int main(void)
{
    const char *wanted[] = {"add", "divide", "modulo"};

    for (int i = 0; i < 3; i++) {
        const Operation *operation = find_operation(wanted[i]);

        if (operation == NULL) {
            printf("%-8s is not implemented\n", wanted[i]);
            continue;
        }
        printf("%-8s(12, 4) = %.2f\n", operation->name, operation->apply(12.0, 4.0));
    }
    return 0;
}
