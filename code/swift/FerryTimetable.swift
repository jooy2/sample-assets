// FerryTimetable.swift — a timetable domain model and the queries over it.
//
// Enums with associated values and raw values, protocols with associated
// types and default implementations, generics with constraints, Codable,
// property wrappers, result builders, custom operators, and Sequence
// conformance. Errors are thrown and validated at construction.
//
//   swiftc -O FerryTimetable.swift -o timetable && ./timetable
//   swift FerryTimetable.swift
//
// The cooperative, the routes, and every sailing below are invented.

import Foundation

// ------------------------------------------------------------------- clock

/// Minutes since midnight, with arithmetic that wraps at the day boundary.
struct TimeOfDay: Hashable, Comparable, Codable, CustomStringConvertible {
    let minutes: Int

    init(_ minutes: Int) {
        // A sailing at 25:10 is a sailing at 01:10 the next day.
        self.minutes = ((minutes % 1440) + 1440) % 1440
    }

    init(hour: Int, minute: Int) {
        self.init(hour * 60 + minute)
    }

    init?(_ text: String) {
        let parts = text.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else { return nil }
        self.init(hour: hour, minute: minute)
    }

    var hour: Int { minutes / 60 }
    var minute: Int { minutes % 60 }

    var description: String {
        String(format: "%02d:%02d", hour, minute)
    }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutes < rhs.minutes
    }

    static func + (lhs: TimeOfDay, minutes: Int) -> TimeOfDay {
        TimeOfDay(lhs.minutes + minutes)
    }

    /// Minutes from one time to another, going forwards through midnight.
    static func - (lhs: TimeOfDay, rhs: TimeOfDay) -> Int {
        let difference = lhs.minutes - rhs.minutes
        return difference >= 0 ? difference : difference + 1440
    }
}

/// A custom operator for "is this time within n minutes of that one".
infix operator ~=~ : ComparisonPrecedence

func ~=~ (lhs: TimeOfDay, rhs: (TimeOfDay, Int)) -> Bool {
    let (target, tolerance) = rhs
    let forwards = lhs - target
    let backwards = target - lhs
    return min(forwards, backwards) <= tolerance
}

// ------------------------------------------------------------------ model

enum Day: Int, CaseIterable, Codable, CustomStringConvertible {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    var isWeekend: Bool { self == .saturday || self == .sunday }

    var description: String {
        ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][rawValue]
    }
}

/// When a sailing runs. The associated values carry the exceptions, so the
/// pattern match in `runs(on:)` is exhaustive by construction.
enum Schedule: Codable, CustomStringConvertible {
    case daily
    case weekdays
    case weekends
    case only(Set<Day>)
    case except(Set<Day>)
    case seasonal(from: Int, to: Int, base: [Day])   // months, inclusive

    func runs(on day: Day, month: Int = 6) -> Bool {
        switch self {
        case .daily:
            return true
        case .weekdays:
            return !day.isWeekend
        case .weekends:
            return day.isWeekend
        case .only(let days):
            return days.contains(day)
        case .except(let days):
            return !days.contains(day)
        case .seasonal(let from, let to, let base):
            let inSeason = from <= to
                ? (from...to).contains(month)
                : month >= from || month <= to
            return inSeason && base.contains(day)
        }
    }

    var description: String {
        switch self {
        case .daily: return "daily"
        case .weekdays: return "Mon-Fri"
        case .weekends: return "Sat-Sun"
        case .only(let days):
            return days.sorted { $0.rawValue < $1.rawValue }
                .map(\.description).joined(separator: ",")
        case .except(let days):
            return "daily except " + days.sorted { $0.rawValue < $1.rawValue }
                .map(\.description).joined(separator: ",")
        case .seasonal(let from, let to, _):
            return "months \(from)-\(to)"
        }
    }
}

enum Vessel: String, Codable, CaseIterable {
    case kestrel = "MV Kestrel"
    case halloway = "MV Halloway"
    case marlow = "MV Marlow"
    case fenwick = "MV Fenwick"

    /// How many passengers the vessel takes.
    var capacity: Int {
        switch self {
        case .kestrel: return 240
        case .halloway: return 120
        case .marlow: return 380
        case .fenwick: return 90
        }
    }

    var carriesVehicles: Bool { self == .marlow || self == .kestrel }
}

enum TimetableError: Error, CustomStringConvertible {
    case emptyRoute(String)
    case noSailings(String)
    case overlappingVessel(Vessel, TimeOfDay, TimeOfDay)
    case badTime(String)

