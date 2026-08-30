// Result<Success, Failure> makes a fallible outcome a value that can be
// stored, passed, and transformed before anyone deals with the failure.

import Foundation

enum LoadError: Error, CustomStringConvertible {
    case notFound(String)
    case notANumber(String)
    case outOfRange(Int)

    var description: String {
        switch self {
        case .notFound(let key): "\(key) is missing"
        case .notANumber(let raw): "\"\(raw)\" is not a number"
        case .outOfRange(let value): "\(value) is outside 1-6"
        }
    }
}

/// mapError has to produce another Error, so a plain String will not do.
struct WrappedError: Error, CustomStringConvertible {
    let description: String
}

let configuration = ["port": "8080", "zone": "3", "timeout": "soon", "retries": "900"]

func read(_ key: String) -> Result<String, LoadError> {
    configuration[key].map { .success($0) } ?? .failure(.notFound(key))
}

func parseZone(_ raw: String) -> Result<Int, LoadError> {
    guard let value = Int(raw) else { return .failure(.notANumber(raw)) }
    guard (1...6).contains(value) else { return .failure(.outOfRange(value)) }
    return .success(value)
}

// map transforms the success; mapError transforms the failure; flatMap
// chains another fallible step.
func zone(for key: String) -> Result<Int, LoadError> {
    read(key).flatMap(parseZone)
}

for key in ["zone", "timeout", "retries", "missing"] {
    switch zone(for: key) {
    case .success(let value):
        print("\(key.padding(toLength: 9, withPad: " ", startingAt: 0)) -> zone \(value)")
    case .failure(let error):
        print("\(key.padding(toLength: 9, withPad: " ", startingAt: 0)) !  \(error)")
    }
}

// The accessors, when a full switch is more than the situation needs.
print("optional success:", try? zone(for: "zone").get())
print("with a default:", (try? zone(for: "missing").get()) ?? 1)
print("mapped:", zone(for: "zone").map { $0 * 10 })
print("mapped error:", zone(for: "missing").mapError { WrappedError(description: "wrapped: \($0)") })

// Result captures a throwing call, which bridges the two error styles.
func throwingParse(_ raw: String) throws -> Int {
    try parseZone(raw).get()
}
let captured = Result { try throwingParse("9") }
print("captured a throw:", captured)

// Collecting a batch, keeping the failures rather than stopping at one.
let outcomes = ["1", "nine", "4", "12"].map(parseZone)
let (succeeded, failed) = outcomes.reduce(into: ([Int](), [LoadError]())) { totals, outcome in
    switch outcome {
    case .success(let value): totals.0.append(value)
    case .failure(let error): totals.1.append(error)
    }
}
print("succeeded \(succeeded), failed \(failed.map(\.description))")

// Stopping at the first failure instead.
func firstFailureWins(_ raws: [String]) -> Result<[Int], LoadError> {
    var values: [Int] = []
    for raw in raws {
        switch parseZone(raw) {
        case .success(let value): values.append(value)
        case .failure(let error): return .failure(error)
        }
    }
    return .success(values)
}
print("all good:", firstFailureWins(["1", "2", "3"]))
print("one bad:", firstFailureWins(["1", "nine", "3"]))

// A completion handler taking a Result is the pre-async convention.
func load(_ key: String, completion: (Result<Int, LoadError>) -> Void) {
    completion(zone(for: key))
}
load("zone") { print("callback got:", $0) }
load("missing") { print("callback got:", $0) }
