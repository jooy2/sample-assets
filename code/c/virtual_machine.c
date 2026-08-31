/*
 * virtual_machine.c — a stack machine: instruction set, assembler,
 * disassembler, interpreter, and a tracing mode.
 *
 * The VM has a value stack, a call stack with local frames, a constant pool,
 * and thirty instructions. Programs are written in a small assembly language
 * that the assembler in this file turns into bytecode.
 *
 *   cc -std=c11 -Wall -Wextra -O2 -o vm virtual_machine.c
 *   ./vm          run the built-in programs
 *   ./vm -t       run them with a trace of every instruction
 *
 * Everything is one translation unit and uses only the C standard library.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <ctype.h>

#define STACK_MAX     256
#define FRAMES_MAX     64

/*
 * Each call frame owns a fixed slice of the locals array. The stride has to
 * be small enough that FRAMES_MAX frames still fit -- an earlier version used
 * 32 slots per frame against a 256-slot array, which quietly capped recursion
 * at depth eight and reported it as a bad jump.
 */
#define LOCALS_PER_FRAME  8
#define LOCALS_MAX       (FRAMES_MAX * LOCALS_PER_FRAME)
#define CONSTANTS_MAX 256
#define CODE_MAX     4096
#define LABELS_MAX    128
#define NAME_MAX_LEN   32

/* ------------------------------------------------------------ instructions */

typedef enum {
    OP_HALT,      /* stop                                              */
    OP_CONST,     /* push constants[operand]                           */
    OP_PUSH,      /* push operand as an integer                        */
    OP_POP,       /* discard the top                                   */
    OP_DUP,       /* duplicate the top                                 */
    OP_SWAP,      /* exchange the top two                              */
    OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_MOD, OP_NEG,
    OP_EQ, OP_NE, OP_LT, OP_LE, OP_GT, OP_GE,
    OP_AND, OP_OR, OP_NOT,
    OP_JMP,       /* jump to operand                                   */
    OP_JZ,        /* pop; jump if zero                                 */
    OP_JNZ,       /* pop; jump if non-zero                             */
    OP_LOAD,      /* push local[operand]                               */
    OP_STORE,     /* pop into local[operand]                           */
    OP_CALL,      /* call operand, arity in the high byte              */
    OP_RET,       /* return, leaving the top of the stack as the value */
    OP_PRINT,     /* pop and print                                     */
    OP_PRINTS,    /* print constants[operand] as text                  */
    OP_COUNT
} OpCode;

typedef struct {
    const char *name;
    bool has_operand;
} OpInfo;

static const OpInfo OP_INFO[OP_COUNT] = {
    [OP_HALT]   = {"halt",   false},
    [OP_CONST]  = {"const",  true },
    [OP_PUSH]   = {"push",   true },
    [OP_POP]    = {"pop",    false},
    [OP_DUP]    = {"dup",    false},
    [OP_SWAP]   = {"swap",   false},
    [OP_ADD]    = {"add",    false},
    [OP_SUB]    = {"sub",    false},
    [OP_MUL]    = {"mul",    false},
    [OP_DIV]    = {"div",    false},
    [OP_MOD]    = {"mod",    false},
    [OP_NEG]    = {"neg",    false},
    [OP_EQ]     = {"eq",     false},
    [OP_NE]     = {"ne",     false},
    [OP_LT]     = {"lt",     false},
    [OP_LE]     = {"le",     false},
    [OP_GT]     = {"gt",     false},
    [OP_GE]     = {"ge",     false},
    [OP_AND]    = {"and",    false},
    [OP_OR]     = {"or",     false},
    [OP_NOT]    = {"not",    false},
    [OP_JMP]    = {"jmp",    true },
    [OP_JZ]     = {"jz",     true },
    [OP_JNZ]    = {"jnz",    true },
    [OP_LOAD]   = {"load",   true },
    [OP_STORE]  = {"store",  true },
    [OP_CALL]   = {"call",   true },
    [OP_RET]    = {"ret",    false},
    [OP_PRINT]  = {"print",  false},
    [OP_PRINTS] = {"prints", true },
};

/* --------------------------------------------------------------- the image */

