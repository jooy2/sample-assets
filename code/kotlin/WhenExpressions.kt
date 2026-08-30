// `when` is Kotlin's switch, but it is an expression, matches on more than
// equality, and can drop its subject entirely.

enum class Priority { LOW, NORMAL, HIGH, URGENT }

fun responseTime(priority: Priority): String = when (priority) {
    Priority.LOW -> "within a week"
    Priority.NORMAL -> "within two days"
    Priority.HIGH -> "within four hours"
    Priority.URGENT -> "immediately"
}

fun platformsFor(line: String): Int = when (line) {
    "Amber", "Cobalt" -> 4          // several values in one branch
    "Emerald", "Crimson" -> 3
    else -> 1
}

fun describeZone(zone: Int): String = when (zone) {
    in 1..2 -> "central"            // a range
    in 3..4 -> "suburban"
    !in 1..6 -> "off the network"   // a negated range
    else -> "outer"
}

fun typeOf(value: Any): String = when (value) {
    is Int -> "an Int of ${value.toString().length} digits"  // smart cast
    is String -> "a String of ${value.length} characters"
    is List<*> -> "a List of ${value.size}"
    is Pair<*, *> -> "a Pair (${value.first}, ${value.second})"
    else -> "a ${value::class.simpleName}"
}

// Without a subject, each branch is just a condition.
fun fareBand(zone: Int, offPeak: Boolean): String = when {
    zone <= 2 && offPeak -> "cheap"
    zone <= 2 -> "standard"
    offPeak -> "long distance, off peak"
    else -> "long distance"
}

fun main() {
    Priority.entries.forEach { println("${it.name.padEnd(7)} ${responseTime(it)}") }

    listOf("Amber", "Slate", "Violet").forEach { println("$it -> ${platformsFor(it)} platforms") }
    listOf(1, 3, 5, 9).forEach { println("zone $it is ${describeZone(it)}") }

    listOf(42, "Alder Cross", listOf(1, 2, 3), 2 to 3, 1.5).forEach { println(typeOf(it)) }

    println(fareBand(2, offPeak = true))
    println(fareBand(5, offPeak = false))

    // `when` can capture its subject in a local.
    val result = when (val zone = platformsFor("Amber") + 1) {
        in 1..6 -> "usable zone $zone"
        else -> "out of range"
    }
    println(result)
}
