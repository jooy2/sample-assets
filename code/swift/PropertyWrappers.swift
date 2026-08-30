// A property wrapper moves repeated get/set logic into a type of its own.

import Foundation

@propertyWrapper
struct Clamped<Value: Comparable> {
    private var value: Value
    private let range: ClosedRange<Value>

    init(wrappedValue: Value, _ range: ClosedRange<Value>) {
        self.range = range
        self.value = min(max(wrappedValue, range.lowerBound), range.upperBound)
    }

    var wrappedValue: Value {
        get { value }
        set { value = min(max(newValue, range.lowerBound), range.upperBound) }
    }
}

@propertyWrapper
struct Trimmed {
    private var value = ""

    init(wrappedValue: String) {
        self.wrappedValue = wrappedValue
    }

    var wrappedValue: String {
        get { value }
        set { value = newValue.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

/// projectedValue is what `$property` reaches, and can be a different type.
@propertyWrapper
struct Tracked<Value> {
    private var value: Value
    private var history: [Value] = []

    init(wrappedValue: Value) {
        self.value = wrappedValue
        self.history = [wrappedValue]
    }

    var wrappedValue: Value {
        get { value }
        set {
            value = newValue
            history.append(newValue)
        }
    }

    var projectedValue: [Value] { history }
}

@propertyWrapper
final class Lazy<Value> {
    private var build: (() -> Value)?
    private var cached: Value?

    init(wrappedValue build: @autoclosure @escaping () -> Value) {
        self.build = build
    }

    var wrappedValue: Value {
        if let cached { return cached }
        print("  computing once")
        let value = build!()
        cached = value
        build = nil
        return value
    }
}

struct Sensor {
    @Trimmed var id: String
    @Clamped(1...6) var zone: Int = 1
    @Clamped(0...100) var battery: Int = 100
    @Tracked var status: String = "ok"
    @Lazy var calibration: Double = expensiveCalibration()
}

func expensiveCalibration() -> Double {
    (1...1_000).reduce(0.0) { $0 + Double($1) } / 1_000
}

var sensor = Sensor(id: "  SNS-01  ")

print("trimmed id: [\(sensor.id)]")

sensor.zone = 9
print("zone clamped to \(sensor.zone)")
sensor.zone = 4
print("zone \(sensor.zone)")

sensor.battery = 140
print("battery clamped to \(sensor.battery)")

sensor.status = "warning"
sensor.status = "error"
sensor.status = "ok"
print("status \(sensor.status), history \(sensor.$status)")

print("calibration \(sensor.calibration)")
print("calibration \(sensor.calibration)")

// A wrapper is a type, so it can be used directly too.
var standalone = Clamped(wrappedValue: 12, 1...6)
print("standalone wrapper: \(standalone.wrappedValue)")
standalone.wrappedValue = 3
print("after assignment: \(standalone.wrappedValue)")
