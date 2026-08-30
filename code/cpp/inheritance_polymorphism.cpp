// A virtual function makes the call site defer to the runtime type.

#include <iostream>
#include <memory>
#include <string>
#include <utility>
#include <vector>

class Employee {
public:
    Employee(std::string name, double base) : name_(std::move(name)), base_(base) {}
    virtual ~Employee() = default;

    virtual double monthly_pay() const { return base_ / 12.0; }
    virtual std::string title() const { return "Employee"; }

    const std::string& name() const { return name_; }

protected:
    double base() const { return base_; }

private:
    std::string name_;
    double base_;
};

class Engineer : public Employee {
public:
    Engineer(std::string name, double base, double bonus)
        : Employee(std::move(name), base), bonus_(bonus) {}

    double monthly_pay() const override { return Employee::monthly_pay() + bonus_ / 12.0; }
    std::string title() const override { return "Engineer"; }

private:
    double bonus_;
};

class Contractor : public Employee {
public:
    Contractor(std::string name, double rate, int hours)
        : Employee(std::move(name), 0.0), rate_(rate), hours_(hours) {}

    double monthly_pay() const override { return rate_ * hours_; }
    std::string title() const override { return "Contractor"; }

private:
    double rate_;
    int hours_;
};

int main() {
    std::vector<std::unique_ptr<Employee>> staff;
    staff.push_back(std::make_unique<Employee>("Beatrix Nordstrom", 96000));
    staff.push_back(std::make_unique<Engineer>("Yolanda Blackwood", 132000, 18000));
    staff.push_back(std::make_unique<Contractor>("Talia Whitlock", 85.0, 120));

    double payroll = 0.0;
    for (const auto& person : staff) {
        std::cout << person->title() << ' ' << person->name() << ": "
                  << person->monthly_pay() << '\n';
        payroll += person->monthly_pay();
    }
    std::cout << "monthly payroll " << payroll << '\n';
    return 0;
}
