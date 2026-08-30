// RAII: the destructor releases the resource, so an early return or a
// thrown exception cannot leak it.

#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <utility>

class ScopedTimerLog {
public:
    explicit ScopedTimerLog(std::string label) : label_(std::move(label)) {
        std::cout << "-> entering " << label_ << '\n';
    }

    ~ScopedTimerLog() { std::cout << "<- leaving  " << label_ << '\n'; }

    ScopedTimerLog(const ScopedTimerLog&) = delete;
    ScopedTimerLog& operator=(const ScopedTimerLog&) = delete;

private:
    std::string label_;
};

void write_report(const std::string& path, bool fail) {
    ScopedTimerLog guard("write_report");

    std::ofstream file(path);
    if (!file) {
        throw std::runtime_error("cannot open " + path);
    }
    file << "station,line,zone\n";
    file << "Alder Cross,Amber,2\n";

    if (fail) {
        throw std::runtime_error("interrupted halfway");
    }
    std::cout << "   wrote " << path << '\n';
}

int main() {
    write_report("stations.csv", false);

    try {
        write_report("stations.csv", true);
    } catch (const std::exception& error) {
        std::cout << "caught: " << error.what() << '\n';
    }
    return 0;
}
