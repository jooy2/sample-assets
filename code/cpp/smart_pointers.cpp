// unique_ptr owns alone, shared_ptr counts owners, weak_ptr observes
// without keeping the object alive.

#include <iostream>
#include <memory>
#include <string>
#include <utility>

struct Sensor {
    std::string name;

    explicit Sensor(std::string name) : name(std::move(name)) {
        std::cout << "opened  " << this->name << '\n';
    }
    ~Sensor() { std::cout << "closed  " << name << '\n'; }
};

int main() {
    {
        auto sole = std::make_unique<Sensor>("cold-store-a");
        std::cout << "unique owner of " << sole->name << '\n';
        // auto copy = sole;          // would not compile: unique_ptr cannot be copied
        auto moved = std::move(sole); // ownership handed over instead
        std::cout << "sole is " << (sole ? "still set" : "now empty") << '\n';
    }

    std::weak_ptr<Sensor> observer;
    {
        auto shared = std::make_shared<Sensor>("greenhouse-1");
        auto second = shared;
        observer = shared;
        std::cout << "owners: " << shared.use_count() << '\n';
    }

    std::cout << "after the scope, the observer is "
              << (observer.expired() ? "expired" : "alive") << '\n';
    return 0;
}
