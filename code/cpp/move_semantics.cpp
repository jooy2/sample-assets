// Copying duplicates the buffer; moving hands it over. The traces below
// show which one the compiler picked.

#include <iostream>
#include <string>
#include <utility>
#include <vector>

class Buffer {
public:
    explicit Buffer(std::string name, std::size_t size)
        : name_(std::move(name)), bytes_(size, '.') {}

    Buffer(const Buffer& other) : name_(other.name_ + "-copy"), bytes_(other.bytes_) {
        std::cout << "copy  " << name_ << " (" << bytes_.size() << " bytes duplicated)\n";
    }

    Buffer(Buffer&& other) noexcept
        : name_(std::move(other.name_)), bytes_(std::move(other.bytes_)) {
        std::cout << "move  " << name_ << " (buffer handed over)\n";
    }

    std::size_t size() const { return bytes_.size(); }
    const std::string& name() const { return name_; }

private:
    std::string name_;
    std::vector<char> bytes_;
};

int main() {
    Buffer original("frame", 1024);

    Buffer copied = original;              // copy constructor
    Buffer moved = std::move(original);    // move constructor

    std::cout << "copied " << copied.name() << " holds " << copied.size() << '\n';
    std::cout << "moved  " << moved.name() << " holds " << moved.size() << '\n';
    std::cout << "the moved-from buffer now holds " << original.size() << '\n';
    return 0;
}
