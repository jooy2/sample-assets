/* A singly linked list: push to the front, walk it, free it. */

#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    int value;
    struct Node *next;
} Node;

/* Returns the new head, or the old head when the allocation fails. */
static Node *list_push(Node *head, int value)
{
    Node *node = malloc(sizeof(Node));

    if (node == NULL) {
        fprintf(stderr, "out of memory\n");
        return head;
    }
    node->value = value;
    node->next = head;
    return node;
}

static void list_print(const Node *head)
{
    for (const Node *node = head; node != NULL; node = node->next) {
        printf("%d -> ", node->value);
    }
    printf("NULL\n");
}

static void list_free(Node *head)
{
    while (head != NULL) {
        Node *next = head->next;
        free(head);
        head = next;
    }
}

int main(void)
{
    Node *head = NULL;

    for (int i = 1; i <= 5; i++) {
        head = list_push(head, i * 11);
    }
    list_print(head);
    list_free(head);
    return 0;
}