typedef struct {
    uint8_t  code[CODE_MAX];
    int32_t  operand[CODE_MAX];
    int      length;

    char     constants[CONSTANTS_MAX][NAME_MAX_LEN];
    int      constant_count;
} Program;

typedef struct {
    char name[NAME_MAX_LEN];
    int  address;   /* -1 until the label is defined */
} Label;

typedef enum {
    VM_OK,
    VM_HALTED,
    VM_STACK_OVERFLOW,
    VM_STACK_UNDERFLOW,
    VM_FRAME_OVERFLOW,
    VM_DIVIDE_BY_ZERO,
    VM_BAD_ADDRESS,
    VM_BAD_LOCAL,
    VM_BAD_OPCODE
} VmStatus;

static const char *vm_status_text(VmStatus status)
{
    switch (status) {
    case VM_OK:              return "running";
    case VM_HALTED:          return "halted";
    case VM_STACK_OVERFLOW:  return "stack overflow";
    case VM_STACK_UNDERFLOW: return "stack underflow";
    case VM_FRAME_OVERFLOW:  return "call stack overflow";
    case VM_DIVIDE_BY_ZERO:  return "divide by zero";
    case VM_BAD_ADDRESS:     return "jump outside the program";
    case VM_BAD_LOCAL:       return "local slot outside the frame";
    case VM_BAD_OPCODE:      return "unknown opcode";
    }
    return "?";
}

/* ------------------------------------------------------------- the machine */

typedef struct {
    int return_address;
    int base;      /* index into locals for this frame */
    int arity;
} Frame;

typedef struct {
    const Program *program;

    int64_t stack[STACK_MAX];
    int     top;

    int64_t locals[LOCALS_MAX];

    Frame   frames[FRAMES_MAX];
    int     frame_count;

    int      pc;
    bool     trace;
    long     steps;
    VmStatus status;
} Vm;

static void vm_init(Vm *vm, const Program *program, bool trace)
{
    memset(vm, 0, sizeof(*vm));
    vm->program = program;
    vm->trace = trace;
    vm->status = VM_OK;
    vm->frames[0].base = 0;
    vm->frames[0].return_address = -1;
    vm->frame_count = 1;
}

static bool push(Vm *vm, int64_t value)
{
    if (vm->top >= STACK_MAX) {
        vm->status = VM_STACK_OVERFLOW;
        return false;
    }
    vm->stack[vm->top++] = value;
    return true;
}

static bool pop(Vm *vm, int64_t *out)
{
    if (vm->top <= 0) {
        vm->status = VM_STACK_UNDERFLOW;
        return false;
    }
    *out = vm->stack[--vm->top];
    return true;
}

static bool pop2(Vm *vm, int64_t *left, int64_t *right)
{
    return pop(vm, right) && pop(vm, left);
}

static void trace_line(const Vm *vm, int pc, uint8_t op, int32_t operand)
{
    fprintf(stderr, "%04d  %-7s", pc, OP_INFO[op].name);
    if (OP_INFO[op].has_operand) {
        fprintf(stderr, "%-5d", operand);
    } else {
        fprintf(stderr, "%-5s", "");
    }
    fprintf(stderr, " | stack:");
    for (int i = 0; i < vm->top && i < 8; i++) {
        fprintf(stderr, " %lld", (long long)vm->stack[i]);
    }
    if (vm->top > 8) {
        fprintf(stderr, " ...");
    }
    fputc('\n', stderr);
}

