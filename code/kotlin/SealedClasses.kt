// A sealed hierarchy has a fixed set of subtypes, so `when` over it needs
// no else branch and is checked for completeness.

import kotlin.math.PI

sealed interface Shape {
    val area: Double
}

data class Circle(val radius: Double) : Shape {
    override val area get() = PI * radius * radius
}

data class Rectangle(val width: Double, val height: Double) : Shape {
    override val area get() = width * height
}

data class Triangle(val base: Double, val height: Double) : Shape {
    override val area get() = base * height / 2
}

// A sealed class with a type parameter, the usual Result shape.
sealed class Outcome<out T> {
    data class Ok<T>(val value: T) : Outcome<T>()
    data class Err(val message: String) : Outcome<Nothing>()
}

fun describe(shape: Shape): String = when (shape) {
    is Rectangle -> if (shape.width == shape.height) "a square" else "a rectangle"
    is Circle -> if (shape.radius > 10) "a large circle" else "a circle"
    is Triangle -> "a triangle"
}

fun parseZone(raw: String): Outcome<Int> {
    val zone = raw.toIntOrNull() ?: return Outcome.Err("\"$raw\" is not a number")
    return if (zone in 1..6) Outcome.Ok(zone) else Outcome.Err("zone $zone is outside 1-6")
}

fun main() {
    val shapes = listOf(Circle(2.0), Rectangle(4.0, 4.0), Triangle(6.0, 2.5), Circle(12.0))

    for (shape in shapes) {
        println("%-16s area %7.2f".format(describe(shape), shape.area))
    }
    println("total %.2f".format(shapes.sumOf { it.area }))

    for (raw in listOf("3", "9", "east")) {
        val message = when (val outcome = parseZone(raw)) {
            is Outcome.Ok -> "zone ${outcome.value}"
            is Outcome.Err -> "rejected: ${outcome.message}"
        }
        println("${raw.padEnd(6)} $message")
    }
}
