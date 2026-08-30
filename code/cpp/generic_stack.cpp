// A class template: one Stack definition, any element type.

#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

template <typename T>
class Stack {
public:
    void push(T value) { items_.push_back(std::move(value)); }

    T pop() {
        if (items_.empty()) {
            throw std::out_of_range("pop from an empty stack");
        }
        T value = std::move(items_.back());
        items_.pop_back();
        return value;
    }

    const T& peek() const {
        if (items_.empty()) {
            throw std::out_of_range("peek at an empty stack");
        }
        return items_.back();
    }

    bool empty() const { return items_.empty(); }
    std::size_t size() const { return items_.size(); }

private:
    std::vector<T> items_;
};

int main() {
    Stack<int> numbers;
    for (int value : {3, 1, 4, 1, 5}) {
        numbers.push(value);
    }
    std::cout << "top " << numbers.peek() << ", size " << numbers.size() << '\n';
    while (!numbers.empty()) {
        std::cout << numbers.pop() << ' ';
    }
    std::cout << '\n';

    Stack<std::string> words;
    words.push("cobalt");
    words.push("emerald");
    std::cout << words.pop() << ", then " << words.pop() << '\n';

    try {
        words.pop();
    } catch (const std::out_of_range& error) {
        std::cout << "caught: " << error.what() << '\n';
    }
    return 0;
}