    var description: String {
        switch self {
        case .emptyRoute(let name): return "route \"\(name)\" has no terminals"
        case .noSailings(let name): return "route \"\(name)\" has no sailings"
        case .overlappingVessel(let vessel, let a, let b):
            return "\(vessel.rawValue) is booked at both \(a) and \(b)"
        case .badTime(let text): return "not a time: \(text)"
        }
    }
}

// ------------------------------------------------------------- property wrapper

/// Keeps a value inside bounds instead of trusting the caller.
@propertyWrapper
struct Clamped<Value: Comparable> {
    private var stored: Value
    private let range: ClosedRange<Value>

    init(wrappedValue: Value, _ range: ClosedRange<Value>) {
        self.range = range
        self.stored = min(max(wrappedValue, range.lowerBound), range.upperBound)
    }

    var wrappedValue: Value {
        get { stored }
        set { stored = min(max(newValue, range.lowerBound), range.upperBound) }
    }

    var projectedValue: ClosedRange<Value> { range }
}

// ------------------------------------------------------------------ sailing

struct Sailing: Identifiable, Codable, CustomStringConvertible {
    let id: String
    let departs: TimeOfDay
    let arrives: TimeOfDay
    let vessel: Vessel
    let schedule: Schedule

    @Clamped(0...100) var expectedLoad: Int = 0

    init(id: String,
         departs: TimeOfDay,
         arrives: TimeOfDay,
         vessel: Vessel,
         schedule: Schedule = .daily,
         expectedLoad: Int = 50) {
        self.id = id
        self.departs = departs
        self.arrives = arrives
        self.vessel = vessel
        self.schedule = schedule
        self.expectedLoad = expectedLoad
    }

    var duration: Int { arrives - departs }

    var expectedPassengers: Int {
        vessel.capacity * expectedLoad / 100
    }

    var description: String {
        "\(departs)->\(arrives) \(vessel.rawValue) (\(schedule))"
    }

    // Codable cannot synthesise through a property wrapper with a default, so
    // the coding keys are written out.
    enum CodingKeys: String, CodingKey {
        case id, departs, arrives, vessel, schedule, expectedLoad
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        departs = try container.decode(TimeOfDay.self, forKey: .departs)
        arrives = try container.decode(TimeOfDay.self, forKey: .arrives)
        vessel = try container.decode(Vessel.self, forKey: .vessel)
        schedule = try container.decode(Schedule.self, forKey: .schedule)
        expectedLoad = try container.decode(Int.self, forKey: .expectedLoad)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(departs, forKey: .departs)
        try container.encode(arrives, forKey: .arrives)
        try container.encode(vessel, forKey: .vessel)
        try container.encode(schedule, forKey: .schedule)
        try container.encode(expectedLoad, forKey: .expectedLoad)
    }
}

// ------------------------------------------------------------------- route

struct Route: Identifiable, Codable {
    let id: String
    let name: String
    let from: String
    let to: String
    private(set) var sailings: [Sailing]

    init(id: String, name: String, from: String, to: String,
         sailings: [Sailing]) throws {
        guard !from.isEmpty, !to.isEmpty else { throw TimetableError.emptyRoute(name) }
        guard !sailings.isEmpty else { throw TimetableError.noSailings(name) }

        self.id = id
        self.name = name
        self.from = from
        self.to = to
        self.sailings = sailings.sorted { $0.departs < $1.departs }
    }

    func sailings(on day: Day, month: Int = 6) -> [Sailing] {
        sailings.filter { $0.schedule.runs(on: day, month: month) }
    }

    /// The next sailing at or after a time, wrapping to the first of the day.
    func next(after time: TimeOfDay, on day: Day) -> Sailing? {
        let running = sailings(on: day)
        return running.first { $0.departs >= time } ?? running.first
    }

    var firstDeparture: TimeOfDay? { sailings.first?.departs }
    var lastDeparture: TimeOfDay? { sailings.last?.departs }

    /// The largest gap between consecutive departures, which is the number
    /// passengers actually feel.
    func longestGap(on day: Day) -> (minutes: Int, after: TimeOfDay)? {
        let running = sailings(on: day)
        guard running.count > 1 else { return nil }

        var worst = (minutes: 0, after: running[0].departs)
        for (earlier, later) in zip(running, running.dropFirst()) {
            let gap = later.departs - earlier.departs
            if gap > worst.minutes { worst = (gap, earlier.departs) }
        }
        return worst
    }
}

/// Iterating a route yields its sailings.
extension Route: Sequence {
    func makeIterator() -> Array<Sailing>.Iterator { sailings.makeIterator() }
}

// ------------------------------------------------------------- result builder

