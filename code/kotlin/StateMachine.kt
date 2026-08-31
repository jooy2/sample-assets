/**
 * StateMachine.kt — a type-safe finite state machine and a DSL to declare one.
 *
 * Sealed interfaces for states and events, a builder DSL with a receiver
 * lambda, generics with reified type parameters, `Result` for fallible
 * transitions, delegated properties, extension functions, sequences, value
 * classes, and exhaustive `when` over a closed hierarchy.
 *
 * Requires Kotlin 1.9 or later (data objects).
 *
 *   kotlinc StateMachine.kt -include-runtime -d machine.jar && java -jar machine.jar
 *   kotlin StateMachine.kt
 *
 * The machine below tracks a ferry booking. Every state, event, and figure is
 * invented. Standard library only.
 */

import kotlin.properties.Delegates
import kotlin.reflect.KClass

// -------------------------------------------------------------- value types

/** A booking reference. A value class, so it costs nothing at runtime but
 *  cannot be swapped with any other String by accident. */
@JvmInline
value class Reference(val value: String) {
    init {
        require(value.matches(Regex("^BK-\\d{4,}$"))) {
            "a booking reference looks like BK-1001, not \"$value\""
        }
    }

    override fun toString(): String = value
}

@JvmInline
value class Pence(val amount: Long) : Comparable<Pence> {
    operator fun plus(other: Pence) = Pence(amount + other.amount)
    operator fun minus(other: Pence) = Pence(amount - other.amount)
    operator fun times(factor: Int) = Pence(amount * factor)

    override fun compareTo(other: Pence): Int = amount.compareTo(other.amount)

    override fun toString(): String {
        val sign = if (amount < 0) "-" else ""
        val absolute = kotlin.math.abs(amount)
        return "$sign£${absolute / 100}.${(absolute % 100).toString().padStart(2, '0')}"
    }

    companion object {
        val Zero = Pence(0)
        fun pounds(value: Double) = Pence(Math.round(value * 100))
    }
}

// ------------------------------------------------------------------- states

/**
 * Every state a booking can be in. A sealed interface, so `when` over it is
 * exhaustive and adding a state breaks compilation everywhere it matters —
 * which is the point of using one.
 */
sealed interface BookingState {
    val label: String get() = this::class.simpleName ?: "?"

    /** A state nothing leaves. */
    val isTerminal: Boolean get() = false

    data object Draft : BookingState

    data class Held(val seats: Int, val until: String) : BookingState

    data class Confirmed(val seats: Int, val paid: Pence) : BookingState

    data class PartlyPaid(val seats: Int, val paid: Pence, val owed: Pence) : BookingState

    data class Cancelled(val reason: String, val refund: Pence) : BookingState {
        override val isTerminal: Boolean get() = true
    }

    data class Travelled(val seats: Int) : BookingState {
        override val isTerminal: Boolean get() = true
    }

    data class Expired(val heldFor: String) : BookingState {
        override val isTerminal: Boolean get() = true
    }
}

// ------------------------------------------------------------------- events

sealed interface BookingEvent {
    val name: String get() = this::class.simpleName ?: "?"

    data class Hold(val seats: Int, val until: String) : BookingEvent
    data class Pay(val amount: Pence) : BookingEvent
    data class Refund(val amount: Pence, val reason: String) : BookingEvent
    data class Cancel(val reason: String) : BookingEvent
    data object Board : BookingEvent
    data object Expire : BookingEvent
    data class Amend(val seats: Int) : BookingEvent
}

// ------------------------------------------------------------------ results

/** Why a transition was refused. */
sealed interface Refusal {
    val message: String

    // Typed as Any rather than BookingState: the machine below is generic,
    // and a refusal that named one domain's states would not be.
    data class NoRule(val state: Any, val event: Any) : Refusal {
        override val message: String
            get() = "${state.summary()} has no rule for ${event.title()}"
    }

    data class GuardFailed(val reason: String) : Refusal {
        override val message: String get() = reason
    }

    data class Terminal(val state: Any) : Refusal {
        override val message: String get() = "${state.summary()} is final"
    }
}

class TransitionRefused(val refusal: Refusal) : IllegalStateException(refusal.message)

