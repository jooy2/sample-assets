/* Packing several on/off settings into the bits of one integer. */

#include <stdio.h>

typedef enum {
    PERMISSION_READ    = 1u << 0,
    PERMISSION_WRITE   = 1u << 1,
    PERMISSION_EXECUTE = 1u << 2,
    PERMISSION_DELETE  = 1u << 3
} Permission;

static unsigned set_flag(unsigned flags, Permission flag)    { return flags | flag; }
static unsigned clear_flag(unsigned flags, Permission flag)  { return flags & ~flag; }
static unsigned toggle_flag(unsigned flags, Permission flag) { return flags ^ flag; }
static int has_flag(unsigned flags, Permission flag)         { return (flags & flag) != 0; }

static void describe(unsigned flags)
{
    printf("%c%c%c%c (0x%X)\n",
           has_flag(flags, PERMISSION_READ)    ? 'r' : '-',
           has_flag(flags, PERMISSION_WRITE)   ? 'w' : '-',
           has_flag(flags, PERMISSION_EXECUTE) ? 'x' : '-',
           has_flag(flags, PERMISSION_DELETE)  ? 'd' : '-',
           flags);
}

int main(void)
{
    unsigned flags = 0;

    flags = set_flag(flags, PERMISSION_READ);
    flags = set_flag(flags, PERMISSION_WRITE);
    describe(flags);

    flags = toggle_flag(flags, PERMISSION_EXECUTE);
    describe(flags);

    flags = clear_flag(flags, PERMISSION_WRITE);
    describe(flags);
    return 0;
}