/// Lets a timetable be written as a nested literal rather than an array.
@resultBuilder
struct SailingBuilder {
    static func buildBlock(_ components: [Sailing]...) -> [Sailing] {
        components.flatMap { $0 }
    }

    static func buildExpression(_ sailing: Sailing) -> [Sailing] { [sailing] }

    static func buildExpression(_ sailings: [Sailing]) -> [Sailing] { sailings }

    static func buildOptional(_ component: [Sailing]?) -> [Sailing] {
        component ?? []
    }

    static func buildEither(first component: [Sailing]) -> [Sailing] { component }

    static func buildEither(second component: [Sailing]) -> [Sailing] { component }

    static func buildArray(_ components: [[Sailing]]) -> [Sailing] {
        components.flatMap { $0 }
    }
}

extension Route {
    init(id: String, name: String, from: String, to: String,
         @SailingBuilder sailings build: () -> [Sailing]) throws {
        try self.init(id: id, name: name, from: from, to: to, sailings: build())
    }
}

/// Generate an hourly (or n-minutely) run of sailings.
func repeating(_ prefix: String,
               every minutes: Int,
               from start: TimeOfDay,
               until end: TimeOfDay,
               crossing duration: Int,
               vessel: Vessel,
               schedule: Schedule = .daily,
               load: Int = 55) -> [Sailing] {
    var result: [Sailing] = []
    var departure = start
    var index = 1

    while departure <= end {
        result.append(Sailing(id: "\(prefix)-\(index)",
                              departs: departure,
                              arrives: departure + duration,
                              vessel: vessel,
                              schedule: schedule,
                              expectedLoad: load))
        departure = departure + minutes
        index += 1
        if departure.minutes < start.minutes { break }   // wrapped past midnight
    }
    return result
}

// ------------------------------------------------------------- the network

/// Anything that can be summarised as a row of a report.
protocol Reportable {
    associatedtype Key: Hashable
    var reportKey: Key { get }
    var reportCells: [String] { get }
}

extension Reportable {
    var reportLine: String { reportCells.joined(separator: "  ") }
}

extension Route: Reportable {
    var reportKey: String { id }
    var reportCells: [String] {
        [id.padded(4),
         name.padded(16),
         "\(sailings.count)".leftPadded(3),
         (firstDeparture?.description ?? "-").padded(5),
         (lastDeparture?.description ?? "-").padded(5)]
    }
}

extension String {
    func padded(_ width: Int) -> String {
        count >= width ? self : self + String(repeating: " ", count: width - count)
    }

    func leftPadded(_ width: Int) -> String {
        count >= width ? self : String(repeating: " ", count: width - count) + self
    }
}

struct Network {
    private(set) var routes: [Route]

    init(routes: [Route]) { self.routes = routes }

    subscript(id: String) -> Route? {
        routes.first { $0.id == id }
    }

    /// Sailings across every route on a day, in departure order.
    func departures(on day: Day, month: Int = 6) -> [(route: Route, sailing: Sailing)] {
        routes
            .flatMap { route in route.sailings(on: day, month: month).map { (route, $0) } }
            .sorted { $0.1.departs < $1.1.departs }
    }

    /// Where one vessel is asked to be in two places at once.
    func vesselConflicts(on day: Day) -> [(Vessel, Sailing, Sailing)] {
        var byVessel: [Vessel: [Sailing]] = [:]
        for (_, sailing) in departures(on: day) {
            byVessel[sailing.vessel, default: []].append(sailing)
        }

        var conflicts: [(Vessel, Sailing, Sailing)] = []
        for (vessel, sailings) in byVessel {
            for (earlier, later) in zip(sailings, sailings.dropFirst())
            where later.departs < earlier.arrives {
                conflicts.append((vessel, earlier, later))
            }
        }
        return conflicts.sorted { $0.1.departs < $1.1.departs }
    }

    func expectedPassengers(on day: Day) -> Int {
        departures(on: day).reduce(0) { $0 + $1.sailing.expectedPassengers }
    }

    /// Group any reportable collection by its key, generically.
    func grouped<T: Reportable>(_ items: [T]) -> [T.Key: [T]] {
        Dictionary(grouping: items, by: \.reportKey)
    }
}

// --------------------------------------------------------------------- demo

