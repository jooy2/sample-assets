// Structured bindings unpack pairs, tuples, and plain structs into named
// variables in one line.

#include <iostream>
#include <map>
#include <string>
#include <tuple>

struct Reading {
    std::string device;
    double celsius;
    int battery;
};

std::tuple<int, int, int> split_seconds(int total) {
    return {total / 3600, (total % 3600) / 60, total % 60};
}

int main() {
    const std::map<std::string, int> platforms{
        {"Alder Cross", 2}, {"Quill Wharf", 4}, {"Saltwick Halt", 1},
    };

    for (const auto& [station, count] : platforms) {
        std::cout << station << " has " << count << " platform(s)\n";
    }

    const auto [hours, minutes, seconds] = split_seconds(9045);
    std::cout << hours << "h " << minutes << "m " << seconds << "s\n";

    const Reading reading{"SNS-03", 21.4, 88};
    const auto& [device, celsius, battery] = reading;
    std::cout << device << ": " << celsius << "C, battery " << battery << "%\n";

    std::map<std::string, int> extra;
    const auto [position, inserted] = extra.insert({"Vellin Halt", 2});
    std::cout << position->first << " inserted: " << std::boolalpha << inserted << '\n';
    return 0;
}
