// Stored properties, computed properties, observers, lazy initialisation,
// and subscripts.

import Foundation

struct Temperature {
    // A stored property holds the value.
    var celsius: Double

    // A computed property derives it, and can be writable.
    var fahrenheit: Double {
        get { celsius * 9 / 5 + 32 }
        set { celsius = (newValue - 32) * 5 / 9 }
    }

    // A read-only computed property needs no `get`.
    var kelvin: Double { celsius + 273.15 }

    var description: String {
        String(format: "%.1fC / %.1fF", celsius, fahrenheit)
    }
}

final class Sensor {
    let id: String

    // willSet and didSet run around every assignment, but not during init.
    var celsius: Double = 20 {
        willSet {
            print("  \(id): \(celsius) -> \(newValue)")
        }
        didSet {
            if abs(celsius - oldValue) > 5 {
                alarms += 1
            }
        }
    }

    private(set) var alarms = 0

    // A property observer can clamp, but a wrapper or a setter is clearer.
    var battery: Int = 100 {
        didSet { battery = min(100, max(0, battery)) }
    }

    // lazy defers the work until the first read, and runs it once.
    lazy var calibration: Double = {
        print("  computing the calibration for \(id)")
        return (1...1_000).reduce(0.0) { $0 + Double($1) } / 1_000
    }()

    // A static property belongs to the type.
    static var built = 0

    init(id: String) {
        self.id = id
        Sensor.built += 1
    }

    // A subscript makes the type indexable.
    private var readings: [String: Double] = [:]

    subscript(key: String) -> Double? {
        get { readings[key] }
        set { readings[key] = newValue }
    }

    subscript(key: String, default fallback: Double) -> Double {
        readings[key] ?? fallback
    }
}

var temperature = Temperature(celsius: 21.5)
print(temperature.description, "| kelvin", temperature.kelvin)

temperature.fahrenheit = 100
print("after setting fahrenheit:", temperature.description)

let sensor = Sensor(id: "SNS-01")
sensor.celsius = 22.0
sensor.celsius = 31.5
sensor.celsius = 21.0
print("alarms raised: \(sensor.alarms)")

sensor.battery = 140
print("battery clamped to \(sensor.battery)")

print("before the first read, nothing has been computed")
print("calibration \(sensor.calibration)")
print("calibration \(sensor.calibration)")

sensor["morning"] = 19.4
sensor["evening"] = 23.8
print("subscript:", sensor["morning"] as Any, "| missing:", sensor["night", default: 0])

print("sensors built:", Sensor.built)

// A global computed property, and one on an extension.
extension Temperature {
    var isFreezing: Bool { celsius <= 0 }
}
print("freezing:", Temperature(celsius: -3).isFreezing)
