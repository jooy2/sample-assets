// Binary search, iterative and recursive, over a sorted int array.

import java.util.Arrays;

public class BinarySearch {

    /** Returns the index of {@code needle}, or -1 when it is absent. */
    static int search(int[] values, int needle) {
        int low = 0;
        int high = values.length - 1;

        while (low <= high) {
            int middle = low + (high - low) / 2; // avoids overflow
            if (values[middle] == needle) {
                return middle;
            }
            if (values[middle] < needle) {
                low = middle + 1;
            } else {
                high = middle - 1;
            }
        }
        return -1;
    }

    static int searchRecursive(int[] values, int needle, int low, int high) {
        if (low > high) {
            return -1;
        }
        int middle = low + (high - low) / 2;
        if (values[middle] == needle) {
            return middle;
        }
        return values[middle] < needle
                ? searchRecursive(values, needle, middle + 1, high)
                : searchRecursive(values, needle, low, middle - 1);
    }

    /** The first index whose value is not below {@code needle}. */
    static int lowerBound(int[] values, int needle) {
        int low = 0;
        int high = values.length;

        while (low < high) {
            int middle = low + (high - low) / 2;
            if (values[middle] < needle) {
                low = middle + 1;
            } else {
                high = middle;
            }
        }
        return low;
    }

    public static void main(String[] args) {
        int[] sorted = {2, 5, 8, 12, 16, 23, 38, 56, 72, 91};

        for (int needle : new int[] {23, 2, 91, 42}) {
            System.out.printf("%2d -> iterative %2d, recursive %2d%n",
                    needle,
                    search(sorted, needle),
                    searchRecursive(sorted, needle, 0, sorted.length - 1));
        }

        System.out.println("lower bound of 40: " + lowerBound(sorted, 40));
        System.out.println("java.util.Arrays agrees: " + Arrays.binarySearch(sorted, 23));
    }
}
