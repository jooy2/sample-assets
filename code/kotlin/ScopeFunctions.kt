// let, run, with, apply, and also differ in two ways only: what `it`/`this`
// refers to, and what the block returns.

data class Station(var name: String = "", var line: String = "", var zone: Int = 0) {
    fun validate() = require(name.isNotBlank()) { "a station needs a name" }
}

fun main() {
    // apply: receiver is `this`, returns the receiver. For configuring.
    val station = Station().apply {
        name = "Alder Cross"
        line = "Amber"
        zone = 2
    }
    println(station)

    // also: receiver is `it`, returns the receiver. For side effects.
    val checked = station
        .also { println("  checking ${it.name}") }
        .also { it.validate() }
    println("still the same object: ${checked === station}")

    // let: receiver is `it`, returns the block's result. For transforming,
    // and for running code only when a value is not null.
    val label: String = station.let { "${it.name} (zone ${it.zone})" }
    println(label)

    val nickname: String? = null
    println(nickname?.let { "nickname: $it" } ?: "no nickname")

    // run: receiver is `this`, returns the block's result. let + apply.
    val fare = station.run {
        val base = 2.40
        base + zone * 0.85
    }
    println("fare %.2f".format(fare))

    // with: the same as run, but takes the receiver as an argument.
    val summary = with(station) {
        "$name is on the $line line in zone $zone"
    }
    println(summary)

    // run without a receiver simply scopes a block of statements.
    val platforms = run {
        val base = 2
        val interchange = true
        if (interchange) base + 2 else base
    }
    println("platforms: $platforms")

    // takeIf and takeUnless turn a condition into a nullable value.
    println(station.takeIf { it.zone <= 3 }?.name ?: "outside the inner zones")
    println(station.takeUnless { it.stepFreeGuess() }?.name ?: "assumed step free")

    // Chained together, they replace a pile of temporary variables.
    val report = Station()
        .apply { name = "Quill Wharf"; line = "Cobalt"; zone = 3 }
        .also { it.validate() }
        .let { "${it.line}: ${it.name}" }
        .uppercase()
    println(report)
}

private fun Station.stepFreeGuess(): Boolean = zone <= 2
