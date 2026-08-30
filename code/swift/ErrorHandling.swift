// throw, try, catch, and defer. Swift's errors are values, not exceptions
// that unwind through anything.

import Foundation

enum ValidationError: Error {
    case notANumber(String)
    case outOfRange(value: Int, allowed: ClosedRange<Int>)
    case missing(field: String)
}

// LocalizedError gives the type a readable message.
extension ValidationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notANumber(let raw): "\"\(raw)\" is not a number"
        case .outOfRange(let value, let allowed): "\(value) is outside \(allowed)"
        case .missing(let field): "\(field) is missing"
        }
    }
}

// `throws` is part of the signature, so callers cannot ignore it.
func parseZone(_ raw: String) throws -> Int {
    guard let zone = Int(raw) else {
        throw ValidationError.notANumber(raw)
    }
    let allowed = 1...6
    guard allowed.contains(zone) else {
        throw ValidationError.outOfRange(value: zone, allowed: allowed)
    }
    return zone
}

func loadStation(_ fields: [String: String]) throws -> (name: String, zone: Int) {
    guard let name = fields["name"] else {
        throw ValidationError.missing(field: "name")
    }
    // try propagates the error to this function's caller.
    let zone = try parseZone(fields["zone"] ?? "")
    return (name, zone)
}

for raw in ["3", "9", "east"] {
    do {
        print("\(raw.padding(toLength: 6, withPad: " ", startingAt: 0)) -> zone \(try parseZone(raw))")
    } catch ValidationError.outOfRange(let value, let allowed) {
        // Catching one case, with its associated values bound.
        print("\(raw.padding(toLength: 6, withPad: " ", startingAt: 0)) -> \(value) is not in \(allowed)")
    } catch let error as ValidationError {
        print("\(raw.padding(toLength: 6, withPad: " ", startingAt: 0)) -> \(error.localizedDescription)")
    } catch {
        print("something else went wrong: \(error)")
    }
}

// try? turns a throw into nil; try! crashes on one.
print("try?:", (try? parseZone("9")) as Any)
print("try? with a default:", (try? parseZone("east")) ?? 1)
print("try!:", try! parseZone("4"))

do {
    let station = try loadStation(["name": "Alder Cross", "zone": "2"])
    print("loaded \(station.name) in zone \(station.zone)")
    _ = try loadStation(["zone": "2"])
} catch {
    print("caught:", error.localizedDescription)
}

// defer runs on the way out of the scope, in reverse order, however the
// scope ends.
func withCleanup() throws -> String {
    var open = ["report.csv"]
    defer {
        open.removeAll()
        print("  cleaned up, \(open.count) handles left open")
    }
    defer { print("  this defer runs first") }

    guard open.count == 1 else {
        throw ValidationError.missing(field: "handle")
    }
    return "returned from the body"
}
do {
    print(try withCleanup())
} catch {
    print("withCleanup threw:", error)
}

// rethrows: this only throws if the closure it was given does.
func transform<T>(_ values: [String], using body: (String) throws -> T) rethrows -> [T] {
    try values.map(body)
}
do {
    print("rethrows:", try transform(["1", "2"], using: parseZone))
} catch {
    print("rethrows threw:", error)
}
print("no throw:", transform(["a", "b"], using: { $0.uppercased() }))

// Result captures a throwing call as a value.
let outcome = Result { try parseZone("9") }
switch outcome {
case .success(let zone): print("success \(zone)")
case .failure(let error): print("failure \(error.localizedDescription)")
}
