/**
 * FleetAnalytics.kt — reading a fleet's operating record and reporting on it.
 *
 * Data classes with destructuring and `copy`, sealed hierarchies, enum classes
 * with properties, collection operators (`groupBy`, `partition`, `fold`,
 * `zipWithNext`, `windowed`, `chunked`, `associateBy`, `flatMap`), lazy
 * sequences, scope functions (`let`, `run`, `apply`, `also`, `with`),
 * infix and operator functions, generic extension functions with receivers,
 * `Comparable` and `compareBy`, and null handling without a single `!!`.
 *
 * Requires Kotlin 1.9 or later.
 *
 *   kotlinc FleetAnalytics.kt -include-runtime -d fleet.jar && java -jar fleet.jar
 *   kotlin FleetAnalytics.kt
 *
 * Standard library only. Every vessel, sailing, and figure below is invented.
 */

import kotlin.math.abs
import kotlin.math.roundToInt
import kotlin.math.sqrt

// -------------------------------------------------------------- small types

/** Minutes since midnight, with arithmetic that wraps at the day boundary. */
@JvmInline
value class Clock(val raw: Int) : Comparable<Clock> {
    /** Always in 0..1439, however far out of range [raw] was. */
    val minutes: Int get() = ((raw % 1440) + 1440) % 1440
    val hour: Int get() = minutes / 60
    val minute: Int get() = minutes % 60

    operator fun plus(added: Int) = Clock(minutes + added)

    /** Forwards from [other] to this, through midnight if need be. */
    infix fun since(other: Clock): Int =
        (minutes - other.minutes).let { if (it >= 0) it else it + 1440 }

    override fun compareTo(other: Clock): Int = minutes.compareTo(other.minutes)

    override fun toString(): String =
        "%02d:%02d".format(hour, minute)

    companion object {
        fun of(text: String): Clock? = text.split(":")
            .takeIf { it.size == 2 }
            ?.let { (h, m) -> h.toIntOrNull()?.let { hh -> m.toIntOrNull()?.let { mm -> Clock(hh * 60 + mm) } } }
    }
}

enum class Weather(val label: String, val disruptive: Boolean) {
    Clear("clear", false),
    Cloudy("cloudy", false),
    Rain("rain", false),
    Fog("fog", true),
    Swell("swell", true),
    Gale("gale", true);

    companion object {
        /** Parse leniently: an unknown word is Clear rather than a crash. */
        fun from(text: String): Weather =
            Weather.entries.firstOrNull { it.label.equals(text, ignoreCase = true) } ?: Clear
    }
}

enum class Route(val code: String, val fullName: String, val crossingMinutes: Int) {
    HarbourLoop("HRB", "Harbour Loop", 19),
    KestrelPoint("KSP", "Kestrel Point", 26),
    Halloway("HLW", "Halloway", 34),
    NightCrossing("NCR", "Night Crossing", 42);

    companion object {
        private val byCode = Route.entries.associateBy(Route::code)
        fun of(code: String): Route? = byCode[code]
    }
}

data class Vessel(
    val name: String,
    val capacity: Int,
    val builtIn: Int,
    val carriesVehicles: Boolean,
) {
    val age: Int get() = 2027 - builtIn
}

/** What happened to one scheduled sailing. */
sealed interface Outcome {
    data class Sailed(val passengers: Int, val delayMinutes: Int) : Outcome
    data class Cancelled(val cause: Cause) : Outcome
    data object NotYetRun : Outcome
}

enum class Cause(val label: String, val ourFault: Boolean) {
    Weather("weather", false),
    Mechanical("mechanical", true),
    Crew("crew shortage", true),
    Berth("berth unavailable", false),
}