static VmStatus vm_run(Vm *vm, long step_limit)
{
    const Program *program = vm->program;

    while (vm->status == VM_OK) {
        if (vm->pc < 0 || vm->pc >= program->length) {
            return vm->status = VM_BAD_ADDRESS;
        }
        if (++vm->steps > step_limit) {
            fprintf(stderr, "step limit reached\n");
            return vm->status = VM_HALTED;
        }

        int pc = vm->pc;
        uint8_t op = program->code[pc];
        int32_t operand = program->operand[pc];
        vm->pc++;

        if (op >= OP_COUNT) {
            return vm->status = VM_BAD_OPCODE;
        }
        if (vm->trace) {
            trace_line(vm, pc, op, operand);
        }

        int64_t a = 0, b = 0;

        switch (op) {
        case OP_HALT:
            return vm->status = VM_HALTED;

        case OP_PUSH:
            if (!push(vm, operand)) return vm->status;
            break;

        case OP_CONST:
            if (!push(vm, operand)) return vm->status;
            break;

        case OP_POP:
            if (!pop(vm, &a)) return vm->status;
            break;

        case OP_DUP:
            if (vm->top < 1) return vm->status = VM_STACK_UNDERFLOW;
            if (!push(vm, vm->stack[vm->top - 1])) return vm->status;
            break;

        case OP_SWAP:
            if (vm->top < 2) return vm->status = VM_STACK_UNDERFLOW;
            a = vm->stack[vm->top - 1];
            vm->stack[vm->top - 1] = vm->stack[vm->top - 2];
            vm->stack[vm->top - 2] = a;
            break;

        case OP_ADD: case OP_SUB: case OP_MUL: case OP_DIV: case OP_MOD:
        case OP_EQ:  case OP_NE:  case OP_LT:  case OP_LE:
        case OP_GT:  case OP_GE:  case OP_AND: case OP_OR: {
            if (!pop2(vm, &a, &b)) return vm->status;
            int64_t result = 0;
            switch (op) {
            case OP_ADD: result = a + b; break;
            case OP_SUB: result = a - b; break;
            case OP_MUL: result = a * b; break;
            case OP_DIV:
                if (b == 0) return vm->status = VM_DIVIDE_BY_ZERO;
                result = a / b;
                break;
            case OP_MOD:
                if (b == 0) return vm->status = VM_DIVIDE_BY_ZERO;
                result = a % b;
                break;
            case OP_EQ:  result = a == b; break;
            case OP_NE:  result = a != b; break;
            case OP_LT:  result = a <  b; break;
            case OP_LE:  result = a <= b; break;
            case OP_GT:  result = a >  b; break;
            case OP_GE:  result = a >= b; break;
            case OP_AND: result = a && b; break;
            case OP_OR:  result = a || b; break;
            default: break;
            }
            if (!push(vm, result)) return vm->status;
            break;
        }

        case OP_NEG:
            if (!pop(vm, &a)) return vm->status;
            if (!push(vm, -a)) return vm->status;
            break;

        case OP_NOT:
            if (!pop(vm, &a)) return vm->status;
            if (!push(vm, !a)) return vm->status;
            break;

        case OP_JMP:
            vm->pc = operand;
            break;

        case OP_JZ:
            if (!pop(vm, &a)) return vm->status;
            if (a == 0) vm->pc = operand;
            break;

        case OP_JNZ:
            if (!pop(vm, &a)) return vm->status;
            if (a != 0) vm->pc = operand;
            break;

        case OP_LOAD: {
            if (operand < 0 || operand >= LOCALS_PER_FRAME) {
                return vm->status = VM_BAD_LOCAL;
            }
            int slot = vm->frames[vm->frame_count - 1].base + operand;
            if (!push(vm, vm->locals[slot])) return vm->status;
            break;
        }

        case OP_STORE: {
            if (operand < 0 || operand >= LOCALS_PER_FRAME) {
                return vm->status = VM_BAD_LOCAL;
            }
            int slot = vm->frames[vm->frame_count - 1].base + operand;
            if (!pop(vm, &a)) return vm->status;
            vm->locals[slot] = a;
            break;
        }

        case OP_CALL: {
            /* The address is the low 16 bits, the arity the next 8. */
            int address = operand & 0xffff;
            int arity   = (operand >> 16) & 0xff;

            if (vm->frame_count >= FRAMES_MAX) return vm->status = VM_FRAME_OVERFLOW;
            if (vm->top < arity) return vm->status = VM_STACK_UNDERFLOW;
            if (arity > LOCALS_PER_FRAME) return vm->status = VM_BAD_LOCAL;

            Frame *caller = &vm->frames[vm->frame_count - 1];
            Frame *callee = &vm->frames[vm->frame_count++];
            callee->return_address = vm->pc;
            callee->base = caller->base + LOCALS_PER_FRAME;
            callee->arity = arity;

            /* Arguments are popped into locals 0..arity-1, left to right. */
            for (int i = arity - 1; i >= 0; i--) {
                if (!pop(vm, &a)) return vm->status;
                vm->locals[callee->base + i] = a;
            }
            vm->pc = address;
            break;
        }

        case OP_RET: {
            if (vm->frame_count <= 1) return vm->status = VM_HALTED;
            Frame *frame = &vm->frames[--vm->frame_count];
            vm->pc = frame->return_address;
            break;
        }

        case OP_PRINT:
            if (!pop(vm, &a)) return vm->status;
            printf("%lld\n", (long long)a);
            break;

        case OP_PRINTS:
            if (operand < 0 || operand >= program->constant_count) {
                return vm->status = VM_BAD_ADDRESS;
            }
            printf("%s\n", program->constants[operand]);
            break;

        default:
            return vm->status = VM_BAD_OPCODE;
        }
    }

    return vm->status;
}