/** What one transition produced. */
data class Transition<S : Any, E : Any>(
    val from: S,
    val event: E,
    val to: S,
    val effects: List<String>,
)

// ---------------------------------------------------------------- the DSL

/**
 * A rule: which state and event it applies to, an optional guard, and what it
 * produces.
 */
class Rule<S : Any, E : Any> internal constructor(
    internal val fromType: KClass<out S>,
    internal val eventType: KClass<out E>,
    internal val guard: (S, E) -> String?,
    internal val target: (S, E) -> S,
    internal val effects: List<(S, E) -> String>,
)

/** The builder for a single rule, used as the receiver of a lambda. */
class RuleBuilder<S : Any, E : Any, FS : S, FE : E> @PublishedApi internal constructor(
    private val fromType: KClass<FS>,
    private val eventType: KClass<FE>,
) {
    private var guard: (FS, FE) -> String? = { _, _ -> null }
    private var target: ((FS, FE) -> S)? = null
    private val effects = mutableListOf<(FS, FE) -> String>()

    /** Refuse the transition, with a reason, when the predicate fails. */
    fun require(reason: String, predicate: (FS, FE) -> Boolean) {
        val previous = guard
        guard = { state, event ->
            previous(state, event) ?: if (predicate(state, event)) null else reason
        }
    }

    /** Where the machine goes. */
    fun goTo(next: (FS, FE) -> S) {
        target = next
    }

    /** Something to do on the way, recorded rather than performed. */
    fun onTransition(effect: (FS, FE) -> String) {
        effects += effect
    }

    @Suppress("UNCHECKED_CAST")
    @PublishedApi
    internal fun build(): Rule<S, E> {
        // Read into locals first: inside the lambdas below, a bare `guard`
        // would still resolve to the property, but it reads like recursion.
        val accumulatedGuard = guard
        val produce = target ?: error("a rule for ${fromType.simpleName} has no goTo")
        val recorded = effects.toList()

        return Rule(
            fromType = fromType,
            eventType = eventType,
            guard = { state, event -> accumulatedGuard(state as FS, event as FE) },
            target = { state, event -> produce(state as FS, event as FE) },
            effects = recorded.map { effect ->
                { state: S, event: E -> effect(state as FS, event as FE) }
            },
        )
    }
}

/** The builder for the whole machine. */
class MachineBuilder<S : Any, E : Any> internal constructor() {
    private val rules = mutableListOf<Rule<S, E>>()
    private val listeners = mutableListOf<(Transition<S, E>) -> Unit>()
    private var terminal: (S) -> Boolean = { false }

    /**
     * Declare a rule. The reified type parameters are what let the body see
     * the concrete state and event types rather than the sealed supertypes.
     */
    inline fun <reified FS : S, reified FE : E> on(
        noinline body: RuleBuilder<S, E, FS, FE>.() -> Unit,
    ) {
        addRule(RuleBuilder<S, E, FS, FE>(FS::class, FE::class).apply(body).build())
    }

    @PublishedApi
    internal fun addRule(rule: Rule<S, E>) {
        rules += rule
    }

    fun onEach(listener: (Transition<S, E>) -> Unit) {
        listeners += listener
    }

    /** Which states the machine will not leave. */
    fun terminalWhen(predicate: (S) -> Boolean) {
        terminal = predicate
    }

    internal fun build(initial: S): StateMachine<S, E> =
        StateMachine(initial, rules.toList(), listeners.toList(), terminal)
}

/** Entry point for the DSL. */
fun <S : Any, E : Any> stateMachine(
    initial: S,
    build: MachineBuilder<S, E>.() -> Unit,
): StateMachine<S, E> = MachineBuilder<S, E>().apply(build).build(initial)

// --------------------------------------------------------------- the machine

