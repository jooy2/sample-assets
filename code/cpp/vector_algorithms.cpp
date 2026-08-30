// Standard algorithms over a std::vector: sort, find, transform, accumulate.

#include <algorithm>
#include <iostream>
#include <numeric>
#include <string>
#include <vector>

int main() {
    std::vector<int> readings{23, 5, 91, 42, 8, 67, 15, 30};

    std::sort(readings.begin(), readings.end());

    const auto found = std::find(readings.begin(), readings.end(), 42);
    if (found != readings.end()) {
        std::cout << "42 sits at index " << std::distance(readings.begin(), found) << '\n';
    }

    std::vector<int> doubled;
    doubled.reserve(readings.size());
    std::transform(readings.begin(), readings.end(), std::back_inserter(doubled),
                   [](int value) { return value * 2; });

    const int total = std::accumulate(readings.begin(), readings.end(), 0);
    const auto above_thirty =
        std::count_if(readings.begin(), readings.end(), [](int value) { return value > 30; });

    std::cout << "sorted:  ";
    for (int value : readings) {
        std::cout << value << ' ';
    }
    std::cout << "\ndoubled: ";
    for (int value : doubled) {
        std::cout << value << ' ';
    }
    std::cout << "\ntotal " << total << ", " << above_thirty << " above 30\n";
    return 0;
}