/* ------------------------------------------------------------- the assembler */

typedef struct {
    Program *program;
    Label    labels[LABELS_MAX];
    int      label_count;

    struct { int site; char name[NAME_MAX_LEN]; int arity; } fixups[LABELS_MAX];
    int      fixup_count;

    int      line;
    bool     failed;
} Assembler;

static int find_label(Assembler *as, const char *name)
{
    for (int i = 0; i < as->label_count; i++) {
        if (strcmp(as->labels[i].name, name) == 0) return i;
    }
    return -1;
}

static int intern_label(Assembler *as, const char *name)
{
    int index = find_label(as, name);
    if (index >= 0) return index;
    if (as->label_count >= LABELS_MAX) return -1;

    index = as->label_count++;
    snprintf(as->labels[index].name, NAME_MAX_LEN, "%s", name);
    as->labels[index].address = -1;
    return index;
}

static int intern_constant(Program *program, const char *text)
{
    for (int i = 0; i < program->constant_count; i++) {
        if (strcmp(program->constants[i], text) == 0) return i;
    }
    if (program->constant_count >= CONSTANTS_MAX) return -1;

    int index = program->constant_count++;
    snprintf(program->constants[index], NAME_MAX_LEN, "%s", text);
    return index;
}

static int find_opcode(const char *word)
{
    for (int i = 0; i < OP_COUNT; i++) {
        if (OP_INFO[i].name && strcmp(OP_INFO[i].name, word) == 0) return i;
    }
    return -1;
}

static void emit(Assembler *as, uint8_t op, int32_t operand)
{
    Program *program = as->program;
    if (program->length >= CODE_MAX) {
        fprintf(stderr, "line %d: program too long\n", as->line);
        as->failed = true;
        return;
    }
    program->code[program->length] = op;
    program->operand[program->length] = operand;
    program->length++;
}

/*
 * Assemble one line. The syntax is deliberately thin:
 *
 *   name:              define a label here
 *   push 42            an instruction with a numeric operand
 *   jmp loop           an instruction with a label operand
 *   call add 2         a call: label then arity
 *   prints "text"      a string constant
 *   ; anything         a comment
 */
