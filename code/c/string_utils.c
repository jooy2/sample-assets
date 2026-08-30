/* Small string helpers: trim, uppercase, and split on a delimiter. */

#include <stdio.h>
#include <string.h>
#include <ctype.h>

/* Trims in place and returns a pointer into the original buffer. */
static char *trim(char *text)
{
    while (isspace((unsigned char)*text)) {
        text++;
    }
    if (*text == '\0') {
        return text;
    }

    char *end = text + strlen(text) - 1;
    while (end > text && isspace((unsigned char)*end)) {
        end--;
    }
    end[1] = '\0';
    return text;
}

static void to_upper(char *text)
{
    for (char *at = text; *at; at++) {
        *at = (char)toupper((unsigned char)*at);
    }
}

/* Fills `parts` with pointers into `text`, which is cut up in place. */
static size_t split(char *text, char delimiter, char **parts, size_t limit)
{
    size_t count = 0;
    char *start = text;

    for (char *at = text; count < limit; at++) {
        if (*at != delimiter && *at != '\0') {
            continue;
        }
        int reached_end = (*at == '\0');

        *at = '\0';
        parts[count++] = start;
        if (reached_end) {
            break;
        }
        start = at + 1;
    }
    return count;
}

int main(void)
{
    char padded[] = "   quill moor   ";
    printf("[%s]\n", trim(padded));

    char shout[] = "stonebay";
    to_upper(shout);
    printf("%s\n", shout);

    char csv[] = "amber,cobalt,emerald,crimson";
    char *parts[8];
    size_t count = split(csv, ',', parts, 8);

    for (size_t i = 0; i < count; i++) {
        printf("%zu: %s\n", i, parts[i]);
    }
    return 0;
}
