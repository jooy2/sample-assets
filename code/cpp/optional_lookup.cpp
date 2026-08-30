// std::optional says "a value, or nothing" in the return type, so the
// caller cannot forget the missing case.

#include <iostream>
#include <map>
#include <optional>
#include <string>

std::optional<int> zone_of(const std::string& station) {
    static const std::map<std::string, int> zones{
        {"Alder Cross", 2},
        {"Quill Wharf", 3},
        {"Saltwick Halt", 5},
    };

    const auto found = zones.find(station);
    if (found == zones.end()) {
        return std::nullopt;
    }
    return found->second;
}

std::optional<double> divide(double numerator, double denominator) {
    if (denominator == 0.0) {
        return std::nullopt;
    }
    return numerator / denominator;
}

int main() {
    for (const std::string& station : {"Quill Wharf", "Nether Gate"}) {
        if (const auto zone = zone_of(station)) {
            std::cout << station << " is in zone " << *zone << '\n';
        } else {
            std::cout << station << " is not on the network\n";
        }
    }

    std::cout << "fallback: " << zone_of("Nether Gate").value_or(-1) << '\n';
    std::cout << "12 / 4 = " << divide(12, 4).value_or(0) << '\n';
    std::cout << "12 / 0 = "
              << (divide(12, 0).has_value() ? "a number" : "undefined") << '\n';
    return 0;
}