static void assemble_line(Assembler *as, char *line)
{
    char *comment = strchr(line, ';');
    if (comment) *comment = '\0';

    char *cursor = line;
    while (isspace((unsigned char)*cursor)) cursor++;
    if (*cursor == '\0') return;

    char word[NAME_MAX_LEN];
    int consumed = 0;
    if (sscanf(cursor, "%31s%n", word, &consumed) != 1) return;
    cursor += consumed;

    size_t length = strlen(word);
    if (length > 0 && word[length - 1] == ':') {
        word[length - 1] = '\0';
        int index = intern_label(as, word);
        if (index < 0) {
            fprintf(stderr, "line %d: too many labels\n", as->line);
            as->failed = true;
            return;
        }
        as->labels[index].address = as->program->length;
        return;
    }

    int op = find_opcode(word);
    if (op < 0) {
        fprintf(stderr, "line %d: unknown instruction '%s'\n", as->line, word);
        as->failed = true;
        return;
    }

    if (!OP_INFO[op].has_operand) {
        emit(as, (uint8_t)op, 0);
        return;
    }

    while (isspace((unsigned char)*cursor)) cursor++;

    if (*cursor == '"') {
        char *end = strchr(cursor + 1, '"');
        if (!end) {
            fprintf(stderr, "line %d: unterminated string\n", as->line);
            as->failed = true;
            return;
        }
        *end = '\0';
        int index = intern_constant(as->program, cursor + 1);
        emit(as, (uint8_t)op, index);
        return;
    }

    if (*cursor == '-' || isdigit((unsigned char)*cursor)) {
        emit(as, (uint8_t)op, (int32_t)strtol(cursor, NULL, 10));
        return;
    }

    /* A label operand: record a fixup and patch it once every label is known. */
    char name[NAME_MAX_LEN];
    int arity = 0;
    int fields = sscanf(cursor, "%31s %d", name, &arity);
    if (fields < 1) {
        fprintf(stderr, "line %d: %s needs an operand\n", as->line, OP_INFO[op].name);
        as->failed = true;
        return;
    }

    if (as->fixup_count >= LABELS_MAX) {
        fprintf(stderr, "line %d: too many forward references\n", as->line);
        as->failed = true;
        return;
    }
    as->fixups[as->fixup_count].site = as->program->length;
    as->fixups[as->fixup_count].arity = (op == OP_CALL) ? arity : 0;
    snprintf(as->fixups[as->fixup_count].name, NAME_MAX_LEN, "%s", name);
    as->fixup_count++;

    intern_label(as, name);
    emit(as, (uint8_t)op, 0);
}

static bool assemble(Program *program, const char *source)
{
    Assembler as;
    memset(&as, 0, sizeof(as));
    as.program = program;

    char *copy = malloc(strlen(source) + 1);
    if (!copy) return false;
    strcpy(copy, source);

    char *save = NULL;
    for (char *line = strtok_r(copy, "\n", &save);
         line != NULL;
         line = strtok_r(NULL, "\n", &save)) {
        as.line++;
        assemble_line(&as, line);
    }
    free(copy);

    for (int i = 0; i < as.fixup_count; i++) {
        int index = find_label(&as, as.fixups[i].name);
        if (index < 0 || as.labels[index].address < 0) {
            fprintf(stderr, "undefined label '%s'\n", as.fixups[i].name);
            as.failed = true;
            continue;
        }
        int32_t address = as.labels[index].address;
        if (program->code[as.fixups[i].site] == OP_CALL) {
            address |= (as.fixups[i].arity & 0xff) << 16;
        }
        program->operand[as.fixups[i].site] = address;
    }

    return !as.failed;
}

static void disassemble(const Program *program, const char *title)
{
    printf("--- %s (%d instruction(s)) ---\n", title, program->length);
    for (int pc = 0; pc < program->length; pc++) {
        uint8_t op = program->code[pc];
        printf("  %04d  %-7s", pc, op < OP_COUNT ? OP_INFO[op].name : "?");
        if (op < OP_COUNT && OP_INFO[op].has_operand) {
            if (op == OP_CALL) {
                printf(" %d (arity %d)",
                       program->operand[pc] & 0xffff,
                       (program->operand[pc] >> 16) & 0xff);
            } else if (op == OP_PRINTS) {
                printf(" \"%s\"", program->constants[program->operand[pc]]);
            } else {
                printf(" %d", program->operand[pc]);
            }
        }
        putchar('\n');
    }
}

/* ------------------------------------------------------------- the programs */

static const char PROGRAM_FACTORIAL[] =
    "; factorial(12), computed iteratively                            \n"
    "        prints \"factorial 1..12\"                               \n"
    "        push 1                                                   \n"
    "        store 0        ; accumulator                             \n"
    "        push 1                                                   \n"
    "        store 1        ; counter                                 \n"
    "loop:                                                            \n"
    "        load 1                                                   \n"
    "        push 12                                                  \n"
    "        gt                                                       \n"
    "        jnz done                                                 \n"
    "        load 0                                                   \n"
    "        load 1                                                   \n"
    "        mul                                                      \n"
    "        store 0                                                  \n"
    "        load 0                                                   \n"
    "        print                                                    \n"
    "        load 1                                                   \n"
    "        push 1                                                   \n"
    "        add                                                      \n"
    "        store 1                                                  \n"
    "        jmp loop                                                 \n"
    "done:                                                            \n"
    "        halt                                                     \n";

