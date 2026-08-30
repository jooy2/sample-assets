/* A fixed-size hash table with string keys, resolving collisions by
   linear probing. */

#include <stdio.h>
#include <string.h>

#define TABLE_SIZE 16

typedef struct {
    const char *key; /* NULL marks an empty slot */
    int value;
} Entry;

/* The FNV-1a hash, small enough to read in one sitting. */
static unsigned long hash_key(const char *key)
{
    unsigned long hash = 2166136261UL;

    for (const unsigned char *at = (const unsigned char *)key; *at; at++) {
        hash ^= *at;
        hash *= 16777619UL;
    }
    return hash;
}

static int table_set(Entry *table, const char *key, int value)
{
    size_t index = hash_key(key) % TABLE_SIZE;

    for (size_t probe = 0; probe < TABLE_SIZE; probe++) {
        size_t slot = (index + probe) % TABLE_SIZE;

        if (table[slot].key == NULL || strcmp(table[slot].key, key) == 0) {
            table[slot].key = key;
            table[slot].value = value;
            return 1;
        }
    }
    return 0; /* the table is full */
}

/* Writes the value into `out` and returns 1, or returns 0 when the key is absent. */
static int table_get(const Entry *table, const char *key, int *out)
{
    size_t index = hash_key(key) % TABLE_SIZE;

    for (size_t probe = 0; probe < TABLE_SIZE; probe++) {
        size_t slot = (index + probe) % TABLE_SIZE;

        if (table[slot].key == NULL) {
            return 0;
        }
        if (strcmp(table[slot].key, key) == 0) {
            *out = table[slot].value;
            return 1;
        }
    }
    return 0;
}

int main(void)
{
    Entry table[TABLE_SIZE] = {{NULL, 0}};
    const char *keys[] = {"alder", "bramble", "cinder", "dunmar"};

    for (int i = 0; i < 4; i++) {
        table_set(table, keys[i], (i + 1) * 100);
    }

    int value = 0;
    for (int i = 0; i < 4; i++) {
        if (table_get(table, keys[i], &value)) {
            printf("%-8s %d\n", keys[i], value);
        }
    }
    printf("elmgate  %s\n", table_get(table, "elmgate", &value) ? "found" : "not found");
    return 0;
}
