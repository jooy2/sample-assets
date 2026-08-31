/*
 * json_parser.c — a complete JSON reader and writer.
 *
 * A recursive-descent parser that builds a document tree, a query function
 * that walks it by path, a pretty-printer, and a compact writer. Handles the
 * parts that trip up quick implementations: string escapes, surrogate pairs,
 * exponents, deep nesting limits, and reporting where a syntax error is.
 *
 *   cc -std=c11 -Wall -Wextra -O2 -o json json_parser.c
 *   ./json                 parse the built-in documents
 *   ./json file.json       parse a file and pretty-print it
 *   ./json -c file.json    parse and print compactly
 *
 * Standard library only. Every allocation is released by json_free.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>
#include <math.h>
#include <errno.h>

#define MAX_DEPTH 128

/* ------------------------------------------------------------- the document */

typedef enum {
    JSON_NULL,
    JSON_BOOL,
    JSON_NUMBER,
    JSON_STRING,
    JSON_ARRAY,
    JSON_OBJECT
} JsonType;

typedef struct JsonValue JsonValue;

typedef struct JsonMember {
    char      *key;
    JsonValue *value;
    struct JsonMember *next;
} JsonMember;

struct JsonValue {
    JsonType type;
    union {
        bool   boolean;
        double number;
        char  *string;
        struct {
            JsonValue **items;
            size_t      count;
            size_t      capacity;
        } array;
        struct {
            JsonMember *first;
            JsonMember *last;
            size_t      count;
        } object;
    } as;
};

/* ------------------------------------------------------------ construction */

static JsonValue *json_new(JsonType type)
{
    JsonValue *value = calloc(1, sizeof(JsonValue));
    if (value) value->type = type;
    return value;
}

void json_free(JsonValue *value)
{
    if (!value) return;

    switch (value->type) {
    case JSON_STRING:
        free(value->as.string);
        break;
    case JSON_ARRAY:
        for (size_t i = 0; i < value->as.array.count; i++) {
            json_free(value->as.array.items[i]);
        }
        free(value->as.array.items);
        break;
    case JSON_OBJECT: {
        JsonMember *member = value->as.object.first;
        while (member) {
            JsonMember *next = member->next;
            free(member->key);
            json_free(member->value);
            free(member);
            member = next;
        }
        break;
    }
    default:
        break;
    }
    free(value);
}

static bool array_push(JsonValue *array, JsonValue *item)
{
    if (array->as.array.count == array->as.array.capacity) {
        size_t capacity = array->as.array.capacity ? array->as.array.capacity * 2 : 8;
        JsonValue **grown = realloc(array->as.array.items, capacity * sizeof(JsonValue *));
        if (!grown) return false;
        array->as.array.items = grown;
        array->as.array.capacity = capacity;
    }
    array->as.array.items[array->as.array.count++] = item;
    return true;
}

static bool object_put(JsonValue *object, char *key, JsonValue *value)
{
    JsonMember *member = calloc(1, sizeof(JsonMember));
    if (!member) return false;

    member->key = key;
    member->value = value;

    if (object->as.object.last) {
        object->as.object.last->next = member;
    } else {
        object->as.object.first = member;
    }
    object->as.object.last = member;
    object->as.object.count++;
    return true;
}

/* -------------------------------------------------------------- the parser */

typedef struct {
    const char *text;
    size_t      length;
    size_t      position;
    int         depth;
    char        error[160];
    int         error_line;
    int         error_column;
} Parser;

static void parser_fail(Parser *parser, const char *message)
{
    if (parser->error[0]) return;   /* keep the first error, not the last */

    int line = 1;
    int column = 1;
    for (size_t i = 0; i < parser->position && i < parser->length; i++) {
        if (parser->text[i] == '\n') { line++; column = 1; } else { column++; }
    }
    parser->error_line = line;
    parser->error_column = column;
    snprintf(parser->error, sizeof(parser->error), "%s", message);
}

static void skip_whitespace(Parser *parser)
{
    while (parser->position < parser->length) {
        char c = parser->text[parser->position];
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
            parser->position++;
        } else {
            break;
        }
    }
}

static char peek(Parser *parser)
{
    return parser->position < parser->length ? parser->text[parser->position] : '\0';
}

