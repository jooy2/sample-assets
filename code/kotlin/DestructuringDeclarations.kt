// Destructuring calls component1(), component2(), and so on, which data
// classes, pairs, triples, and map entries all provide.

data class Reading(val device: String, val celsius: Double, val battery: Int)

/** Any class can opt in by declaring the componentN operators itself. */
class GridPoint(val x: Int, val y: Int) {
    operator fun component1() = x
    operator fun component2() = y
}

fun splitSeconds(total: Int): Triple<Int, Int, Int> =
    Triple(total / 3600, (total % 3600) / 60, total % 60)

fun main() {
    val (device, celsius, battery) = Reading("SNS-01", 21.4, 88)
    println("$device: ${celsius}C, battery $battery%")

    // Underscore skips a component that is not needed.
    val (_, onlyTemperature) = Reading("SNS-04", 31.2, 74)
    println("temperature only: $onlyTemperature")

    val (hours, minutes, seconds) = splitSeconds(9045)
    println("${hours}h ${minutes}m ${seconds}s")

    val (x, y) = GridPoint(45, -10)
    println("grid $x,$y")

    // In a loop, over pairs and over map entries.
    val readings = listOf(
        Reading("SNS-01", 21.4, 88),
        Reading("SNS-04", 31.2, 74),
        Reading("SNS-07", 19.6, 9),
    )
    for ((id, temperature, charge) in readings) {
        val flag = when {
            charge < 15 -> "battery low"
            temperature > 30 -> "too warm"
            else -> "ok"
        }
        println("  ${id.padEnd(8)} $flag")
    }

    val zones = mapOf("Alder Cross" to 2, "Quill Wharf" to 3)
    for ((station, zone) in zones) {
        println("  $station sits in zone $zone")
    }

    // In a lambda's parameter list.
    println(zones.map { (station, zone) -> "$station=$zone" })
    println(readings.map { (id, _, charge) -> id to charge })

    // Returning several values without declaring a class.
    val (minimum, maximum) = readings.map { it.celsius }.let { it.min() to it.max() }
    println("range $minimum..$maximum")
}