data class Sailing(
    val id: String,
    val route: Route,
    val vessel: Vessel,
    val departs: Clock,
    val weather: Weather,
    val outcome: Outcome,
) {
    val arrives: Clock get() = departs + route.crossingMinutes

    val sailed: Boolean get() = outcome is Outcome.Sailed

    val passengers: Int
        get() = (outcome as? Outcome.Sailed)?.passengers ?: 0

    val delay: Int
        get() = (outcome as? Outcome.Sailed)?.delayMinutes ?: 0

    /** Load as a percentage of capacity, or null when nothing sailed. */
    val load: Double?
        get() = (outcome as? Outcome.Sailed)
            ?.let { it.passengers * 100.0 / vessel.capacity }

    val timeOfDay: TimeOfDay get() = when (departs.hour) {
        in 0..5 -> TimeOfDay.Night
        in 6..9 -> TimeOfDay.MorningPeak
        in 10..15 -> TimeOfDay.Midday
        in 16..19 -> TimeOfDay.EveningPeak
        else -> TimeOfDay.Evening
    }
}

enum class TimeOfDay { Night, MorningPeak, Midday, EveningPeak, Evening }

// ------------------------------------------------------------ the statistics

/** A summary of any group of sailings. */
data class Summary(
    val scheduled: Int,
    val sailed: Int,
    val cancelled: Int,
    val passengers: Int,
    val seatsOffered: Int,
    val totalDelay: Int,
) {
    val reliability: Double get() = if (scheduled == 0) 0.0 else sailed * 100.0 / scheduled
    val load: Double get() = if (seatsOffered == 0) 0.0 else passengers * 100.0 / seatsOffered
    val meanDelay: Double get() = if (sailed == 0) 0.0 else totalDelay.toDouble() / sailed

    /** Summaries add, so a fold over groups needs nothing else. */
    operator fun plus(other: Summary) = Summary(
        scheduled = scheduled + other.scheduled,
        sailed = sailed + other.sailed,
        cancelled = cancelled + other.cancelled,
        passengers = passengers + other.passengers,
        seatsOffered = seatsOffered + other.seatsOffered,
        totalDelay = totalDelay + other.totalDelay,
    )

    companion object {
        val Empty = Summary(0, 0, 0, 0, 0, 0)

        fun of(sailing: Sailing) = Summary(
            scheduled = 1,
            sailed = if (sailing.sailed) 1 else 0,
            cancelled = if (sailing.outcome is Outcome.Cancelled) 1 else 0,
            passengers = sailing.passengers,
            seatsOffered = if (sailing.sailed) sailing.vessel.capacity else 0,
            totalDelay = sailing.delay,
        )
    }
}

/** Fold any collection of sailings into one summary. */
fun Iterable<Sailing>.summarise(): Summary =
    fold(Summary.Empty) { running, sailing -> running + Summary.of(sailing) }

/**
 * Group and summarise in one step. Generic over the key, so the same function
 * serves route, vessel, weather, and hour.
 */
fun <K> Iterable<Sailing>.summariseBy(key: (Sailing) -> K): Map<K, Summary> =
    groupBy(key).mapValues { (_, group) -> group.summarise() }

/** Mean, and the standard deviation about it, of any numeric projection. */
fun <T> Iterable<T>.spread(value: (T) -> Double): Pair<Double, Double> {
    val values = map(value)
    if (values.isEmpty()) return 0.0 to 0.0

    val mean = values.average()
    val variance = values.sumOf { (it - mean) * (it - mean) } / values.size
    return mean to sqrt(variance)
}

/** The value at a percentile, interpolating between neighbours. */
fun List<Double>.percentile(fraction: Double): Double {
    if (isEmpty()) return 0.0
    val sorted = sorted()
    val position = (sorted.size - 1) * fraction
    val lower = position.toInt()
    val upper = minOf(lower + 1, sorted.size - 1)
    return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - lower)
}

// ------------------------------------------------------------- presentation

fun Double.percent(places: Int = 1): String = "%.${places}f%%".format(this)

fun Double.rounded(places: Int = 1): String = "%.${places}f".format(this)

