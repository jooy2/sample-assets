/* Reading command line options by hand, without getopt. */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

typedef struct {
    int verbose;
    int repeat;
    const char *name;
} Options;

static void usage(const char *program)
{
    fprintf(stderr, "usage: %s [-v] [-n COUNT] NAME\n", program);
}

int main(int argc, char **argv)
{
    Options options = {0, 1, NULL};
    int index = 1;

    for (; index < argc; index++) {
        if (strcmp(argv[index], "-v") == 0) {
            options.verbose = 1;
        } else if (strcmp(argv[index], "-n") == 0) {
            if (index + 1 >= argc) {
                fprintf(stderr, "-n needs a count\n");
                return 1;
            }
            options.repeat = atoi(argv[++index]);
        } else if (argv[index][0] == '-') {
            fprintf(stderr, "unknown option: %s\n", argv[index]);
            usage(argv[0]);
            return 1;
        } else {
            break;
        }
    }

    if (index >= argc) {
        usage(argv[0]);
        return 1;
    }
    options.name = argv[index];

    if (options.verbose) {
        fprintf(stderr, "greeting %s %d time(s)\n", options.name, options.repeat);
    }
    for (int i = 0; i < options.repeat; i++) {
        printf("Hello, %s!\n", options.name);
    }
    return 0;
}