class StateMachine<S : Any, E : Any> internal constructor(
    initial: S,
    private val rules: List<Rule<S, E>>,
    private val listeners: List<(Transition<S, E>) -> Unit>,
    private val terminal: (S) -> Boolean,
) {
    var changes: Int = 0
        private set

    /**
     * A delegated property: every write is announced, which is how the change
     * count stays in step with the state without a setter written by hand.
     * It is private, with a read-only view beside it, so nothing outside can
     * move the machine except through fire().
     */
    private var currentState: S by Delegates.observable(initial) { _, old, new ->
        if (old != new) changes += 1
    }

    val state: S get() = currentState

    private val log = mutableListOf<Transition<S, E>>()

    val history: List<Transition<S, E>> get() = log.toList()

    /** Try an event. Never throws; a refusal is a value. */
    fun fire(event: E): Result<Transition<S, E>> {
        val current = currentState

        if (terminal(current)) {
            return Result.failure(TransitionRefused(Refusal.Terminal(current)))
        }

        val rule = rules.firstOrNull { candidate ->
            candidate.fromType.isInstance(current) && candidate.eventType.isInstance(event)
        } ?: return Result.failure(TransitionRefused(Refusal.NoRule(current, event)))

        rule.guard(current, event)?.let { reason ->
            return Result.failure(TransitionRefused(Refusal.GuardFailed(reason)))
        }

        val next = rule.target(current, event)
        val effects = rule.effects.map { it(current, event) }
        val transition = Transition(current, event, next, effects)

        currentState = next
        log += transition
        listeners.forEach { it(transition) }

        return Result.success(transition)
    }

    /** Apply several events, stopping at the first refusal. */
    fun fireAll(vararg events: E): Result<List<Transition<S, E>>> {
        val applied = mutableListOf<Transition<S, E>>()
        for (event in events) {
            val result = fire(event)
            result.fold(
                onSuccess = { applied += it },
                onFailure = { return Result.failure(it) },
            )
        }
        return Result.success(applied)
    }

    /** Which events would be accepted from here, given a set to try. */
    fun accepts(candidates: List<E>): List<E> = candidates.filter { event ->
        val current = currentState
        if (terminal(current)) {
            false
        } else {
            rules.any { rule ->
                rule.fromType.isInstance(current) &&
                    rule.eventType.isInstance(event) &&
                    rule.guard(current, event) == null
            }
        }
    }
}

// ------------------------------------------------------- extension functions

/** Print a Result the same way whichever branch it took. */
fun <S : Any, E : Any> Result<Transition<S, E>>.describe(): String = fold(
    onSuccess = { transition ->
        val effects = if (transition.effects.isEmpty()) {
            ""
        } else {
            "  [${transition.effects.joinToString("; ")}]"
        }
        "${transition.from.summary()} --${transition.event.title()}--> " +
            "${transition.to.summary()}$effects"
    },
    onFailure = { error -> "refused: ${error.message}" },
)

fun Any.summary(): String = when (this) {
    is BookingState.Draft -> "Draft"
    is BookingState.Held -> "Held(${seats} until ${until})"
    is BookingState.Confirmed -> "Confirmed(${seats}, paid $paid)"
    is BookingState.PartlyPaid -> "PartlyPaid(${seats}, paid $paid, owes $owed)"
    is BookingState.Cancelled -> "Cancelled($reason, refund $refund)"
    is BookingState.Travelled -> "Travelled($seats)"
    is BookingState.Expired -> "Expired(after $heldFor)"
    else -> toString()
}

fun Any.title(): String = when (this) {
    is BookingEvent -> name
    else -> toString()
}

/** Every state a sequence of events walks through, lazily. */
fun <S : Any, E : Any> StateMachine<S, E>.walk(events: List<E>): Sequence<String> =
    events.asSequence().map { event -> fire(event).describe() }

// --------------------------------------------------------------- the machine

const val SEAT_PRICE_MINOR = 1250L