/** A bar of hashes, for a histogram in a terminal. */
infix fun Int.barOf(width: Int): String = "#".repeat(minOf(this, width))

/**
 * Print a table without any of the callers having to count characters. The
 * receiver lambda builds rows; the widths follow from what was added.
 */
class Table(private val headings: List<String>) {
    private val rows = mutableListOf<List<String>>()
    private val rightAligned = mutableSetOf<Int>()

    fun row(vararg cells: Any?) {
        rows += cells.map { it?.toString() ?: "" }
    }

    fun rightAlign(vararg columns: Int) = apply { rightAligned += columns.toList() }

    override fun toString(): String {
        val widths = headings.indices.map { column ->
            (rows.map { it.getOrElse(column) { "" } } + headings[column])
                .maxOf { it.length }
        }

        fun line(cells: List<String>) = cells
            .mapIndexed { index, cell ->
                if (index in rightAligned) cell.padStart(widths[index]) else cell.padEnd(widths[index])
            }
            .joinToString("  ")
            .trimEnd()

        return buildString {
            appendLine("  " + line(headings))
            appendLine("  " + widths.joinToString("  ") { "-".repeat(it) })
            rows.forEach { appendLine("  " + line(it)) }
        }.trimEnd()
    }
}

fun table(vararg headings: String, build: Table.() -> Unit): Table =
    Table(headings.toList()).apply(build)

fun heading(title: String) {
    println()
    println("--- $title ---")
}

// -------------------------------------------------------------- the fleet

val fleet = listOf(
    Vessel("MV Marlow", 380, 2014, carriesVehicles = true),
    Vessel("MV Kestrel", 240, 2019, carriesVehicles = true),
    Vessel("MV Halloway", 120, 2003, carriesVehicles = false),
    Vessel("MV Fenwick", 90, 2021, carriesVehicles = false),
).associateBy(Vessel::name)

/**
 * The day's record, as it might arrive from an operations system:
 * id, route, vessel, departure, weather, and what happened.
 */
val record = """
    HRB-01|HRB|MV Marlow|06:20|clear|sailed:284:0
    HRB-02|HRB|MV Marlow|06:40|clear|sailed:301:0
    HRB-03|HRB|MV Marlow|07:00|clear|sailed:346:2
    HRB-04|HRB|MV Marlow|07:20|cloudy|sailed:372:0
    HRB-05|HRB|MV Marlow|07:40|cloudy|sailed:358:4
    HRB-06|HRB|MV Marlow|08:00|rain|sailed:341:7
    HRB-07|HRB|MV Marlow|08:20|rain|sailed:299:3
    HRB-08|HRB|MV Marlow|10:00|rain|sailed:142:0
    HRB-09|HRB|MV Marlow|11:00|cloudy|sailed:118:0
    HRB-10|HRB|MV Marlow|12:00|clear|sailed:161:0
    HRB-11|HRB|MV Marlow|16:00|clear|sailed:312:0
    HRB-12|HRB|MV Marlow|16:40|clear|sailed:355:5
    HRB-13|HRB|MV Marlow|17:20|cloudy|sailed:368:9
    HRB-14|HRB|MV Marlow|18:00|cloudy|sailed:344:2
    HRB-15|HRB|MV Marlow|18:40|rain|cancelled:mechanical
    KSP-01|KSP|MV Kestrel|06:15|clear|sailed:211:0
    KSP-02|KSP|MV Kestrel|07:00|clear|sailed:198:0
    KSP-03|KSP|MV Kestrel|07:30|cloudy|sailed:224:3
    KSP-04|KSP|MV Kestrel|08:00|rain|sailed:231:6
    KSP-05|KSP|MV Kestrel|09:00|rain|sailed:154:0
    KSP-06|KSP|MV Kestrel|11:00|cloudy|sailed:88:0
    KSP-07|KSP|MV Kestrel|13:00|clear|sailed:96:0
    KSP-08|KSP|MV Kestrel|16:30|clear|sailed:206:0
    KSP-09|KSP|MV Kestrel|17:30|cloudy|sailed:229:4
    KSP-10|KSP|MV Kestrel|18:30|fog|cancelled:weather
    KSP-11|KSP|MV Kestrel|19:00|fog|cancelled:weather
    HLW-01|HLW|MV Halloway|08:05|clear|sailed:61:0
    HLW-02|HLW|MV Halloway|09:05|cloudy|sailed:44:0
    HLW-03|HLW|MV Halloway|10:05|rain|sailed:39:2
    HLW-04|HLW|MV Halloway|11:05|swell|cancelled:weather
    HLW-05|HLW|MV Halloway|12:05|swell|cancelled:weather
    HLW-06|HLW|MV Halloway|13:05|rain|sailed:52:0
    HLW-07|HLW|MV Halloway|14:05|cloudy|sailed:48:11
    HLW-08|HLW|MV Halloway|15:05|cloudy|sailed:57:0
    HLW-09|HLW|MV Halloway|16:05|clear|sailed:71:0
    HLW-10|HLW|MV Halloway|17:05|clear|cancelled:crew
    NCR-01|NCR|MV Fenwick|21:30|clear|sailed:41:0
    NCR-02|NCR|MV Fenwick|23:00|clear|sailed:56:0
    NCR-03|NCR|MV Fenwick|00:30|fog|cancelled:weather
""".trimIndent()

