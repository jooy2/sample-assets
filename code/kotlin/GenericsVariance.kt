// Type parameters, upper bounds, and the `out`/`in` variance annotations
// that decide where a generic type can be substituted.

// `out T` means T only ever comes out: Producer<Circle> is a Producer<Shape>.
interface Producer<out T> {
    fun produce(): T
}

// `in T` means T only ever goes in: Consumer<Shape> is a Consumer<Circle>.
interface Consumer<in T> {
    fun consume(value: T)
}

open class Shape(val name: String)
class Circle : Shape("circle")

class ShapeBox<T : Shape>(private val items: MutableList<T> = mutableListOf()) {
    fun add(item: T) = items.add(item)
    fun first(): T = items.first()
    fun names(): List<String> = items.map { it.name }
}

// A generic function with an upper bound.
fun <T : Comparable<T>> largest(values: List<T>): T = values.reduce { a, b -> if (a > b) a else b }

// Use-site variance: this only reads from the list, so it accepts any subtype.
fun totalArea(shapes: List<out Shape>): Int = shapes.size

// reified keeps the type at runtime, which erasure normally removes.
inline fun <reified T> List<Any>.ofType(): List<T> = filterIsInstance<T>()

fun main() {
    val circleProducer = object : Producer<Circle> {
        override fun produce() = Circle()
    }
    val shapeProducer: Producer<Shape> = circleProducer // allowed by `out`
    println("produced a ${shapeProducer.produce().name}")

    val shapeConsumer = object : Consumer<Shape> {
        override fun consume(value: Shape) = println("consumed a ${value.name}")
    }
    val circleConsumer: Consumer<Circle> = shapeConsumer // allowed by `in`
    circleConsumer.consume(Circle())

    val box = ShapeBox<Circle>()
    box.add(Circle())
    box.add(Circle())
    println("box holds ${box.names()}")

    println("largest int: ${largest(listOf(23, 5, 91, 42))}")
    println("largest string: ${largest(listOf("amber", "cobalt", "emerald"))}")
    println("counted ${totalArea(listOf(Circle(), Shape("square")))} shapes")

    val mixed: List<Any> = listOf(1, "amber", Circle(), 2.5, "cobalt")
    println("strings only: ${mixed.ofType<String>()}")
    println("circles only: ${mixed.ofType<Circle>().map { it.name }}")
}
