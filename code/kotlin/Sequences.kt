// A List runs each operation over the whole collection; a Sequence runs the
// whole chain over each element, lazily.

fun main() {
    val numbers = (1..10).toList()

    println("eager:")
    numbers
        .map { println("  map $it"); it * 2 }
        .filter { it > 10 }
        .take(2)
        .also { println("  result $it") }

    println("lazy:")
    numbers.asSequence()
        .map { println("  map $it"); it * 2 }
        .filter { it > 10 }
        .take(2)
        .toList()
        .also { println("  result $it") }

    // An infinite sequence is only possible lazily.
    val fibonacci = generateSequence(0L to 1L) { (a, b) -> b to (a + b) }.map { it.first }
    println("fibonacci: ${fibonacci.take(12).toList()}")

    println("first over a thousand: ${fibonacci.first { it > 1_000 }}")

    // generateSequence stops when the block returns null.
    val countdown = generateSequence(5) { if (it > 1) it - 1 else null }
    println("countdown: ${countdown.toList()}")

    // sequence { } yields values one at a time, including from a loop.
    val primes = sequence {
        var candidate = 2
        while (true) {
            if ((2 until candidate).none { candidate % it == 0 }) {
                yield(candidate)
            }
            candidate++
        }
    }
    println("primes: ${primes.take(10).toList()}")

    // yieldAll delegates to another sequence or collection.
    val lines = sequence {
        yield("Amber")
        yieldAll(listOf("Cobalt", "Emerald"))
    }
    println("lines: ${lines.toList()}")

    // Sequences are single-use unless built from a source that can restart.
    val once = listOf("a", "b").asSequence()
    println(once.toList())
    println("still readable from a list-backed sequence: ${once.toList()}")

    val stations = listOf("Alder Cross", "Quill Wharf", "Saltwick Halt", "Nether Gate")
    val summary = stations.asSequence()
        .filter { it.length > 11 }
        .map { it.substringBefore(" ") }
        .sorted()
        .joinToString()
    println("summary: $summary")
}
