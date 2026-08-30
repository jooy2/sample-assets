// Kotlin separates String from String? and will not let a nullable value be
// used until it has been checked.

data class Station(val name: String, val nickname: String?, val zone: Int)

private val network = mapOf(
    "alder" to Station("Alder Cross", "the Cross", 2),
    "quill" to Station("Quill Wharf", null, 3),
)

fun label(station: Station): String = station.nickname ?: station.name

fun zoneOf(handle: String): Int? = network[handle]?.zone

fun main() {
    for (handle in listOf("alder", "quill", "nether")) {
        val station = network[handle]

        if (station == null) {
            println("$handle is not on the network")
            continue
        }
        // Past the check, the compiler smart-casts to the non-null type.
        println("$handle -> ${label(station)} (zone ${station.zone})")
    }

    println("zone of quill: ${zoneOf("quill")}")
    println("zone of nether: ${zoneOf("nether") ?: -1}")

    // ?.let runs the block only when the value is there.
    network["alder"]?.nickname?.let { println("nickname in caps: ${it.uppercase()}") }
    network["quill"]?.nickname?.let { println("never printed: $it") }

    // The elvis operator also works as an early return.
    fun postcodeFor(handle: String): String {
        val station = network[handle] ?: return "unknown"
        return "zone-${station.zone}"
    }
    println(postcodeFor("quill") + " / " + postcodeFor("nether"))

    // Collections of nullable elements.
    val nicknames: List<String?> = network.values.map { it.nickname }
    println("all: $nicknames")
    println("without nulls: ${nicknames.filterNotNull()}")
    println("lengths: ${nicknames.map { it?.length ?: 0 }}")

    // !! turns a null into an exception at a point you choose.
    runCatching { network["nether"]!!.name }
        .onFailure { println("!! threw ${it::class.simpleName}") }

    // lateinit defers initialisation without giving up non-nullability.
    println(Loader().apply { load() }.value)
}

private class Loader {
    lateinit var value: String

    fun load() {
        value = "built on first use"
    }
}
