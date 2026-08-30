// Closures: the syntax, the capture rules, and the higher-order functions
// that take them.

import Foundation

struct Station {
    let name: String
    let line: String
    let zone: Int
    let platforms: Int
}

let stations = [
    Station(name: "Alder Cross", line: "Amber", zone: 2, platforms: 2),
    Station(name: "Quill Wharf", line: "Cobalt", zone: 3, platforms: 4),
    Station(name: "Saltwick Halt", line: "Amber", zone: 5, platforms: 1),
    Station(name: "Nether Gate", line: "Emerald", zone: 2, platforms: 3),
]

// The full form, then everything Swift lets you leave out.
let byZoneFull: (Station, Station) -> Bool = { (left: Station, right: Station) -> Bool in
    return left.zone < right.zone
}
let byZoneShort: (Station, Station) -> Bool = { $0.zone < $1.zone }

print(stations.sorted(by: byZoneFull).map(\.name))
print(stations.sorted(by: byZoneShort).first?.name as Any)

// Trailing closure syntax, and the key-path shorthand.
print(stations.filter { $0.zone <= 3 }.map(\.name))
print("platforms:", stations.reduce(0) { $0 + $1.platforms })
print("deepest:", stations.max { $0.zone < $1.zone }?.name as Any)
print("any in zone 5:", stations.contains { $0.zone == 5 })
print("all have platforms:", stations.allSatisfy { $0.platforms > 0 })
print("first deep:", stations.first { $0.zone > 4 }?.name as Any)
print("index:", stations.firstIndex { $0.line == "Emerald" } as Any)

// compactMap drops nils; flatMap flattens.
let parsed = ["2", "three", "5"].compactMap { Int($0) }
print("parsed:", parsed)
print("words:", stations.flatMap { $0.name.split(separator: " ") }.map(String.init))

// Grouping and partitioning.
print("grouped:", Dictionary(grouping: stations, by: \.line).mapValues { $0.count })

// A closure captures by reference, so it sees later changes.
var threshold = 3
let shallow = { (station: Station) in station.zone <= threshold }
threshold = 1
print("captured by reference:", stations.filter(shallow).count)

// A capture list takes a copy at the point the closure is made.
threshold = 3
let frozen = { [threshold] (station: Station) in station.zone <= threshold }
threshold = 1
print("captured by value:", stations.filter(frozen).count)

// A closure that outlives the call needs @escaping.
var pending: [() -> String] = []
func schedule(_ work: @escaping () -> String) {
    pending.append(work)
}
schedule { "ran later" }
print(pending.map { $0() })

// autoclosure wraps an expression so it is evaluated only when used.
func logIfNeeded(_ enabled: Bool, _ message: @autoclosure () -> String) {
    if enabled { print("log:", message()) }
}
logIfNeeded(true, "this string is built")
logIfNeeded(false, "this one never is")

// Returning a closure keeps its captures alive.
func fareCalculator(base: Double) -> (Int) -> Double {
    { zones in base + Double(zones) * 0.85 }
}
print(String(format: "three zones: %.2f", fareCalculator(base: 2.40)(3)))

// A mutable capture gives a closure its own state.
func makeCounter(start: Int) -> () -> Int {
    var value = start
    return {
        value += 1
        return value
    }
}
let ticket = makeCounter(start: 1000)
print(ticket(), ticket(), ticket())