static bool consume(Parser *parser, char expected)
{
    if (peek(parser) == expected) {
        parser->position++;
        return true;
    }
    return false;
}

static JsonValue *parse_value(Parser *parser);

/* Write a code point to a buffer as UTF-8, returning the byte count. */
static int encode_utf8(uint32_t code_point, char *out)
{
    if (code_point < 0x80) {
        out[0] = (char)code_point;
        return 1;
    }
    if (code_point < 0x800) {
        out[0] = (char)(0xC0 | (code_point >> 6));
        out[1] = (char)(0x80 | (code_point & 0x3F));
        return 2;
    }
    if (code_point < 0x10000) {
        out[0] = (char)(0xE0 | (code_point >> 12));
        out[1] = (char)(0x80 | ((code_point >> 6) & 0x3F));
        out[2] = (char)(0x80 | (code_point & 0x3F));
        return 3;
    }
    out[0] = (char)(0xF0 | (code_point >> 18));
    out[1] = (char)(0x80 | ((code_point >> 12) & 0x3F));
    out[2] = (char)(0x80 | ((code_point >> 6) & 0x3F));
    out[3] = (char)(0x80 | (code_point & 0x3F));
    return 4;
}

static bool read_hex4(Parser *parser, uint32_t *out)
{
    if (parser->position + 4 > parser->length) return false;

    uint32_t value = 0;
    for (int i = 0; i < 4; i++) {
        char c = parser->text[parser->position + i];
        value <<= 4;
        if (c >= '0' && c <= '9')      value |= (uint32_t)(c - '0');
        else if (c >= 'a' && c <= 'f') value |= (uint32_t)(c - 'a' + 10);
        else if (c >= 'A' && c <= 'F') value |= (uint32_t)(c - 'A' + 10);
        else return false;
    }
    parser->position += 4;
    *out = value;
    return true;
}

/* Parse a string body, the opening quote already consumed. */
static char *parse_string_body(Parser *parser)
{
    size_t capacity = 32;
    size_t length = 0;
    char *buffer = malloc(capacity);
    if (!buffer) return NULL;

    while (parser->position < parser->length) {
        char c = parser->text[parser->position++];

        if (c == '"') {
            buffer[length] = '\0';
            return buffer;
        }

        if (length + 5 >= capacity) {
            capacity *= 2;
            char *grown = realloc(buffer, capacity);
            if (!grown) { free(buffer); return NULL; }
            buffer = grown;
        }

        if (c != '\\') {
            if ((unsigned char)c < 0x20) {
                parser->position--;
                parser_fail(parser, "unescaped control character in string");
                free(buffer);
                return NULL;
            }
            buffer[length++] = c;
            continue;
        }

        if (parser->position >= parser->length) break;
        char escape = parser->text[parser->position++];

        switch (escape) {
        case '"':  buffer[length++] = '"';  break;
        case '\\': buffer[length++] = '\\'; break;
        case '/':  buffer[length++] = '/';  break;
        case 'b':  buffer[length++] = '\b'; break;
        case 'f':  buffer[length++] = '\f'; break;
        case 'n':  buffer[length++] = '\n'; break;
        case 'r':  buffer[length++] = '\r'; break;
        case 't':  buffer[length++] = '\t'; break;
        case 'u': {
            uint32_t code_point = 0;
            if (!read_hex4(parser, &code_point)) {
                parser_fail(parser, "\\u must be followed by four hex digits");
                free(buffer);
                return NULL;
            }
            /* A high surrogate must be followed by a low one. */
            if (code_point >= 0xD800 && code_point <= 0xDBFF) {
                if (parser->position + 1 < parser->length
                    && parser->text[parser->position] == '\\'
                    && parser->text[parser->position + 1] == 'u') {
                    parser->position += 2;
                    uint32_t low = 0;
                    if (!read_hex4(parser, &low)) {
                        parser_fail(parser, "bad low surrogate");
                        free(buffer);
                        return NULL;
                    }
                    if (low >= 0xDC00 && low <= 0xDFFF) {
                        code_point = 0x10000
                            + ((code_point - 0xD800) << 10)
                            + (low - 0xDC00);
                    } else {
                        code_point = 0xFFFD;
                    }
                } else {
                    code_point = 0xFFFD;   /* lone surrogate */
                }
            } else if (code_point >= 0xDC00 && code_point <= 0xDFFF) {
                code_point = 0xFFFD;
            }
            length += (size_t)encode_utf8(code_point, buffer + length);
            break;
        }
        default:
            parser->position--;
            parser_fail(parser, "unknown escape sequence");
            free(buffer);
            return NULL;
        }
    }

    parser_fail(parser, "unterminated string");
    free(buffer);
    return NULL;
}