static const char PROGRAM_FIBONACCI[] =
    "; fib(n) by recursion, to show the call stack working            \n"
    "        prints \"fib 0..15 by recursion\"                        \n"
    "        push 0                                                   \n"
    "        store 0                                                  \n"
    "outer:                                                           \n"
    "        load 0                                                   \n"
    "        push 15                                                  \n"
    "        gt                                                       \n"
    "        jnz stop                                                 \n"
    "        load 0                                                   \n"
    "        call fib 1                                               \n"
    "        print                                                    \n"
    "        load 0                                                   \n"
    "        push 1                                                   \n"
    "        add                                                      \n"
    "        store 0                                                  \n"
    "        jmp outer                                                \n"
    "stop:                                                            \n"
    "        halt                                                     \n"
    "                                                                 \n"
    "fib:                                                             \n"
    "        load 0                                                   \n"
    "        push 2                                                   \n"
    "        lt                                                       \n"
    "        jz recurse                                               \n"
    "        load 0                                                   \n"
    "        ret                                                      \n"
    "recurse:                                                         \n"
    "        load 0                                                   \n"
    "        push 1                                                   \n"
    "        sub                                                      \n"
    "        call fib 1                                               \n"
    "        load 0                                                   \n"
    "        push 2                                                   \n"
    "        sub                                                      \n"
    "        call fib 1                                               \n"
    "        add                                                      \n"
    "        ret                                                      \n";

static const char PROGRAM_GCD[] =
    "; Euclid's algorithm on a few pairs                              \n"
    "        prints \"gcd\"                                           \n"
    "        push 1071                                                \n"
    "        push 462                                                 \n"
    "        call gcd 2                                               \n"
    "        print                                                    \n"
    "        push 270                                                 \n"
    "        push 192                                                 \n"
    "        call gcd 2                                               \n"
    "        print                                                    \n"
    "        push 17                                                  \n"
    "        push 5                                                   \n"
    "        call gcd 2                                               \n"
    "        print                                                    \n"
    "        halt                                                     \n"
    "                                                                 \n"
    "gcd:                                                             \n"
    "        load 1                                                   \n"
    "        jz base                                                  \n"
    "        load 1                                                   \n"
    "        load 0                                                   \n"
    "        load 1                                                   \n"
    "        mod                                                      \n"
    "        call gcd 2                                               \n"
    "        ret                                                      \n"
    "base:                                                            \n"
    "        load 0                                                   \n"
    "        ret                                                      \n";

static const char PROGRAM_FAULTY[] =
    "; deliberately divides by zero, to show the error path           \n"
    "        push 10                                                  \n"
    "        push 0                                                   \n"
    "        div                                                      \n"
    "        print                                                    \n"
    "        halt                                                     \n";

static void run_one(const char *title, const char *source, bool trace, bool show_code)
{
    Program program;
    memset(&program, 0, sizeof(program));

    if (!assemble(&program, source)) {
        printf("%s: assembly failed\n\n", title);
        return;
    }
    if (show_code) {
        disassemble(&program, title);
    } else {
        printf("--- %s ---\n", title);
    }

    Vm vm;
    vm_init(&vm, &program, trace);
    VmStatus status = vm_run(&vm, 2000000L);

    printf("  [%s after %ld step(s), %d value(s) left on the stack]\n\n",
           vm_status_text(status), vm.steps, vm.top);
}

int main(int argc, char **argv)
{
    bool trace = false;
    bool show_code = false;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-t") == 0) trace = true;
        else if (strcmp(argv[i], "-d") == 0) show_code = true;
        else {
            fprintf(stderr, "usage: %s [-t] [-d]\n", argv[0]);
            return 1;
        }
    }

    run_one("factorial", PROGRAM_FACTORIAL, trace, show_code);
    run_one("fibonacci", PROGRAM_FIBONACCI, trace, show_code);
    run_one("gcd", PROGRAM_GCD, trace, show_code);
    run_one("faulty", PROGRAM_FAULTY, false, show_code);

    return 0;
}
