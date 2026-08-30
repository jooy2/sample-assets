// Swift enums carry values per case, take methods, and make `switch`
// exhaustive.

import Foundation

enum Priority: String, CaseIterable {
    case low, normal, high, urgent

    var responseTime: String {
        switch self {
        case .low: "within a week"
        case .normal: "within two days"
        case .high: "within four hours"
        case .urgent: "immediately"
        }
    }
}

// A raw value gives every case a backing scalar and a failable initialiser.
enum TransitLine: String {
    case amber, cobalt, emerald, crimson

    var colour: String {
        switch self {
        case .amber: "#c8a02a"
        case .cobalt: "#2a5cc8"
        case .emerald: "#2ac86b"
        case .crimson: "#c82a3c"
        }
    }
}

// Associated values carry different data per case.
enum Event {
    case reading(device: String, celsius: Double)
    case offline(String)
    case heartbeat
}

// An indirect enum can refer to itself.
indirect enum Expression {
    case value(Int)
    case add(Expression, Expression)
    case multiply(Expression, Expression)

    func evaluate() -> Int {
        switch self {
        case .value(let n): n
        case .add(let left, let right): left.evaluate() + right.evaluate()
        case .multiply(let left, let right): left.evaluate() * right.evaluate()
        }
    }
}

for priority in Priority.allCases {
    print("\(priority.rawValue.padding(toLength: 7, withPad: " ", startingAt: 0)) \(priority.responseTime)")
}

print(TransitLine(rawValue: "cobalt")?.colour ?? "unknown")
print("unknown raw value:", TransitLine(rawValue: "violet") as Any)

let events: [Event] = [
    .reading(device: "SNS-01", celsius: -18.4),
    .reading(device: "SNS-04", celsius: 31.2),
    .offline("SNS-09"),
    .heartbeat,
]

for event in events {
    let message: String
    switch event {
    case .reading(let device, let celsius) where celsius > 30:
        message = "\(device) is too warm at \(celsius)C"
    case .reading(let device, let celsius) where celsius < 0:
        message = "\(device) is below freezing at \(celsius)C"
    case .reading(let device, _):
        message = "\(device) is nominal"
    case .offline(let device):
        message = "\(device) is offline"
    case .heartbeat:
        message = "heartbeat"
    }
    print(message)
}

// if case matches one case without a full switch.
if case .reading(let device, _) = events[0] {
    print("first event came from \(device)")
}

let expression = Expression.add(.value(2), .multiply(.value(3), .value(4)))
print("2 + 3 * 4 =", expression.evaluate())

// Enums can conform to protocols and have static members.
extension Priority: Comparable {
    static func < (left: Priority, right: Priority) -> Bool {
        allCases.firstIndex(of: left)! < allCases.firstIndex(of: right)!
    }
}
print("sorted:", [Priority.urgent, .low, .high].sorted().map(\.rawValue))