static JsonValue *parse_number(Parser *parser)
{
    const char *start = parser->text + parser->position;
    char *end = NULL;

    errno = 0;
    double number = strtod(start, &end);

    if (end == start) {
        parser_fail(parser, "expected a number");
        return NULL;
    }
    /* JSON forbids what strtod happily accepts: hex, infinity, leading plus. */
    if (start[0] == '+' || (start[0] == '0' && end - start > 1
                            && start[1] >= '0' && start[1] <= '9')) {
        parser_fail(parser, "malformed number");
        return NULL;
    }
    if (!isfinite(number)) {
        parser_fail(parser, "number out of range");
        return NULL;
    }

    parser->position += (size_t)(end - start);

    JsonValue *value = json_new(JSON_NUMBER);
    if (!value) return NULL;
    value->as.number = number;
    return value;
}

static JsonValue *parse_literal(Parser *parser, const char *word,
                                JsonType type, bool boolean)
{
    size_t length = strlen(word);
    if (parser->position + length > parser->length
        || strncmp(parser->text + parser->position, word, length) != 0) {
        parser_fail(parser, "expected a value");
        return NULL;
    }
    parser->position += length;

    JsonValue *value = json_new(type);
    if (value && type == JSON_BOOL) value->as.boolean = boolean;
    return value;
}

static JsonValue *parse_array(Parser *parser)
{
    JsonValue *array = json_new(JSON_ARRAY);
    if (!array) return NULL;

    skip_whitespace(parser);
    if (consume(parser, ']')) return array;

    for (;;) {
        JsonValue *item = parse_value(parser);
        if (!item) { json_free(array); return NULL; }
        if (!array_push(array, item)) {
            json_free(item);
            json_free(array);
            return NULL;
        }

        skip_whitespace(parser);
        if (consume(parser, ',')) {
            skip_whitespace(parser);
            if (peek(parser) == ']') {
                parser_fail(parser, "trailing comma in array");
                json_free(array);
                return NULL;
            }
            continue;
        }
        if (consume(parser, ']')) return array;

        parser_fail(parser, "expected ',' or ']' in array");
        json_free(array);
        return NULL;
    }
}

static JsonValue *parse_object(Parser *parser)
{
    JsonValue *object = json_new(JSON_OBJECT);
    if (!object) return NULL;

    skip_whitespace(parser);
    if (consume(parser, '}')) return object;

    for (;;) {
        skip_whitespace(parser);
        if (!consume(parser, '"')) {
            parser_fail(parser, "object keys must be strings");
            json_free(object);
            return NULL;
        }
        char *key = parse_string_body(parser);
        if (!key) { json_free(object); return NULL; }

        skip_whitespace(parser);
        if (!consume(parser, ':')) {
            parser_fail(parser, "expected ':' after an object key");
            free(key);
            json_free(object);
            return NULL;
        }

        JsonValue *value = parse_value(parser);
        if (!value) { free(key); json_free(object); return NULL; }
        if (!object_put(object, key, value)) {
            free(key);
            json_free(value);
            json_free(object);
            return NULL;
        }

        skip_whitespace(parser);
        if (consume(parser, ',')) {
            skip_whitespace(parser);
            if (peek(parser) == '}') {
                parser_fail(parser, "trailing comma in object");
                json_free(object);
                return NULL;
            }
            continue;
        }
        if (consume(parser, '}')) return object;

        parser_fail(parser, "expected ',' or '}' in object");
        json_free(object);
        return NULL;
    }
}

