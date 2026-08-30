// Generics: type parameters, constraints, associated types, and opaque
// return types.

struct Stack<Element> {
    private var items: [Element] = []

    var isEmpty: Bool { items.isEmpty }
    var count: Int { items.count }
    var top: Element? { items.last }

    mutating func push(_ item: Element) {
        items.append(item)
    }

    mutating func pop() -> Element? {
        items.popLast()
    }

    func map<T>(_ transform: (Element) throws -> T) rethrows -> Stack<T> {
        var mapped = Stack<T>()
        for item in items {
            mapped.push(try transform(item))
        }
        return mapped
    }
}

// A constrained extension: only stacks of equatable elements get this.
extension Stack where Element: Equatable {
    func contains(_ item: Element) -> Bool {
        items.contains(item)
    }
}

extension Stack: CustomStringConvertible {
    var description: String { "Stack(\(items))" }
}

// A protocol with an associated type describes a family of types.
protocol Container {
    associatedtype Item
    var count: Int { get }
    mutating func append(_ item: Item)
    subscript(index: Int) -> Item { get }
}

extension Stack: Container {
    typealias Item = Element

    mutating func append(_ item: Element) { push(item) }
    subscript(index: Int) -> Element { items[index] }
}

// Generic functions, with a where clause for the harder constraints.
func largest<T: Comparable>(_ values: [T]) -> T? {
    values.max()
}

func allEqual<C1: Container, C2: Container>(_ left: C1, _ right: C2) -> Bool
where C1.Item == C2.Item, C1.Item: Equatable {
    guard left.count == right.count else { return false }
    return (0..<left.count).allSatisfy { left[$0] == right[$0] }
}

// `some` returns one concrete type without naming it.
func makeNumbers() -> some Container {
    var stack = Stack<Int>()
    for value in 1...3 { stack.push(value) }
    return stack
}

// `any` erases the type, so a collection can hold several of them.
func describe(_ containers: [any Container]) -> String {
    containers.map { "\($0.count)" }.joined(separator: ", ")
}

var numbers = Stack<Int>()
for value in [3, 1, 4, 1, 5] { numbers.push(value) }
print(numbers, "top:", numbers.top as Any)
print("popped:", numbers.pop() as Any, "| left:", numbers.count)
print("contains 4:", numbers.contains(4))
print("mapped:", numbers.map { $0 * 10 })

var words = Stack<String>()
words.push("cobalt")
words.push("emerald")
print(words, "| contains amber:", words.contains("amber"))

print("largest:", largest([23, 5, 91, 42]) as Any)
print("largest string:", largest(["amber", "cobalt"]) as Any)

var left = Stack<Int>()
var right = Stack<Int>()
for value in 1...3 {
    left.push(value)
    right.push(value)
}
print("equal containers:", allEqual(left, right))
print("opaque:", makeNumbers().count)
print("erased:", describe([left, words]))
