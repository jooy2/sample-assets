// Extensions add members to a type you do not own. They are resolved
// statically, so they are dispatched on the declared type.

fun String.truncate(length: Int, ellipsis: String = "..."): String =
    if (this.length <= length) this else take(length - ellipsis.length) + ellipsis

fun String.toTitleCase(): String =
    split(" ").joinToString(" ") { word ->
        word.replaceFirstChar { it.uppercase() }
    }

val String.isBlankOrEmpty: Boolean get() = isBlank()

fun Int.isBetween(low: Int, high: Int): Boolean = this in low..high

// An extension on a generic receiver, constrained to numbers.
fun <T : Number> List<T>.mean(): Double =
    if (isEmpty()) 0.0 else sumOf { it.toDouble() } / size

// An extension on a nullable receiver: the body decides what null means.
fun String?.orPlaceholder(): String = this?.takeIf { it.isNotBlank() } ?: "(none)"

// An extension function that takes a receiver-scoped lambda, the shape most
// Kotlin builders use.
class Report(val title: String) {
    private val lines = mutableListOf<String>()

    fun line(text: String) {
        lines.add(text)
    }

    override fun toString(): String = (listOf("== $title ==") + lines).joinToString("\n")
}

fun report(title: String, build: Report.() -> Unit): Report = Report(title).apply(build)

fun main() {
    println("Stations on the Amber line".truncate(18))
    println("quill moor station".toTitleCase())
    println("blank: ${"   ".isBlankOrEmpty}")
    println("3 is between 1 and 5: ${3.isBetween(1, 5)}")
    println("mean: ${listOf(21.4, 19.8, 24.1, 22.7).mean()}")
    println("null receiver: ${null.orPlaceholder()} / ${"  ".orPlaceholder()}")

    println(
        report("Network") {
            line("Amber: 24 stations")
            line("Cobalt: 31 stations")
            line("Emerald: 18 stations")
        }
    )
}