static JsonValue *parse_value(Parser *parser)
{
    if (++parser->depth > MAX_DEPTH) {
        parser_fail(parser, "nested too deeply");
        parser->depth--;
        return NULL;
    }

    skip_whitespace(parser);
    JsonValue *value = NULL;

    switch (peek(parser)) {
    case '{': parser->position++; value = parse_object(parser); break;
    case '[': parser->position++; value = parse_array(parser); break;
    case '"': {
        parser->position++;
        char *text = parse_string_body(parser);
        if (text) {
            value = json_new(JSON_STRING);
            if (value) value->as.string = text; else free(text);
        }
        break;
    }
    case 't': value = parse_literal(parser, "true",  JSON_BOOL, true);  break;
    case 'f': value = parse_literal(parser, "false", JSON_BOOL, false); break;
    case 'n': value = parse_literal(parser, "null",  JSON_NULL, false); break;
    case '\0': parser_fail(parser, "unexpected end of input"); break;
    default:  value = parse_number(parser); break;
    }

    parser->depth--;
    return value;
}

/**
 * Parse a whole document. On failure returns NULL and writes a message of at
 * most `error_size` bytes into `error`.
 */
JsonValue *json_parse(const char *text, char *error, size_t error_size)
{
    Parser parser;
    memset(&parser, 0, sizeof(parser));
    parser.text = text;
    parser.length = strlen(text);

    JsonValue *value = parse_value(&parser);

    if (value) {
        skip_whitespace(&parser);
        if (parser.position != parser.length) {
            parser_fail(&parser, "trailing content after the document");
            json_free(value);
            value = NULL;
        }
    }

    if (!value && error && error_size) {
        snprintf(error, error_size, "line %d, column %d: %s",
                 parser.error_line, parser.error_column,
                 parser.error[0] ? parser.error : "parse failed");
    }
    return value;
}

/* ------------------------------------------------------------------ queries */

JsonValue *json_get(JsonValue *object, const char *key)
{
    if (!object || object->type != JSON_OBJECT) return NULL;
    for (JsonMember *m = object->as.object.first; m; m = m->next) {
        if (strcmp(m->key, key) == 0) return m->value;
    }
    return NULL;
}

JsonValue *json_at(JsonValue *array, size_t index)
{
    if (!array || array->type != JSON_ARRAY) return NULL;
    return index < array->as.array.count ? array->as.array.items[index] : NULL;
}

/**
 * Look a value up by a dotted path, where a numeric segment indexes an array:
 * "routes.1.name". Returns NULL when any segment is missing.
 */
JsonValue *json_path(JsonValue *root, const char *path)
{
    JsonValue *node = root;
    const char *cursor = path;

    while (node && *cursor) {
        char segment[128];
        size_t length = 0;
        while (*cursor && *cursor != '.' && length + 1 < sizeof(segment)) {
            segment[length++] = *cursor++;
        }
        segment[length] = '\0';
        if (*cursor == '.') cursor++;

        if (node->type == JSON_ARRAY) {
            char *end = NULL;
            long index = strtol(segment, &end, 10);
            node = (end != segment && *end == '\0' && index >= 0)
                 ? json_at(node, (size_t)index) : NULL;
        } else {
            node = json_get(node, segment);
        }
    }
    return node;
}

size_t json_count(const JsonValue *value)
{
    if (!value) return 0;
    if (value->type == JSON_ARRAY) return value->as.array.count;
    if (value->type == JSON_OBJECT) return value->as.object.count;
    return 0;
}

const char *json_type_name(const JsonValue *value)
{
    if (!value) return "missing";
    switch (value->type) {
    case JSON_NULL:   return "null";
    case JSON_BOOL:   return "boolean";
    case JSON_NUMBER: return "number";
    case JSON_STRING: return "string";
    case JSON_ARRAY:  return "array";
    case JSON_OBJECT: return "object";
    }
    return "?";
}

/* ------------------------------------------------------------------ writing */

static void write_escaped(FILE *out, const char *text)
{
    fputc('"', out);
    for (const unsigned char *c = (const unsigned char *)text; *c; c++) {
        switch (*c) {
        case '"':  fputs("\\\"", out); break;
        case '\\': fputs("\\\\", out); break;
        case '\b': fputs("\\b", out);  break;
        case '\f': fputs("\\f", out);  break;
        case '\n': fputs("\\n", out);  break;
        case '\r': fputs("\\r", out);  break;
        case '\t': fputs("\\t", out);  break;
        default:
            if (*c < 0x20) {
                fprintf(out, "\\u%04x", *c);
            } else {
                fputc(*c, out);
            }
        }
    }
    fputc('"', out);
}

