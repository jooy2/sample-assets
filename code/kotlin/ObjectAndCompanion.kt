// `object` declares a singleton; `companion object` gives a class the
// static-like members Kotlin otherwise has no keyword for.

// A singleton: created on first use, and there is only ever one.
object NetworkRegistry {
    private val stations = mutableMapOf<String, Int>()

    val size: Int get() = stations.size

    fun register(name: String, zone: Int) {
        stations[name] = zone
    }

    fun zoneOf(name: String): Int? = stations[name]
}

class Station private constructor(val id: String, val name: String, val zone: Int) {

    companion object Factory {
        private var created = 0

        const val MAX_ZONE = 6 // a compile-time constant

        /** A named constructor, which a private constructor makes the only way in. */
        fun of(name: String, zone: Int): Station {
            require(zone in 1..MAX_ZONE) { "zone $zone is outside 1-$MAX_ZONE" }
            created++
            return Station("ST-%03d".format(created), name, zone)
        }

        fun createdSoFar() = created
    }

    override fun toString() = "$id $name (zone $zone)"
}

// An anonymous object implements an interface on the spot.
interface Listener {
    fun onEvent(name: String)
}

fun main() {
    NetworkRegistry.register("Alder Cross", 2)
    NetworkRegistry.register("Quill Wharf", 3)
    println("registry holds ${NetworkRegistry.size}, Quill Wharf is in zone ${NetworkRegistry.zoneOf("Quill Wharf")}")

    val alder = Station.of("Alder Cross", 2)
    val quill = Station.of("Quill Wharf", 3)
    println(alder)
    println(quill)
    println("created ${Station.createdSoFar()}, the limit is zone ${Station.MAX_ZONE}")

    runCatching { Station.of("Far Halt", 9) }
        .onFailure { println("rejected: ${it.message}") }

    val listener = object : Listener {
        var seen = 0

        override fun onEvent(name: String) {
            seen++
            println("  saw $name (event $seen)")
        }
    }
    listener.onEvent("door opened")
    listener.onEvent("door closed")

    // The companion is itself an object, so it can be passed around.
    val factory = Station.Factory
    println(factory.of("Saltwick Halt", 5))
}
