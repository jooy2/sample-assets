// Coroutines from kotlinx.coroutines: suspending work, running it
// concurrently, and cancelling it.
//
// Needs the kotlinx-coroutines-core library on the classpath.

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.system.measureTimeMillis

suspend fun fetchStation(id: String, takes: Long): String {
    delay(takes) // suspends the coroutine, does not block the thread
    return "station $id"
}

fun main() = runBlocking {
    // Sequential: the second call starts only once the first has returned.
    val sequential = measureTimeMillis {
        fetchStation("ST-001", 120)
        fetchStation("ST-002", 120)
    }
    println("sequential took ~$sequential ms")

    // Concurrent: async starts the work, await collects it.
    val concurrent = measureTimeMillis {
        val first = async { fetchStation("ST-003", 120) }
        val second = async { fetchStation("ST-004", 120) }
        println("${first.await()}, ${second.await()}")
    }
    println("concurrent took ~$concurrent ms")

    // awaitAll over a list of deferred results.
    val ids = listOf("ST-005", "ST-006", "ST-007")
    val all = ids.map { async { fetchStation(it, 80) } }.awaitAll()
    println(all)

    // launch fires work off without a result; the scope waits for it.
    coroutineScope {
        repeat(3) { index ->
            launch {
                delay((3 - index) * 30L)
                println("  worker $index finished")
            }
        }
    }
    println("all workers done")

    // A timeout cancels the coroutine and returns null instead.
    val slow = withTimeoutOrNull(50) { fetchStation("ST-008", 300) }
    println("timed out: ${slow == null}")

    // Cancellation is cooperative: the suspending call notices it.
    val job = launch {
        try {
            repeat(100) {
                delay(20)
            }
        } catch (cancelled: CancellationException) {
            println("cancelled after being asked to stop")
            throw cancelled
        }
    }
    delay(60)
    job.cancelAndJoin()
}
