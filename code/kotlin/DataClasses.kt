// Data classes generate equals, hashCode, toString, copy, and componentN
// from the properties in the primary constructor.

data class Address(val city: String, val country: String, val postalCode: String)

data class User(
    val id: Int,
    val firstName: String,
    val lastName: String,
    val address: Address,
    val newsletter: Boolean = false,
) {
    // Only constructor properties take part in equals and toString.
    val fullName: String get() = "$firstName $lastName"

    init {
        require(id > 0) { "id must be positive" }
    }
}

fun main() {
    val original = User(1, "Imogen", "Hawthorne", Address("Harrowgate", "Kestrand", "KE-8256"))

    println(original)
    println(original.fullName)

    // copy() changes only what it names.
    val moved = original.copy(address = original.address.copy(city = "Stonebay"))
    println(moved.address)

    val same = User(1, "Imogen", "Hawthorne", Address("Harrowgate", "Kestrand", "KE-8256"))
    println("structural equality: ${original == same}")
    println("referential equality: ${original === same}")
    println("same hash: ${original.hashCode() == same.hashCode()}")

    // Destructuring uses the generated component functions.
    val (city, country, postal) = original.address
    println("$city, $country $postal")

    // Data classes work well as map keys and in sets.
    val seen = setOf(original, same, moved)
    println("distinct users: ${seen.size}")

    val byAddress = mapOf(original.address to original.fullName)
    println(byAddress[Address("Harrowgate", "Kestrand", "KE-8256")])

    runCatching { User(0, "Bad", "Id", original.address) }
        .onFailure { println("rejected: ${it.message}") }
}