func buildNetwork() throws -> Network {
    let harbourLoop = try Route(
        id: "HRB", name: "Harbour Loop", from: "Fenwick Quay", to: "Marlow Street"
    ) {
        repeating("HRB-AM", every: 20,
                  from: TimeOfDay(hour: 6, minute: 20), until: TimeOfDay(hour: 9, minute: 40),
                  crossing: 19, vessel: .marlow, load: 78)
        repeating("HRB-MID", every: 30,
                  from: TimeOfDay(hour: 10, minute: 0), until: TimeOfDay(hour: 15, minute: 30),
                  crossing: 19, vessel: .marlow, load: 41)
        repeating("HRB-PM", every: 20,
                  from: TimeOfDay(hour: 16, minute: 0), until: TimeOfDay(hour: 19, minute: 20),
                  crossing: 19, vessel: .marlow, load: 72)
        Sailing(id: "HRB-LATE", departs: TimeOfDay(hour: 22, minute: 15),
                arrives: TimeOfDay(hour: 22, minute: 34), vessel: .fenwick,
                schedule: .only([.friday, .saturday]), expectedLoad: 64)
    }

    let kestrelPoint = try Route(
        id: "KSP", name: "Kestrel Point", from: "Fenwick Quay", to: "Kestrel Point"
    ) {
        repeating("KSP", every: 30,
                  from: TimeOfDay(hour: 7, minute: 0), until: TimeOfDay(hour: 19, minute: 0),
                  crossing: 26, vessel: .kestrel, load: 58)
        Sailing(id: "KSP-EARLY", departs: TimeOfDay(hour: 6, minute: 15),
                arrives: TimeOfDay(hour: 6, minute: 41), vessel: .kestrel,
                schedule: .weekdays, expectedLoad: 88)
    }

    let halloway = try Route(
        id: "HLW", name: "Halloway", from: "Marlow Street", to: "Halloway Bank"
    ) {
        repeating("HLW", every: 60,
                  from: TimeOfDay(hour: 8, minute: 5), until: TimeOfDay(hour: 17, minute: 5),
                  crossing: 34, vessel: .halloway,
                  schedule: .except([.sunday]), load: 39)
        repeating("HLW-SUM", every: 60,
                  from: TimeOfDay(hour: 18, minute: 5), until: TimeOfDay(hour: 20, minute: 5),
                  crossing: 34, vessel: .halloway,
                  schedule: .seasonal(from: 5, to: 9, base: Day.allCases), load: 52)
    }

    let nightCrossing = try Route(
        id: "NCR", name: "Night Crossing", from: "Fenwick Quay", to: "North Landing"
    ) {
        Sailing(id: "NCR-1", departs: TimeOfDay(hour: 21, minute: 30),
                arrives: TimeOfDay(hour: 22, minute: 12), vessel: .fenwick,
                schedule: .daily, expectedLoad: 46)
        Sailing(id: "NCR-2", departs: TimeOfDay(hour: 23, minute: 0),
                arrives: TimeOfDay(hour: 23, minute: 42), vessel: .fenwick,
                schedule: .daily, expectedLoad: 61)
        Sailing(id: "NCR-3", departs: TimeOfDay(hour: 0, minute: 30),
                arrives: TimeOfDay(hour: 1, minute: 12), vessel: .fenwick,
                schedule: .only([.friday, .saturday]), expectedLoad: 55)
    }

    return Network(routes: [harbourLoop, kestrelPoint, halloway, nightCrossing])
}

