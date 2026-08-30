// Lambdas: capturing by value, by reference, and storing one in a
// std::function.

#include <algorithm>
#include <functional>
#include <iostream>
#include <vector>

int main() {
    int threshold = 30;

    // Captures a copy, so later changes to `threshold` do not reach it.
    auto above_copy = [threshold](int value) { return value > threshold; };

    // Captures a reference, so it always sees the current value.
    auto above_reference = [&threshold](int value) { return value > threshold; };

    std::vector<int> readings{12, 28, 34, 47, 9, 61};

    threshold = 45;
    std::cout << "captured by value:     "
              << std::count_if(readings.begin(), readings.end(), above_copy) << '\n';
    std::cout << "captured by reference: "
              << std::count_if(readings.begin(), readings.end(), above_reference) << '\n';

    // A mutable lambda keeps state between calls.
    auto next_id = [id = 100]() mutable { return id++; };
    std::cout << next_id() << ' ' << next_id() << ' ' << next_id() << '\n';

    // Stored in std::function, a lambda can be passed around like any value.
    std::function<int(int, int)> combine = [](int a, int b) { return a * b + 1; };
    std::cout << "combine(6, 7) = " << combine(6, 7) << '\n';
    return 0;
}
