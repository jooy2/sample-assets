// Counting words with std::map, then ranking them with std::vector.

#include <algorithm>
#include <cctype>
#include <iostream>
#include <map>
#include <sstream>
#include <string>
#include <vector>

int main() {
    const std::string text =
        "the tide came in and the tide went out and the shore stayed where it was";

    std::map<std::string, int> counts;
    std::istringstream words(text);
    std::string word;

    while (words >> word) {
        std::transform(word.begin(), word.end(), word.begin(),
                       [](unsigned char c) { return std::tolower(c); });
        ++counts[word];
    }

    std::vector<std::pair<std::string, int>> ranked(counts.begin(), counts.end());
    std::sort(ranked.begin(), ranked.end(), [](const auto& left, const auto& right) {
        if (left.second != right.second) {
            return left.second > right.second;
        }
        return left.first < right.first;
    });

    std::cout << counts.size() << " distinct words\n";
    for (std::size_t i = 0; i < ranked.size() && i < 5; ++i) {
        std::cout << ranked[i].second << "  " << ranked[i].first << '\n';
    }
    return 0;
}