/** Parse one line, returning null rather than throwing on anything odd. */
fun parseSailing(line: String): Sailing? {
    val fields = line.split("|")
    if (fields.size != 6) return null

    // A List destructures only as far as component5(), so the six fields are
    // taken by index rather than by name-in-parentheses.
    val id = fields[0]
    val routeCode = fields[1]
    val vesselName = fields[2]
    val departsText = fields[3]
    val weatherText = fields[4]
    val outcomeText = fields[5]

    val route = Route.of(routeCode) ?: return null
    val vessel = fleet[vesselName] ?: return null
    val departs = Clock.of(departsText) ?: return null

    val outcome = outcomeText.split(":").let { parts ->
        when (parts.firstOrNull()) {
            "sailed" -> {
                val passengers = parts.getOrNull(1)?.toIntOrNull() ?: return null
                val delay = parts.getOrNull(2)?.toIntOrNull() ?: 0
                Outcome.Sailed(passengers, delay)
            }
            "cancelled" -> {
                val label = parts.getOrNull(1) ?: return null
                val cause = Cause.entries.firstOrNull { it.label.startsWith(label) } ?: return null
                Outcome.Cancelled(cause)
            }
            "pending" -> Outcome.NotYetRun
            else -> return null
        }
    }

    return Sailing(id, route, vessel, departs, Weather.from(weatherText), outcome)
}

// ---------------------------------------------------------------------- main

