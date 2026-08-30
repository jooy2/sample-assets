// Functions that take or return other functions, plus the syntax Kotlin
// gives them.

fun applyTwice(value: Int, transform: (Int) -> Int): Int = transform(transform(value))

/** Composes two functions left to right. */
infix fun <A, B, C> ((A) -> B).then(next: (B) -> C): (A) -> C = { next(this(it)) }

// The last lambda parameter can go outside the parentheses.
fun <T, R> measure(input: T, label: String, block: (T) -> R): R {
    val started = System.nanoTime()
    val result = block(input)
    val micros = (System.nanoTime() - started) / 1_000
    println("  $label took ${micros}us")
    return result
}

// Returning a function keeps the captured values alive.
fun fareCalculator(base: Double, perZone: Double): (Int) -> Double =
    { zones -> base + zones * perZone }

// inline puts the lambda's body at the call site, so no object is allocated.
inline fun <T> Iterable<T>.countMatching(predicate: (T) -> Boolean): Int {
    var count = 0
    for (item in this) {
        if (predicate(item)) count++
    }
    return count
}

fun main() {
    println(applyTwice(5) { it * 3 })
    println(applyTwice(5, Int::inc))

    val fare = fareCalculator(base = 2.40, perZone = 0.85)
    println("three zones cost %.2f".format(fare(3)))

    val stations = listOf("Alder Cross", "Quill Wharf", "Saltwick Halt", "Nether Gate")
    println("long names: ${stations.countMatching { it.length > 11 }}")

    val longest = measure(stations, "maxByOrNull") { list -> list.maxByOrNull(String::length) }
    println("longest: $longest")

    // Function references, of three kinds.
    val toLength: (String) -> Int = String::length
    val isLong: (String) -> Boolean = { it.length > 11 }
    val printer: (Any) -> Unit = ::println

    println(stations.map(toLength))
    println(stations.filter(isLong))
    stations.take(1).forEach(printer)

    // Composing by hand: Kotlin has no built-in compose, so `then` above
    // is the whole of it.
    val firstWord: (String) -> String = { it.substringBefore(" ") }
    val shout: (String) -> String = String::uppercase
    println((firstWord then shout)("Quill Wharf"))

    // A lambda with a receiver reads like a small DSL.
    val summary = buildString {
        append("lines: ")
        listOf("Amber", "Cobalt").forEach { append(it).append(' ') }
        appendLine()
        append("stations: ${stations.size}")
    }
    println(summary)
}
