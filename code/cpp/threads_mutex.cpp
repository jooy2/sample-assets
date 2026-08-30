// Several threads adding to one counter, with a mutex to keep the
// increments from stepping on each other.

#include <chrono>
#include <iostream>
#include <mutex>
#include <thread>
#include <vector>

int main() {
    constexpr int kThreads = 4;
    constexpr int kStepsEach = 25000;

    long guarded = 0;
    long unguarded = 0;
    std::mutex mutex;

    std::vector<std::thread> workers;
    workers.reserve(kThreads);

    for (int worker = 0; worker < kThreads; ++worker) {
        workers.emplace_back([&] {
            for (int step = 0; step < kStepsEach; ++step) {
                {
                    std::lock_guard<std::mutex> lock(mutex);
                    ++guarded;
                }
                ++unguarded; // a data race, shown here to make the point
            }
        });
    }

    for (std::thread& worker : workers) {
        worker.join();
    }

    std::cout << "expected  " << kThreads * kStepsEach << '\n';
    std::cout << "guarded   " << guarded << '\n';
    std::cout << "unguarded " << unguarded << " (usually short)\n";
    return 0;
}