fun bookingMachine(
    seatPrice: Pence = Pence(SEAT_PRICE_MINOR),
    audit: MutableList<String>? = null,
) = stateMachine<BookingState, BookingEvent>(BookingState.Draft) {

        terminalWhen { state -> state.isTerminal }

        on<BookingState.Draft, BookingEvent.Hold> {
            require("a hold needs at least one seat") { _, event -> event.seats >= 1 }
            require("no more than eight seats may be held at once") { _, event -> event.seats <= 8 }
            goTo { _, event -> BookingState.Held(event.seats, event.until) }
            onTransition { _, event -> "held ${event.seats} seat(s) until ${event.until}" }
        }

        on<BookingState.Held, BookingEvent.Pay> {
            require("a payment must be positive") { _, event -> event.amount > Pence.Zero }
            goTo { state, event ->
                val owed = seatPrice * state.seats - event.amount
                if (owed <= Pence.Zero) {
                    BookingState.Confirmed(state.seats, event.amount)
                } else {
                    BookingState.PartlyPaid(state.seats, event.amount, owed)
                }
            }
            onTransition { state, event ->
                val due = seatPrice * state.seats
                "took ${event.amount} of $due"
            }
        }

        on<BookingState.PartlyPaid, BookingEvent.Pay> {
            require("a payment must be positive") { _, event -> event.amount > Pence.Zero }
            require("that is more than is owed") { state, event -> event.amount <= state.owed }
            goTo { state, event ->
                val owed = state.owed - event.amount
                if (owed <= Pence.Zero) {
                    BookingState.Confirmed(state.seats, state.paid + event.amount)
                } else {
                    BookingState.PartlyPaid(state.seats, state.paid + event.amount, owed)
                }
            }
            onTransition { _, event -> "took a further ${event.amount}" }
        }

        on<BookingState.Held, BookingEvent.Amend> {
            require("an amendment needs at least one seat") { _, event -> event.seats >= 1 }
            goTo { state, event -> BookingState.Held(event.seats, state.until) }
            onTransition { state, event -> "changed from ${state.seats} to ${event.seats} seat(s)" }
        }

        on<BookingState.Held, BookingEvent.Expire> {
            goTo { state, _ -> BookingState.Expired(state.until) }
            onTransition { state, _ -> "the hold on ${state.seats} seat(s) lapsed" }
        }

        on<BookingState.Held, BookingEvent.Cancel> {
            goTo { _, event -> BookingState.Cancelled(event.reason, Pence.Zero) }
            onTransition { _, _ -> "nothing had been paid, so nothing is refunded" }
        }

        on<BookingState.PartlyPaid, BookingEvent.Cancel> {
            goTo { state, event -> BookingState.Cancelled(event.reason, state.paid) }
            onTransition { state, _ -> "refunding ${state.paid}" }
        }

        on<BookingState.Confirmed, BookingEvent.Cancel> {
            goTo { state, event -> BookingState.Cancelled(event.reason, state.paid) }
            onTransition { state, _ -> "refunding ${state.paid} in full" }
        }

        on<BookingState.Confirmed, BookingEvent.Refund> {
            require("a refund cannot exceed what was paid") { state, event ->
                event.amount <= state.paid
            }
            goTo { state, event ->
                val remaining = state.paid - event.amount
                if (remaining <= Pence.Zero) {
                    BookingState.Cancelled(event.reason, state.paid)
                } else {
                    BookingState.PartlyPaid(state.seats, remaining, event.amount)
                }
            }
            onTransition { _, event -> "refunded ${event.amount}: ${event.reason}" }
        }

        on<BookingState.Confirmed, BookingEvent.Board> {
            goTo { state, _ -> BookingState.Travelled(state.seats) }
            onTransition { state, _ -> "${state.seats} passenger(s) boarded" }
        }

        // A listener runs on every accepted transition. In a real system this
        // is where an event would be published; here it fills an audit trail
        // the caller supplied.
        onEach { transition ->
            audit?.add("${transition.event.title()}: ${transition.from.label} -> ${transition.to.label}")
        }
    }

// ---------------------------------------------------------------------- demo

fun heading(title: String) {
    println()
    println("--- $title ---")
}

