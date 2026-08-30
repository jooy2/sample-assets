// Automatic reference counting: strong by default, and the weak and
// unowned references that break the cycles it cannot.

final class Station {
    let name: String

    // A strong reference to its line would complete a cycle, so it is weak.
    weak var line: TransitLine?

    init(name: String) {
        self.name = name
        print("  + Station \(name)")
    }

    deinit {
        print("  - Station \(name)")
    }
}

final class TransitLine {
    let name: String
    var stations: [Station] = []

    init(name: String) {
        self.name = name
        print("  + TransitLine \(name)")
    }

    func add(_ station: Station) {
        stations.append(station)
        station.line = self
    }

    deinit {
        print("  - TransitLine \(name)")
    }
}

// unowned is for a reference that is never nil while the owner lives: a
// customer may exist without a card, but a card never without a customer.
final class Customer {
    let name: String
    var card: LoyaltyCard?

    init(name: String) {
        self.name = name
    }

    deinit { print("  - Customer \(name)") }
}

final class LoyaltyCard {
    let number: String
    unowned let owner: Customer

    init(number: String, owner: Customer) {
        self.number = number
        self.owner = owner
    }

    deinit { print("  - LoyaltyCard \(number)") }
}

// A closure captures self strongly, which is the other common cycle.
final class Reporter {
    var label = "reporter"
    var onEvent: (() -> String)?

    func wireUpBadly() {
        onEvent = { "strongly captured \(self.label)" } // keeps self alive
    }

    func wireUpWell() {
        onEvent = { [weak self] in
            guard let self else { return "the reporter is gone" }
            return "weakly captured \(self.label)"
        }
    }

    deinit { print("  - Reporter") }
}

print("a line and its stations:")
do {
    let amber = TransitLine(name: "Amber")
    amber.add(Station(name: "Alder Cross"))
    amber.add(Station(name: "Quill Wharf"))
    print("  first station's line: \(amber.stations[0].line?.name ?? "none")")
}
print("both were released, because the back reference is weak\n")

print("a customer and a card:")
do {
    let customer = Customer(name: "Imogen Hawthorne")
    customer.card = LoyaltyCard(number: "4821", owner: customer)
    print("  card \(customer.card!.number) belongs to \(customer.card!.owner.name)")
}
print("both released, because the card's owner is unowned\n")

print("a closure that captures self:")
do {
    let reporter = Reporter()
    reporter.wireUpWell()
    print("  \(reporter.onEvent?() ?? "-")")
}
print("released, because the closure captured self weakly\n")

print("counting references by hand:")
var first: Station? = Station(name: "Saltwick Halt")
var second = first
print("  two strong references")
first = nil
print("  one left, still alive")
second = nil
print("  none left, so it is gone")

// A weak reference becomes nil on its own once the object goes.
weak var observer: Station?
do {
    let temporary = Station(name: "Nether Gate")
    observer = temporary
    print("observer sees \(observer?.name ?? "nothing")")
}
print("after the scope, observer sees \(observer?.name ?? "nothing")")