static void write_number(FILE *out, double number)
{
    if (number == (long long)number && fabs(number) < 1e15) {
        fprintf(out, "%lld", (long long)number);
        return;
    }

    /*
     * Print the shortest form that reads back as the same double. Going
     * straight to %.17g is always correct and almost always ugly: it turns
     * 0.68 into 0.68000000000000005.
     */
    char buffer[40];
    for (int digits = 15; digits <= 17; digits++) {
        snprintf(buffer, sizeof(buffer), "%.*g", digits, number);
        if (strtod(buffer, NULL) == number) break;
    }
    fputs(buffer, out);
}

void json_write(FILE *out, const JsonValue *value, int indent, int level)
{
    if (!value) { fputs("null", out); return; }

    const char *newline = indent > 0 ? "\n" : "";
    int pad = indent * (level + 1);
    int close_pad = indent * level;

    switch (value->type) {
    case JSON_NULL:   fputs("null", out); break;
    case JSON_BOOL:   fputs(value->as.boolean ? "true" : "false", out); break;
    case JSON_NUMBER: write_number(out, value->as.number); break;
    case JSON_STRING: write_escaped(out, value->as.string); break;

    case JSON_ARRAY:
        if (value->as.array.count == 0) { fputs("[]", out); break; }
        fputc('[', out);
        fputs(newline, out);
        for (size_t i = 0; i < value->as.array.count; i++) {
            fprintf(out, "%*s", pad, "");
            json_write(out, value->as.array.items[i], indent, level + 1);
            if (i + 1 < value->as.array.count) fputc(',', out);
            fputs(newline, out);
        }
        fprintf(out, "%*s]", close_pad, "");
        break;

    case JSON_OBJECT: {
        if (value->as.object.count == 0) { fputs("{}", out); break; }
        fputc('{', out);
        fputs(newline, out);
        for (JsonMember *m = value->as.object.first; m; m = m->next) {
            fprintf(out, "%*s", pad, "");
            write_escaped(out, m->key);
            fputs(indent > 0 ? ": " : ":", out);
            json_write(out, m->value, indent, level + 1);
            if (m->next) fputc(',', out);
            fputs(newline, out);
        }
        fprintf(out, "%*s}", close_pad, "");
        break;
    }
    }
}

/* ---------------------------------------------------------------- built-ins */

static const char SAMPLE[] =
"{\n"
"  \"service\": \"Northwind Ferry Cooperative\",\n"
"  \"generated\": \"2027-06-30T23:59:00Z\",\n"
"  \"active\": true,\n"
"  \"routes\": [\n"
"    { \"code\": \"HRB\", \"name\": \"Harbour Loop\",   \"passengers\": 83755,\n"
"      \"recovery\": 1.27, \"cancelled\": [\"2027-04-23\", \"2027-05-12\"] },\n"
"    { \"code\": \"KSP\", \"name\": \"Kestrel Point\",  \"passengers\": 63325,\n"
"      \"recovery\": 1.03, \"cancelled\": [] },\n"
"    { \"code\": \"HLW\", \"name\": \"Halloway\",       \"passengers\": 30615,\n"
"      \"recovery\": 0.68, \"cancelled\": [\"2027-04-02\", \"2027-04-14\"] },\n"
"    { \"code\": \"NCR\", \"name\": \"Night Crossing\", \"passengers\": 37185,\n"
"      \"recovery\": 1.03, \"cancelled\": null }\n"
"  ],\n"
"  \"notes\": \"Quoted \\\"figures\\\" are invented.\\nTabs\\tand newlines survive.\",\n"
"  \"unicode\": \"caf\\u00e9 \\ud83d\\udea2 \\u2014 fog\",\n"
"  \"numbers\": [0, -1, 3.14159, 1e3, -2.5e-4, 1234567890123],\n"
"  \"empty\": { \"object\": {}, \"array\": [] }\n"
"}\n";