fun main() {
    val reference = Reference("BK-1001")
    val seatPrice = Pence.pounds(12.50)

    heading("a booking that completes")
    val happy = bookingMachine(seatPrice)
    listOf<BookingEvent>(
        BookingEvent.Hold(seats = 3, until = "18:00"),
        BookingEvent.Pay(Pence.pounds(37.50)),
        BookingEvent.Board,
    ).forEach { println("  " + happy.fire(it).describe()) }
    println("  $reference finished in ${happy.state.summary()} after ${happy.changes} change(s)")

    heading("paying in instalments")
    val instalments = bookingMachine(seatPrice)
    instalments.walk(
        listOf(
            BookingEvent.Hold(4, "18:00"),
            BookingEvent.Pay(Pence.pounds(20.00)),
            BookingEvent.Pay(Pence.pounds(20.00)),
            BookingEvent.Pay(Pence.pounds(10.00)),
            BookingEvent.Board,
        ),
    ).forEach { println("  $it") }

    heading("guards")
    val guarded = bookingMachine(seatPrice)
    listOf<BookingEvent>(
        BookingEvent.Hold(0, "18:00"),
        BookingEvent.Hold(40, "18:00"),
        BookingEvent.Hold(2, "18:00"),
        BookingEvent.Pay(Pence.pounds(-5.00)),
        BookingEvent.Pay(Pence.pounds(10.00)),
        BookingEvent.Pay(Pence.pounds(99.00)),
        BookingEvent.Pay(Pence.pounds(15.00)),
    ).forEach { println("  " + guarded.fire(it).describe()) }

    heading("no rule for the event")
    val stuck = bookingMachine(seatPrice)
    println("  " + stuck.fire(BookingEvent.Board).describe())
    println("  " + stuck.fire(BookingEvent.Pay(Pence.pounds(10.00))).describe())

    heading("a terminal state is final")
    val cancelled = bookingMachine(seatPrice)
    cancelled.fireAll(
        BookingEvent.Hold(2, "18:00"),
        BookingEvent.Cancel("changed their mind"),
    )
    println("  now in ${cancelled.state.summary()}")
    listOf<BookingEvent>(
        BookingEvent.Pay(Pence.pounds(10.00)),
        BookingEvent.Board,
        BookingEvent.Amend(3),
    ).forEach { println("  " + cancelled.fire(it).describe()) }

    heading("what would be accepted from here")
    val choices = listOf(
        BookingEvent.Hold(2, "18:00"),
        BookingEvent.Pay(Pence.pounds(10.00)),
        BookingEvent.Cancel("x"),
        BookingEvent.Board,
        BookingEvent.Expire,
        BookingEvent.Amend(4),
    )
    val exploring = bookingMachine(seatPrice)
    for (step in listOf<BookingEvent?>(null, BookingEvent.Hold(2, "18:00"), BookingEvent.Pay(Pence.pounds(25.00)))) {
        step?.let { exploring.fire(it) }
        println("  from ${exploring.state.summary().padEnd(34)} " +
            exploring.accepts(choices).joinToString(", ") { it.title() })
    }

    heading("fireAll stops at the first refusal")
    val batch = bookingMachine(seatPrice)
    val outcome = batch.fireAll(
        BookingEvent.Hold(2, "18:00"),
        BookingEvent.Pay(Pence.pounds(25.00)),
        BookingEvent.Amend(5),
        BookingEvent.Board,
    )
    outcome.fold(
        onSuccess = { println("  all ${it.size} applied") },
        onFailure = { println("  stopped: ${it.message}") },
    )
    println("  ${batch.history.size} transition(s) were applied before it stopped")
    println("  the machine is in ${batch.state.summary()}")

    heading("the history")
    happy.history.forEachIndexed { index, transition ->
        println("  ${index + 1}. ${transition.event.title().padEnd(8)} " +
            "${transition.from.label} -> ${transition.to.label}")
    }

    heading("value classes refuse nonsense")
    listOf("BK-1001", "1001", "BK-1", "").forEach { candidate ->
        val result = runCatching { Reference(candidate) }
        println("  ${candidate.ifEmpty { "(empty)" }.padEnd(10)} " +
            result.fold({ "ok: $it" }, { "refused: ${it.message}" }))
    }

    heading("the audit trail a listener collected")
    val audit = mutableListOf<String>()
    val audited = bookingMachine(seatPrice, audit)
    audited.fireAll(
        BookingEvent.Hold(2, "18:00"),
        BookingEvent.Pay(Pence.pounds(25.00)),
        BookingEvent.Cancel("weather"),
    )
    audit.forEach { println("  $it") }

    heading("money arithmetic")
    val fare = Pence.pounds(12.50)
    println("  one fare        $fare")
    println("  four fares      ${fare * 4}")
    println("  less a deposit  ${fare * 4 - Pence.pounds(20.00)}")
    println("  a refund        ${Pence.Zero - fare}")
}