fun main() {
    val (sailings, rejected) = record.lineSequence()
        .map { it.trim() }
        .filter { it.isNotEmpty() }
        .map { line -> line to parseSailing(line) }
        .toList()
        .partition { (_, parsed) -> parsed != null }
        .let { (good, bad) ->
            good.mapNotNull { it.second } to bad.map { it.first }
        }

    heading("what was read")
    println("  ${sailings.size} sailing(s) parsed, ${rejected.size} line(s) rejected")
    println("  ${sailings.count { it.sailed }} sailed, " +
        "${sailings.count { it.outcome is Outcome.Cancelled }} cancelled")

    heading("by route")
    println(
        table("Route", "Sched", "Sailed", "Canc", "Passengers", "Load", "Reliability", "Delay") {
            rightAlign(1, 2, 3, 4, 5, 6, 7)
            sailings.summariseBy { it.route }
                .toList()
                .sortedByDescending { (_, summary) -> summary.passengers }
                .forEach { (route, summary) ->
                    row(
                        route.fullName,
                        summary.scheduled,
                        summary.sailed,
                        summary.cancelled,
                        summary.passengers,
                        summary.load.percent(),
                        summary.reliability.percent(),
                        summary.meanDelay.rounded() + "m",
                    )
                }
            sailings.summarise().let { total ->
                row(
                    "All routes", total.scheduled, total.sailed, total.cancelled,
                    total.passengers, total.load.percent(), total.reliability.percent(),
                    total.meanDelay.rounded() + "m",
                )
            }
        },
    )

    heading("by vessel")
    println(
        table("Vessel", "Built", "Age", "Seats", "Trips", "Carried", "Load") {
            rightAlign(1, 2, 3, 4, 5, 6)
            sailings.summariseBy { it.vessel }
                .toList()
                .sortedBy { (vessel, _) -> vessel.name }
                .forEach { (vessel, summary) ->
                    row(
                        vessel.name, vessel.builtIn, vessel.age, vessel.capacity,
                        summary.sailed, summary.passengers, summary.load.percent(),
                    )
                }
        },
    )

    heading("by time of day")
    val byPart = sailings.summariseBy { it.timeOfDay }
    val busiest = byPart.maxByOrNull { (_, summary) -> summary.passengers }
    TimeOfDay.entries.forEach { part ->
        val summary = byPart[part] ?: Summary.Empty
        val bar = (summary.passengers / 120) barOf 30
        println("  ${part.name.padEnd(13)} ${summary.passengers.toString().padStart(5)}  $bar")
    }
    busiest?.let { (part, summary) ->
        println("  busiest: ${part.name} with ${summary.passengers} passenger(s)")
    }

    heading("cancellations")
    val cancellations = sailings.mapNotNull { sailing ->
        (sailing.outcome as? Outcome.Cancelled)?.let { sailing to it.cause }
    }
    val (ours, theirs) = cancellations.partition { (_, cause) -> cause.ourFault }
    println(
        table("Sailing", "Route", "Departs", "Weather", "Cause", "Ours?") {
            cancellations.sortedBy { (sailing, _) -> sailing.departs }
                .forEach { (sailing, cause) ->
                    row(sailing.id, sailing.route.code, sailing.departs,
                        sailing.weather.label, cause.label, if (cause.ourFault) "yes" else "no")
                }
        },
    )
    println("  ${ours.size} within our control, ${theirs.size} not")

    heading("weather and reliability")
    println(
        table("Weather", "Disruptive", "Scheduled", "Sailed", "Reliability") {
            rightAlign(2, 3, 4)
            sailings.summariseBy { it.weather }
                .toList()
                .sortedBy { (weather, _) -> weather.ordinal }
                .forEach { (weather, summary) ->
                    row(weather.label, if (weather.disruptive) "yes" else "no",
                        summary.scheduled, summary.sailed, summary.reliability.percent())
                }
        },
    )

    heading("load, spread out")
    val loads = sailings.mapNotNull { it.load }
    val (mean, deviation) = loads.spread { it }
    println("  ${loads.size} sailing(s) with a load")
    println("  mean   ${mean.rounded()}%  (sd ${deviation.rounded()})")
    listOf(0.1 to "p10", 0.5 to "median", 0.9 to "p90").forEach { (fraction, label) ->
        println("  ${label.padEnd(7)}${loads.percentile(fraction).rounded()}%")
    }

    heading("the widest gaps in service on the Harbour Loop")
    sailings
        .filter { it.route == Route.HarbourLoop }
        .sortedBy { it.departs }
        .zipWithNext { earlier, later -> Triple(earlier, later, later.departs since earlier.departs) }
        .sortedByDescending { (_, _, gap) -> gap }
        .take(3)
        .forEach { (earlier, later, gap) ->
            println("  ${gap.toString().padStart(3)} minutes between ${earlier.departs} and ${later.departs}")
        }

    heading("a rolling three-sailing mean load")
    sailings
        .filter { it.route == Route.KestrelPoint && it.sailed }
        .sortedBy { it.departs }
        .windowed(size = 3, step = 1)
        .forEach { window ->
            val average = window.mapNotNull { it.load }.average()
            println("  ${window.first().departs} to ${window.last().departs}  ${average.rounded()}%")
        }

    heading("sailings in blocks of ten")
    sailings.sortedBy { it.departs }.chunked(10).forEachIndexed { index, block ->
        val summary = block.summarise()
        println("  block ${index + 1}: ${block.first().departs}-${block.last().departs}  " +
            "${summary.passengers} carried, ${summary.reliability.percent(0)} reliable")
    }

    heading("scope functions, one line each")
    val marlow = fleet.getValue("MV Marlow")
    marlow.let { println("  let    ${it.name} seats ${it.capacity}") }
    marlow.run { println("  run    $name is $age years old") }
    with(marlow) { println("  with   carries vehicles: $carriesVehicles") }
    marlow.copy(capacity = 400).also { println("  also   a copy with ${it.capacity} seats") }
    Summary.Empty.let { it + Summary.of(sailings.first()) }
        .apply { println("  apply  one sailing summarised: $passengers passenger(s)") }

    heading("destructuring")
    val (name, capacity, builtIn, vehicles) = marlow
    println("  $name, $capacity seats, built $builtIn, vehicles: $vehicles")
    sailings.first().let { (id, route, vessel) ->
        println("  $id on ${route.fullName} with ${vessel.name}")
    }

    heading("lazy sequences do less work")
    var examined = 0
    val firstBigLoad = sailings.asSequence()
        .onEach { examined += 1 }
        .filter { it.sailed }
        .mapNotNull { sailing -> sailing.load?.let { sailing to it } }
        .firstOrNull { (_, load) -> load > 95 }

    firstBigLoad?.let { (sailing, load) ->
        println("  ${sailing.id} at ${load.rounded()}% was found after examining $examined of ${sailings.size}")
    } ?: println("  none over 95%, after examining all $examined")

    heading("clock arithmetic")
    val late = Clock.of("23:00") ?: Clock(0)
    println("  23:00 plus 42 minutes is ${late + 42}")
    println("  from 23:00 to 00:30 is ${(Clock.of("00:30") ?: late) since late} minutes")
    println("  a bad time parses to null: ${Clock.of("25:70:99") == null}")
    println("  and so does nonsense:      ${Clock.of("half past") == null}")

    heading("nothing was rejected, but the parser is ready for it")
    listOf(
        "HRB-99|ZZZ|MV Marlow|06:20|clear|sailed:100:0",
        "HRB-98|HRB|MV Nowhere|06:20|clear|sailed:100:0",
        "HRB-97|HRB|MV Marlow|99:99|clear|sailed:100:0",
        "HRB-96|HRB|MV Marlow|06:20|clear|exploded",
        "not enough fields",
    ).forEach { line ->
        val why = when {
            line.split("|").size != 6 -> "wrong number of fields"
            Route.of(line.split("|")[1]) == null -> "unknown route"
            fleet[line.split("|")[2]] == null -> "unknown vessel"
            Clock.of(line.split("|")[3]) == null -> "unreadable time"
            else -> "unreadable outcome"
        }
        println("  ${parseSailing(line)?.id ?: "rejected"}: $why")
    }

    heading("the whole day in one line")
    sailings.summarise().run {
        println("  $scheduled scheduled, $sailed sailed, $passengers carried, " +
            "${load.percent()} full, ${reliability.percent()} reliable, " +
            "${abs(totalDelay)} minutes of delay across ${sailed} crossing(s)")
        println("  mean delay per crossing: ${meanDelay.roundToInt()} minute(s)")
    }
}
