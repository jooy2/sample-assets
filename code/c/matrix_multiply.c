/* Multiplying two square matrices held as fixed-size 2D arrays. */

#include <stdio.h>

#define SIZE 3

static void multiply(const int left[SIZE][SIZE],
                     const int right[SIZE][SIZE],
                     int result[SIZE][SIZE])
{
    for (int row = 0; row < SIZE; row++) {
        for (int column = 0; column < SIZE; column++) {
            int sum = 0;

            for (int k = 0; k < SIZE; k++) {
                sum += left[row][k] * right[k][column];
            }
            result[row][column] = sum;
        }
    }
}

static void print_matrix(const char *label, const int matrix[SIZE][SIZE])
{
    printf("%s\n", label);
    for (int row = 0; row < SIZE; row++) {
        for (int column = 0; column < SIZE; column++) {
            printf("%6d", matrix[row][column]);
        }
        printf("\n");
    }
}

int main(void)
{
    const int left[SIZE][SIZE] = {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}};
    const int right[SIZE][SIZE] = {{9, 8, 7}, {6, 5, 4}, {3, 2, 1}};
    int result[SIZE][SIZE];

    multiply(left, right, result);

    print_matrix("left", left);
    print_matrix("right", right);
    print_matrix("product", result);
    return 0;
}