static const char *BROKEN[] = {
    "{ \"a\": 1, }",
    "[1, 2, 3",
    "{ a: 1 }",
    "\"unterminated",
    "{ \"a\": 01 }",
    "[1] extra",
    "{ \"a\": \"bad \\escape\" }",
    NULL
};

static char *read_whole_file(const char *path)
{
    FILE *file = fopen(path, "rb");
    if (!file) return NULL;

    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    fseek(file, 0, SEEK_SET);
    if (size < 0) { fclose(file); return NULL; }

    char *buffer = malloc((size_t)size + 1);
    if (!buffer) { fclose(file); return NULL; }

    size_t read = fread(buffer, 1, (size_t)size, file);
    buffer[read] = '\0';
    fclose(file);
    return buffer;
}

static void report(JsonValue *root)
{
    printf("--- queries ---\n");
    const char *paths[] = {
        "service", "routes.0.name", "routes.2.recovery",
        "routes.3.cancelled", "routes.9.name", "empty.array", "unicode", NULL
    };
    for (int i = 0; paths[i]; i++) {
        JsonValue *found = json_path(root, paths[i]);
        printf("  %-22s %-8s ", paths[i], json_type_name(found));
        if (found) json_write(stdout, found, 0, 0);
        putchar('\n');
    }

    printf("\n--- totals ---\n");
    JsonValue *routes = json_get(root, "routes");
    double passengers = 0;
    int cancelled = 0;
    for (size_t i = 0; i < json_count(routes); i++) {
        JsonValue *route = json_at(routes, i);
        JsonValue *count = json_get(route, "passengers");
        JsonValue *list = json_get(route, "cancelled");
        if (count && count->type == JSON_NUMBER) passengers += count->as.number;
        cancelled += (int)json_count(list);
    }
    printf("  %zu route(s), %.0f passengers, %d cancellation(s)\n",
           json_count(routes), passengers, cancelled);

    printf("\n--- escapes round-tripped ---\n");
    JsonValue *notes = json_get(root, "notes");
    if (notes) printf("  decoded: %s\n", notes->as.string);
}

int main(int argc, char **argv)
{
    char error[160];
    bool compact = false;
    const char *path = NULL;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-c") == 0) compact = true;
        else path = argv[i];
    }

    if (path) {
        char *text = read_whole_file(path);
        if (!text) {
            fprintf(stderr, "cannot read %s\n", path);
            return 2;
        }
        JsonValue *root = json_parse(text, error, sizeof(error));
        free(text);
        if (!root) {
            fprintf(stderr, "%s: %s\n", path, error);
            return 1;
        }
        json_write(stdout, root, compact ? 0 : 2, 0);
        putchar('\n');
        json_free(root);
        return 0;
    }

    JsonValue *root = json_parse(SAMPLE, error, sizeof(error));
    if (!root) {
        fprintf(stderr, "the built-in document failed to parse: %s\n", error);
        return 1;
    }

    report(root);

    printf("\n--- compact ---\n  ");
    json_write(stdout, json_get(root, "empty"), 0, 0);
    putchar('\n');
    printf("  ");
    json_write(stdout, json_get(root, "numbers"), 0, 0);
    putchar('\n');

    printf("\n--- pretty, first route ---\n");
    json_write(stdout, json_at(json_get(root, "routes"), 0), 2, 0);
    putchar('\n');

    json_free(root);

    printf("\n--- rejected input ---\n");
    for (int i = 0; BROKEN[i]; i++) {
        JsonValue *bad = json_parse(BROKEN[i], error, sizeof(error));
        printf("  %-26s %s\n", BROKEN[i], bad ? "ACCEPTED (wrongly)" : error);
        json_free(bad);
    }

    printf("\n--- depth limit ---\n");
    char deep[2 * MAX_DEPTH + 64];
    size_t at = 0;
    for (int i = 0; i < MAX_DEPTH + 2; i++) deep[at++] = '[';
    for (int i = 0; i < MAX_DEPTH + 2; i++) deep[at++] = ']';
    deep[at] = '\0';
    JsonValue *nested = json_parse(deep, error, sizeof(error));
    printf("  %d levels: %s\n", MAX_DEPTH + 2, nested ? "accepted" : error);
    json_free(nested);

    return 0;
}