func run() throws {
    let network = try buildNetwork()

    print("--- the network ---")
    print("  ID    Route             #  First  Last")
    print("  ----  ----------------  -  -----  -----")
    for route in network.routes {
        print("  " + route.reportLine)
    }

    print("\n--- a Wednesday in June ---")
    let wednesday = network.departures(on: .wednesday, month: 6)
    print("  \(wednesday.count) sailings, "
          + "\(network.expectedPassengers(on: .wednesday)) expected passengers")
    for (route, sailing) in wednesday.prefix(6) {
        print("  \(sailing.departs)  \(route.id)  \(sailing.id.padded(10)) "
              + "\(sailing.vessel.rawValue.padded(12)) "
              + "\(sailing.expectedPassengers) expected")
    }
    print("  ...")

    print("\n--- a Sunday in June ---")
    let sunday = network.departures(on: .sunday, month: 6)
    print("  \(sunday.count) sailings, "
          + "\(network.expectedPassengers(on: .sunday)) expected passengers")
    let missing = Set(wednesday.map(\.sailing.id))
        .subtracting(sunday.map(\.sailing.id))
    print("  \(missing.count) sailing(s) that run on Wednesday do not run on Sunday")

    print("\n--- seasonal sailings ---")
    for month in [3, 6, 11] {
        let count = network.departures(on: .saturday, month: month).count
        print("  month \(month): \(count) Saturday sailing(s)")
    }

    print("\n--- longest gap in service ---")
    for route in network.routes {
        if let gap = route.longestGap(on: .wednesday) {
            print("  \(route.name.padded(16)) \(gap.minutes) minutes after \(gap.after)")
        }
    }

    print("\n--- next sailing after 08:47 on a Wednesday ---")
    for route in network.routes {
        let next = route.next(after: TimeOfDay(hour: 8, minute: 47), on: .wednesday)
        print("  \(route.name.padded(16)) \(next?.departs.description ?? "none")")
    }

    print("\n--- vessel conflicts ---")
    print("  in the published timetable on a Friday: "
          + "\(network.vesselConflicts(on: .friday).count)")

    // A second, deliberately broken timetable, so the check has something to
    // find. MV Fenwick cannot be on two crossings at once.
    let clashing = Network(routes: [
        try Route(id: "BAD", name: "Double booked",
                  from: "Fenwick Quay", to: "North Landing", sailings: [
            Sailing(id: "BAD-1", departs: TimeOfDay(hour: 9, minute: 0),
                    arrives: TimeOfDay(hour: 9, minute: 50), vessel: .fenwick),
            Sailing(id: "BAD-2", departs: TimeOfDay(hour: 9, minute: 30),
                    arrives: TimeOfDay(hour: 10, minute: 20), vessel: .fenwick),
            Sailing(id: "BAD-3", departs: TimeOfDay(hour: 10, minute: 0),
                    arrives: TimeOfDay(hour: 10, minute: 50), vessel: .fenwick),
            Sailing(id: "OK-1", departs: TimeOfDay(hour: 9, minute: 15),
                    arrives: TimeOfDay(hour: 9, minute: 45), vessel: .halloway),
        ]),
    ])
    for (vessel, earlier, later) in clashing.vesselConflicts(on: .wednesday) {
        print("  \(vessel.rawValue): \(earlier.id) arrives \(earlier.arrives) "
              + "but \(later.id) departs \(later.departs)")
    }

    print("\n--- time arithmetic across midnight ---")
    let lastNight = TimeOfDay(hour: 23, minute: 0)
    let arrival = lastNight + 42
    print("  23:00 plus 42 minutes is \(arrival)")
    print("  from 23:00 to 00:30 is \(TimeOfDay(hour: 0, minute: 30) - lastNight) minutes")
    print("  00:30 is within 40 minutes of 23:55: "
          + "\(TimeOfDay(hour: 0, minute: 30) ~=~ (TimeOfDay(hour: 23, minute: 55), 40))")
    print("  00:30 is within 20 minutes of 23:55: "
          + "\(TimeOfDay(hour: 0, minute: 30) ~=~ (TimeOfDay(hour: 23, minute: 55), 20))")

    print("\n--- the clamped property wrapper ---")
    var overbooked = Sailing(id: "TEST", departs: TimeOfDay(hour: 9, minute: 0),
                             arrives: TimeOfDay(hour: 9, minute: 30), vessel: .fenwick,
                             expectedLoad: 250)
    print("  asked for 250% load, stored \(overbooked.expectedLoad)%")
    overbooked.expectedLoad = -30
    print("  asked for -30% load, stored \(overbooked.expectedLoad)%")

    print("\n--- Codable round trip ---")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(network.routes[3])
    print("  encoded \(data.count) bytes")

    let decoded = try JSONDecoder().decode(Route.self, from: data)
    print("  decoded \(decoded.name) with \(decoded.sailings.count) sailing(s)")
    print("  first sailing matches: "
          + "\(decoded.sailings[0].departs == network.routes[3].sailings[0].departs)")

    print("\n--- iterating a route directly ---")
    for sailing in network.routes[3] {
        print("  \(sailing)")
    }

    print("\n--- refusals ---")
    let attempts: [(String, () throws -> Void)] = [
        ("a route with no sailings", {
            _ = try Route(id: "X", name: "Empty", from: "A", to: "B", sailings: [])
        }),
        ("a route with no terminals", {
            _ = try Route(id: "Y", name: "Nowhere", from: "", to: "",
                          sailings: [Sailing(id: "s", departs: TimeOfDay(0),
                                             arrives: TimeOfDay(10), vessel: .fenwick)])
        }),
    ]
    for (label, attempt) in attempts {
        do {
            try attempt()
            print("  \(label): unexpectedly allowed")
        } catch let error as TimetableError {
            print("  \(label): \(error)")
        }
    }
    print("  \"25:70\" parses as a time: \(TimeOfDay("25:70") != nil)")
    print("  \"09:05\" parses as a time: \(TimeOfDay("09:05") != nil)")
}

do {
    try run()
} catch {
    print("failed: \(error)")
    exit(1)
}
