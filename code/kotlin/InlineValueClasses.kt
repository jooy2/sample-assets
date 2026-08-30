// A value class wraps one property and is erased to it at runtime, so a
// type-safe wrapper costs nothing.

@JvmInline
value class StationId(val value: String) {
    init {
        require(value.startsWith("ST-")) { "a station id starts with ST-" }
    }

    val number: Int get() = value.removePrefix("ST-").toInt()
}

@JvmInline
value class Cents(val amount: Long) {
    operator fun plus(other: Cents) = Cents(amount + other.amount)
    operator fun times(factor: Int) = Cents(amount * factor)

    override fun toString() = "%.2f".format(amount / 100.0)
}

@JvmInline
value class Zone(val level: Int) : Comparable<Zone> {
    init {
        require(level in 1..6) { "zone $level is outside 1-6" }
    }

    override fun compareTo(other: Zone) = level.compareTo(other.level)
    override fun toString() = "zone $level"
}

// Two String parameters can be swapped by mistake; two value classes cannot.
fun connect(from: StationId, to: StationId) = "${from.value} -> ${to.value}"

fun main() {
    val alder = StationId("ST-001")
    val quill = StationId("ST-002")

    println(connect(alder, quill))
    println("number: ${alder.number}")

    // connect(alder.value, quill.value) would not compile: String is not StationId.

    val subtotal = Cents(7450)
    val shipping = Cents(499)
    println("total ${subtotal + shipping}, three of them ${subtotal * 3}")

    val zones = listOf(Zone(3), Zone(1), Zone(5))
    println("sorted: ${zones.sorted()}")
    println("deepest: ${zones.max()}")

    runCatching { Zone(9) }.onFailure { println("rejected: ${it.message}") }
    runCatching { StationId("A-1") }.onFailure { println("rejected: ${it.message}") }

    // Equality is by the wrapped value, and there is no wrapper object at
    // runtime for the common case.
    println("equal: ${StationId("ST-001") == alder}")
}
