// Protocols describe capability; extensions add behaviour to any type,
// including one you did not write.

import Foundation

protocol Shape {
    var area: Double { get }
    var name: String { get }
}

// A default implementation lives in a protocol extension.
extension Shape {
    var name: String { String(describing: type(of: self)).lowercased() }

    func describe() -> String {
        String(format: "%@ covering %.2f", name, area)
    }
}

struct Circle: Shape {
    let radius: Double
    var area: Double { .pi * radius * radius }
}

struct Rectangle: Shape {
    let width: Double
    let height: Double
    var area: Double { width * height }

    // Overriding the default.
    func describe() -> String {
        "\(width)x\(height) rectangle"
    }
}

// Conforming to a standard protocol hooks a type into the language.
extension Circle: CustomStringConvertible {
    var description: String { "circle(r=\(radius))" }
}

extension Circle: Comparable {
    static func < (left: Circle, right: Circle) -> Bool { left.radius < right.radius }
}

// Extending a type from the standard library.
extension String {
    var slug: String {
        lowercased()
            .map { $0.isLetter || $0.isNumber ? $0 : "-" }
            .reduce(into: "") { result, character in
                if character == "-" && result.hasSuffix("-") { return }
                result.append(character)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    func truncated(to length: Int, ellipsis: String = "...") -> String {
        count <= length ? self : prefix(length - ellipsis.count) + ellipsis
    }
}

// A constrained extension applies only where the constraint holds.
extension Array where Element: Shape {
    var totalArea: Double { reduce(0) { $0 + $1.area } }
}

extension Collection where Element: Numeric {
    var total: Element { reduce(.zero, +) }
}

let shapes: [Shape] = [Circle(radius: 2), Rectangle(width: 4, height: 4), Circle(radius: 12)]
for shape in shapes {
    print(shape.describe())
}
print(String(format: "total %.2f", shapes.reduce(0) { $0 + $1.area }))

// The constrained extension applies to a concrete element type.
let circles = [Circle(radius: 2), Circle(radius: 12)]
print(String(format: "circles alone: %.2f", circles.totalArea))

print(Circle(radius: 3))
print("sorted:", [Circle(radius: 3), Circle(radius: 1)].sorted().map(\.radius))

print("  Alder Cross / Quill Wharf  ".slug)
print("Stations on the Amber line".truncated(to: 18))
print("total:", [1, 2, 3, 4].total)

// A protocol can be used as a type, or as a generic constraint.
func largest<T: Shape>(_ shapes: [T]) -> T? {
    shapes.max { $0.area < $1.area }
}
print("largest circle:", largest([Circle(radius: 2), Circle(radius: 12)])?.radius as Any)
