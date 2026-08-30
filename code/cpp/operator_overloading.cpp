// Giving a value type the operators built-in types have.

#include <iostream>
#include <iomanip>

class Money {
public:
    Money() = default;
    explicit Money(long cents) : cents_(cents) {}

    static Money from_amount(double amount) {
        return Money(static_cast<long>(amount * 100 + (amount < 0 ? -0.5 : 0.5)));
    }

    Money operator+(const Money& other) const { return Money(cents_ + other.cents_); }
    Money operator-(const Money& other) const { return Money(cents_ - other.cents_); }
    Money operator*(int factor) const { return Money(cents_ * factor); }

    Money& operator+=(const Money& other) {
        cents_ += other.cents_;
        return *this;
    }

    bool operator==(const Money& other) const { return cents_ == other.cents_; }
    bool operator<(const Money& other) const { return cents_ < other.cents_; }

    friend std::ostream& operator<<(std::ostream& out, const Money& money) {
        const long whole = money.cents_ / 100;
        const long part = money.cents_ % 100;
        return out << whole << '.' << std::setw(2) << std::setfill('0')
                   << (part < 0 ? -part : part);
    }

private:
    long cents_ = 0;
};

int main() {
    const Money subtotal = Money::from_amount(74.50);
    const Money shipping = Money::from_amount(4.99);
    Money total = subtotal + shipping;

    total += Money::from_amount(6.15);

    std::cout << "subtotal " << subtotal << '\n';
    std::cout << "total    " << total << '\n';
    std::cout << "three of them " << subtotal * 3 << '\n';
    std::cout << "shipping is " << (shipping < subtotal ? "less" : "more")
              << " than the subtotal\n";
    return 0;
}
