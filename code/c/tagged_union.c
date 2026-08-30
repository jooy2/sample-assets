/* A tagged union: one struct that holds any of several value types,
   with an enum saying which one is currently valid. */

#include <stdio.h>

typedef enum {
    VALUE_INTEGER,
    VALUE_DOUBLE,
    VALUE_TEXT,
    VALUE_NOTHING
} ValueKind;

typedef struct {
    ValueKind kind;
    union {
        long integer;
        double number;
        const char *text;
    } as;
} Value;

static Value from_integer(long integer)
{
    Value value = {VALUE_INTEGER, {.integer = integer}};
    return value;
}

static Value from_double(double number)
{
    Value value = {VALUE_DOUBLE, {0}};
    value.as.number = number;
    return value;
}

static Value from_text(const char *text)
{
    Value value = {VALUE_TEXT, {0}};
    value.as.text = text;
    return value;
}

static void print_value(const Value *value)
{
    switch (value->kind) {
    case VALUE_INTEGER: printf("integer %ld\n", value->as.integer); break;
    case VALUE_DOUBLE:  printf("double  %.3f\n", value->as.number); break;
    case VALUE_TEXT:    printf("text    \"%s\"\n", value->as.text); break;
    case VALUE_NOTHING: printf("nothing\n"); break;
    }
}

int main(void)
{
    Value values[] = {
        from_integer(42),
        from_double(3.14159),
        from_text("thistledown"),
        {VALUE_NOTHING, {0}},
    };

    for (size_t i = 0; i < sizeof(values) / sizeof(values[0]); i++) {
        print_value(&values[i]);
    }
    return 0;
}
