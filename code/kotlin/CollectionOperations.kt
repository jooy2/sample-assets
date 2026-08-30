// The standard library's collection operations, which cover most of what a
// loop would do by hand.

data class Station(
    val name: String,
    val line: String,
    val zone: Int,
    val platforms: Int,
    val stepFree: Boolean,
)

fun main() {
    val stations = listOf(
        Station("Alder Cross", "Amber", 2, 2, true),
        Station("Quill Wharf", "Cobalt", 3, 4, false),
        Station("Saltwick Halt", "Amber", 5, 1, true),
        Station("Nether Gate", "Emerald", 2, 3, true),
        Station("Bramble Fields", "Cobalt", 4, 2, false),
    )

    println(stations.filter { it.stepFree && it.zone <= 3 }.map { it.name }.sorted())
    println("platforms: ${stations.sumOf { it.platforms }}")
    println("average zone: %.2f".format(stations.map { it.zone }.average()))

    println("by line: " + stations.groupBy { it.line }.mapValues { (_, group) -> group.size })
    println("names by line: " + stations.groupBy({ it.line }, { it.name }))
    println("indexed: " + stations.associateBy({ it.name }, { it.zone }))

    val (accessible, rest) = stations.partition { it.stepFree }
    println("step free ${accessible.size}, other ${rest.size}")

    println("deepest: ${stations.maxByOrNull { it.zone }?.name}")
    println("shallowest two: ${stations.sortedBy { it.zone }.take(2).map { it.name }}")
    println("sorted by two keys: " + stations
        .sortedWith(compareBy({ it.zone }, { it.name }))
        .joinToString { "${it.name}(${it.zone})" })

    println("any in zone 5: ${stations.any { it.zone == 5 }}")
    println("all have platforms: ${stations.all { it.platforms > 0 }}")
    println("none on Violet: ${stations.none { it.line == "Violet" }}")
    println("count on Amber: ${stations.count { it.line == "Amber" }}")

    println("flat words: " + stations.flatMap { it.name.split(" ") }.distinct())
    println("chunked: " + (1..10).chunked(4))
    println("windowed: " + (1..6).windowed(3))
    println("zipped: " + listOf("a", "b", "c").zip(listOf(1, 2, 3)))

    println("running total: " + stations.runningFold(0) { sum, s -> sum + s.platforms })
    println("fold to a string: " + stations.fold("") { acc, s -> "$acc${s.name.first()}" })

    // Mutable collections are a separate type from read-only ones.
    val queue = mutableListOf("Alder Cross")
    queue += "Quill Wharf"
    queue.removeAt(0)
    println("queue: $queue, read-only view: ${queue.toList()}")
}
