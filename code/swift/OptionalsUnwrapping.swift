// Optionals: Swift's answer to null. A value is either there or it is not,
// and the compiler makes you say which case you are handling.

struct Station {
    let name: String
    let nickname: String?
    let zone: Int
}

let network: [String: Station] = [
    "alder": Station(name: "Alder Cross", nickname: "the Cross", zone: 2),
    "quill": Station(name: "Quill Wharf", nickname: nil, zone: 3),
]

// Optional binding: the value is unwrapped only inside the branch.
for handle in ["alder", "quill", "nether"] {
    if let station = network[handle] {
        print("\(handle) -> \(station.name) (zone \(station.zone))")
    } else {
        print("\(handle) is not on the network")
    }
}

// The shorthand when the names match.
if let station = network["alder"], let nickname = station.nickname {
    print("nickname: \(nickname)")
}

// guard unwraps for the rest of the scope, and must exit on failure.
func label(for handle: String) -> String {
    guard let station = network[handle] else {
        return "unknown"
    }
    return station.nickname ?? station.name
}
print(label(for: "quill"), "/", label(for: "nether"))

// ?? supplies a default; the right side is evaluated only when needed.
print("zone:", network["nether"]?.zone ?? -1)

// Optional chaining stops at the first nil and yields an Optional.
print("nickname length:", network["quill"]?.nickname?.count as Any)
print("uppercased:", network["alder"]?.name.uppercased() ?? "(none)")

// map and flatMap transform without unwrapping by hand.
let zone: Int? = network["alder"].map { $0.zone * 10 }
let nickname: String? = network["alder"].flatMap { $0.nickname }
print("mapped:", zone as Any, "| flatMapped:", nickname as Any)

// Collections of optionals.
let nicknames = network.values.map { $0.nickname }
print("all:", nicknames)
print("without nils:", nicknames.compactMap { $0 })

// Pattern matching on an optional.
switch network["quill"] {
case .some(let station) where station.zone > 2:
    print("\(station.name) is beyond zone 2")
case .some(let station):
    print("\(station.name) is close in")
case .none:
    print("nothing there")
}

// Force unwrapping crashes on nil, so it belongs only where nil is a bug.
let definitely = network["alder"]!
print("force unwrapped:", definitely.name)

// An implicitly unwrapped optional behaves like a normal value until it is
// nil, which is why it is rare outside of two-phase initialisation.
var late: String! = nil
late = "assigned before it is read"
print(late)
