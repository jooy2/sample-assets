// Measuring elapsed time with std::chrono, and converting between the
// duration units it defines.

#include <chrono>
#include <iostream>
#include <thread>
#include <vector>

class Stopwatch {
public:
    Stopwatch() : start_(std::chrono::steady_clock::now()) {}

    void reset() { start_ = std::chrono::steady_clock::now(); }

    std::chrono::microseconds elapsed() const {
        return std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::steady_clock::now() - start_);
    }

private:
    std::chrono::steady_clock::time_point start_;
};

int main() {
    Stopwatch watch;

    long long sum = 0;
    for (int i = 1; i <= 2'000'000; ++i) {
        sum += i;
    }
    const auto counting = watch.elapsed();

    watch.reset();
    std::this_thread::sleep_for(std::chrono::milliseconds(20));
    const auto sleeping = watch.elapsed();

    std::cout << "sum " << sum << '\n';
    std::cout << "counting took " << counting.count() << " us\n";
    std::cout << "sleeping took " << sleeping.count() / 1000.0 << " ms\n";

    constexpr std::chrono::hours shift(8);
    std::cout << "a shift is " << std::chrono::minutes(shift).count() << " minutes\n";
    return 0;
}
