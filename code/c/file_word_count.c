/* Counting lines, words, and characters in a file, the way `wc` does. */

#include <stdio.h>
#include <ctype.h>

typedef struct {
    long lines;
    long words;
    long characters;
} Counts;

static Counts count_stream(FILE *stream)
{
    Counts counts = {0, 0, 0};
    int inside_word = 0;
    int character;

    while ((character = fgetc(stream)) != EOF) {
        counts.characters++;

        if (character == '\n') {
            counts.lines++;
        }
        if (isspace(character)) {
            inside_word = 0;
        } else if (!inside_word) {
            inside_word = 1;
            counts.words++;
        }
    }
    return counts;
}

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "usage: %s FILE\n", argv[0]);
        return 1;
    }

    FILE *stream = fopen(argv[1], "r");
    if (stream == NULL) {
        perror(argv[1]);
        return 1;
    }

    Counts counts = count_stream(stream);
    fclose(stream);

    printf("%8ld %8ld %8ld %s\n",
           counts.lines, counts.words, counts.characters, argv[1]);
    return 0;
}
