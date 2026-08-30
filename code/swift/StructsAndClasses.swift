// A struct is a value type, copied on assignment; a class is a reference
// type, shared. Choosing between them is most of Swift's design work.

struct PointValue {
    var x: Double
    var y: Double

    // Changing a property of a struct needs `mutating`.
    mutating func move(dx: Double, dy: Double) {
        x += dx
        y += dy
    }

    // A non-mutating alternative returns a new value.
    func moved(dx: Double, dy: Double) -> PointValue {
        PointValue(x: x + dx, y: y + dy)
    }
}

final class PointReference {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    func move(dx: Double, dy: Double) {
        x += dx
        y += dy
    }

    deinit {
        print("  a PointReference was released")
    }
}

class Vehicle {
    let name: String
    private(set) var capacity: Int

    init(name: String, capacity: Int) {
        self.name = name
        self.capacity = capacity
    }

    func describe() -> String {
        "\(name) carries \(capacity)"
    }
}

final class Tram: Vehicle {
    let line: String
    private var charge = 100

    init(name: String, capacity: Int, line: String) {
        self.line = line
        super.init(name: name, capacity: capacity) // after the subclass's own properties
    }

    func drain(_ amount: Int) {
        charge = max(0, charge - amount)
    }

    override func describe() -> String {
        "\(super.describe()) on the \(line) line, \(charge)% charged"
    }
}

// Structs get a memberwise initialiser for free.
var original = PointValue(x: 1, y: 2)
var copy = original
copy.move(dx: 100, dy: 0)
print("value semantics: original \(original.x), copy \(copy.x)")
print("non-mutating:", original.moved(dx: 5, dy: 5))

let shared = PointReference(x: 1, y: 2)
let alias = shared
alias.move(dx: 100, dy: 0)
print("reference semantics: both read \(shared.x)")

// let on a struct freezes its properties; on a class only the binding.
let frozen = PointValue(x: 0, y: 0)
// frozen.x = 1        // would not compile
let constantReference = PointReference(x: 0, y: 0)
constantReference.x = 1 // allowed: the object is mutable, the binding is not
print("class through a let:", constantReference.x)

let tram = Tram(name: "Tram 14", capacity: 180, line: "Amber")
tram.drain(35)
print(tram.describe())
print("is a Vehicle:", tram is Vehicle)

// Identity applies only to references.
print("identical:", shared === alias, "| different objects:", shared === constantReference)

// deinit runs when the last reference goes away.
do {
    _ = PointReference(x: 9, y: 9)
}
print("done")
