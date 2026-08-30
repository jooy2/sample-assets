// std::variant holds one of a fixed set of types; std::visit dispatches on
// whichever one is currently held.

#include <iostream>
#include <string>
#include <type_traits>
#include <variant>
#include <vector>

struct Circle { double radius; };
struct Rectangle { double width; double height; };
struct Triangle { double base; double height; };

using Shape = std::variant<Circle, Rectangle, Triangle>;

struct AreaOf {
    double operator()(const Circle& shape) const { return 3.14159265 * shape.radius * shape.radius; }
    double operator()(const Rectangle& shape) const { return shape.width * shape.height; }
    double operator()(const Triangle& shape) const { return shape.base * shape.height / 2.0; }
};

std::string name_of(const Shape& shape) {
    return std::visit([](const auto& held) -> std::string {
        using Held = std::decay_t<decltype(held)>;
        if constexpr (std::is_same_v<Held, Circle>) {
            return "circle";
        } else if constexpr (std::is_same_v<Held, Rectangle>) {
            return "rectangle";
        } else {
            return "triangle";
        }
    }, shape);
}

int main() {
    const std::vector<Shape> shapes{
        Circle{2.0},
        Rectangle{3.0, 4.5},
        Triangle{6.0, 2.5},
    };

    double total = 0.0;
    for (const Shape& shape : shapes) {
        const double area = std::visit(AreaOf{}, shape);
        total += area;
        std::cout << name_of(shape) << " covers " << area << '\n';
    }
    std::cout << "total " << total << '\n';
    return 0;
}
