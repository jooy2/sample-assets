// Array, Set, and Dictionary, and the operations the standard library
// gives all of them through Sequence and Collection.

import Foundation

struct Station: Hashable {
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
    Station(name: "Bramble Fields", line: "Cobalt", zone: 4, platforms: 2),
]

// Array: ordered, indexed, and the workhorse.
print("count \(stations.count), first \(stations.first?.name ?? "-"), last \(stations.last?.name ?? "-")")
print("prefix:", stations.prefix(2).map(\.name))
print("suffix:", stations.suffix(2).map(\.name))
print("dropped:", stations.dropFirst(3).map(\.name))
print("sliced:", stations[1...2].map(\.name))
print("reversed:", stations.reversed().map(\.name).first as Any)
print("chunked:", stride(from: 0, to: stations.count, by: 2).map { Array(stations[$0..<min($0 + 2, stations.count)]).count })

// Transformations.
print("names:", stations.map(\.name))
print("inner:", stations.filter { $0.zone <= 3 }.map(\.name))
print("platforms:", stations.reduce(0) { $0 + $1.platforms })
print("words:", stations.flatMap { $0.name.split(separator: " ") }.count)
print("parsed:", ["2", "three", "5"].compactMap { Int($0) })
print("running total:", stations.reduce(into: [Int]()) { $0.append(($0.last ?? 0) + $1.platforms) })

// Sorting, including by several keys.
print("by zone:", stations.sorted { ($0.zone, $0.name) < ($1.zone, $1.name) }.map(\.name))
print("by key path:", stations.sorted(using: KeyPathComparator(\.platforms, order: .reverse)).first?.name as Any)

// Searching.
print("deepest:", stations.max { $0.zone < $1.zone }?.name as Any)
print("any in zone 5:", stations.contains { $0.zone == 5 })
print("all have platforms:", stations.allSatisfy { $0.platforms > 0 })
print("index:", stations.firstIndex { $0.line == "Emerald" } as Any)
print("split:", stations.split { $0.zone > 3 }.map { $0.count })

// Dictionary: unordered, keyed, and built several ways.
let zones = Dictionary(uniqueKeysWithValues: stations.map { ($0.name, $0.zone) })
print("lookup:", zones["Quill Wharf"] as Any, "| missing:", zones["Vellin Halt", default: 0])

let grouped = Dictionary(grouping: stations, by: \.line)
print("grouped:", grouped.mapValues { $0.count })

let platformsPerLine = stations.reduce(into: [String: Int]()) { totals, station in
    totals[station.line, default: 0] += station.platforms
}
print("platforms per line:", platformsPerLine)

// Merging resolves duplicates with a closure.
var counts = ["Amber": 2]
counts.merge(["Amber": 1, "Cobalt": 2]) { current, new in current + new }
print("merged:", counts)

print("filtered dictionary:", zones.filter { $0.value <= 2 }.keys.sorted())
print("sorted entries:", zones.sorted { $0.value < $1.value }.prefix(2).map(\.key))

// Set: unique, unordered, and fast at membership.
let amber = Set(stations.filter { $0.line == "Amber" }.map(\.name))
let stepFree: Set = ["Alder Cross", "Nether Gate"]

print("intersection:", amber.intersection(stepFree))
print("union:", amber.union(stepFree).count)
print("difference:", amber.subtracting(stepFree))
print("disjoint:", amber.isDisjoint(with: stepFree))
print("unique lines:", Set(stations.map(\.line)).sorted())

// Lazy defers the work until the values are actually needed.
var pulled = 0
let firstTwo = stations.lazy
    .map { station -> Station in pulled += 1; return station }
    .filter { $0.zone <= 3 }
    .prefix(2)
print("lazy result:", Array(firstTwo).map(\.name), "after pulling \(pulled)")
