// A delegated property hands get and set to another object: lazy, observable,
// a map, or one of your own.

import kotlin.properties.Delegates
import kotlin.properties.ReadWriteProperty
import kotlin.reflect.KProperty

class Configuration(source: Map<String, Any?>) {
    // Delegating to a map: the property name is the key.
    val host: String by source
    val port: Int by source
    val debug: Boolean by source
}

/** A delegate of your own: clamps whatever is assigned into a range. */
class Clamped(private var value: Int, private val range: IntRange) : ReadWriteProperty<Any?, Int> {
    override fun getValue(thisRef: Any?, property: KProperty<*>): Int = value

    override fun setValue(thisRef: Any?, property: KProperty<*>, value: Int) {
        this.value = value.coerceIn(range)
    }
}

class Sensor(id: String) {
    // lazy runs the block once, on first read.
    val calibration: Double by lazy {
        println("  computing the calibration for $id")
        21.5
    }

    // observable fires after every assignment.
    var status: String by Delegates.observable("ok") { _, old, new ->
        println("  status $old -> $new")
    }

    // vetoable can refuse the assignment.
    var battery: Int by Delegates.vetoable(100) { _, _, new -> new in 0..100 }

    var zone: Int by Clamped(1, 1..6)
}

fun main() {
    val configuration = Configuration(mapOf("host" to "localhost", "port" to 8080, "debug" to true))
    println("${configuration.host}:${configuration.port} debug=${configuration.debug}")

    val sensor = Sensor("SNS-01")
    println("before the first read, nothing has been computed")
    println("calibration ${sensor.calibration}")
    println("calibration ${sensor.calibration} (cached)")

    sensor.status = "warning"
    sensor.status = "ok"

    sensor.battery = 40
    println("battery ${sensor.battery}")
    sensor.battery = 140 // vetoed
    println("battery still ${sensor.battery}")

    sensor.zone = 9
    println("zone clamped to ${sensor.zone}")
    sensor.zone = 4
    println("zone ${sensor.zone}")
}
