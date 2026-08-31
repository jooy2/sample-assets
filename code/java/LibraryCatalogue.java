import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.OptionalDouble;
import java.util.function.Predicate;
import java.util.stream.Collectors;

/**
 * A lending library: a domain model built from records and a sealed hierarchy,
 * an in-memory repository, a composable query API, a loan ledger with fines,
 * and a set of reports.
 *
 * Single file, standard library only, no framework.
 *
 * <pre>
 *   javac LibraryCatalogue.java
 *   java LibraryCatalogue
 * </pre>
 *
 * Every borrower, title, and figure below is invented.
 */
public final class LibraryCatalogue {

    private LibraryCatalogue() {
    }

    // ------------------------------------------------------------ the model

    /** Everything the library lends is one of these four kinds. */
    public sealed interface Holding
            permits Book, Periodical, AudioRecording, ReferenceOnly {

        String id();

        String title();

        /** How long this kind of holding may be borrowed for. */
        int loanDays();

        /** Fine per day once a loan is overdue, in pence. */
        int finePerDay();

        default boolean lendable() {
            return loanDays() > 0;
        }
    }

    public record Book(
            String id,
            String title,
            String author,
            int year,
            String isbn,
            Shelf shelf) implements Holding {

        public Book {
            Objects.requireNonNull(id, "id");
            Objects.requireNonNull(title, "title");
            if (year < 1450) {
                throw new IllegalArgumentException("year before movable type: " + year);
            }
        }

        @Override
        public int loanDays() {
            return shelf == Shelf.SHORT_LOAN ? 7 : 21;
        }

        @Override
        public int finePerDay() {
            return shelf == Shelf.SHORT_LOAN ? 50 : 15;
        }
    }

    public record Periodical(
            String id,
            String title,
            int volume,
            int issue,
            LocalDate published) implements Holding {

        @Override
        public int loanDays() {
            return 7;
        }

        @Override
        public int finePerDay() {
            return 20;
        }
    }

    public record AudioRecording(
            String id,
            String title,
            String performer,
            int minutes) implements Holding {

        @Override
        public int loanDays() {
            return 14;
        }

        @Override
        public int finePerDay() {
            return 25;
        }
    }

    /** Held for consultation in the reading room, never lent. */
    public record ReferenceOnly(
            String id,
            String title,
            String note) implements Holding {

        @Override
        public int loanDays() {
            return 0;
        }

        @Override
        public int finePerDay() {
            return 0;
        }
    }

    public enum Shelf {
        GENERAL, SHORT_LOAN, STORE, LOCAL_HISTORY
    }

    public record Member(String card, String name, LocalDate joined, boolean staff) {

        /** Staff may hold more at once, and are not fined. */
        public int limit() {
            return staff ? 20 : 6;
        }
    }

    /** One loan. Immutable; returning a copy rather than mutating in place. */
    public record Loan(
            String holdingId,
            String card,
            LocalDate taken,
            LocalDate due,
            Optional<LocalDate> returned) {

        public boolean open() {
            return returned.isEmpty();
        }

        public boolean overdueOn(LocalDate date) {
            LocalDate end = returned.orElse(date);
            return end.isAfter(due);
        }

        public long daysOverdueOn(LocalDate date) {
            LocalDate end = returned.orElse(date);
            return end.isAfter(due) ? ChronoUnit.DAYS.between(due, end) : 0;
        }

        public Loan returnedOn(LocalDate date) {
            return new Loan(holdingId, card, taken, due, Optional.of(date));
        }
    }

    // ------------------------------------------------------------- failures

    public static class LibraryException extends RuntimeException {
        public LibraryException(String message) {
            super(message);
        }
    }

    public static final class NotLendableException extends LibraryException {
        public NotLendableException(Holding holding) {
            super(holding.title() + " is reference only");
        }
    }

    public static final class AlreadyOnLoanException extends LibraryException {
        public AlreadyOnLoanException(String holdingId) {
            super(holdingId + " is already on loan");
        }
    }

    public static final class LimitReachedException extends LibraryException {
        public LimitReachedException(Member member) {
            super(member.name() + " already holds " + member.limit() + " items");
        }
    }

    // ----------------------------------------------------------- the catalogue

    /** An in-memory catalogue with a loan ledger. */
    public static final class Catalogue {

        private final Map<String, Holding> holdings = new LinkedHashMap<>();
        private final Map<String, Member> members = new LinkedHashMap<>();
        private final List<Loan> ledger = new ArrayList<>();

        public Catalogue add(Holding holding) {
            if (holdings.putIfAbsent(holding.id(), holding) != null) {
                throw new LibraryException("duplicate holding id: " + holding.id());
            }
            return this;
        }

        public Catalogue enrol(Member member) {
            members.put(member.card(), member);
            return this;
        }

        public Optional<Holding> holding(String id) {
            return Optional.ofNullable(holdings.get(id));
        }

        public Optional<Member> member(String card) {
            return Optional.ofNullable(members.get(card));
        }

        public List<Holding> all() {
            return List.copyOf(holdings.values());
        }

        public List<Loan> loans() {
            return List.copyOf(ledger);
        }

        // ---------------------------------------------------------- lending

        public Loan lend(String holdingId, String card, LocalDate on) {
            Holding holding = holding(holdingId)
                    .orElseThrow(() -> new LibraryException("no such holding: " + holdingId));
            Member member = member(card)
                    .orElseThrow(() -> new LibraryException("no such member: " + card));

            if (!holding.lendable()) {
                throw new NotLendableException(holding);
            }
            if (onLoan(holdingId)) {
                throw new AlreadyOnLoanException(holdingId);
            }
            if (openLoansFor(card).size() >= member.limit()) {
                throw new LimitReachedException(member);
            }

            Loan loan = new Loan(
                    holdingId, card, on, on.plusDays(holding.loanDays()), Optional.empty());
            ledger.add(loan);
            return loan;
        }

        public Loan giveBack(String holdingId, LocalDate on) {
            for (int index = 0; index < ledger.size(); index++) {
                Loan loan = ledger.get(index);
                if (loan.holdingId().equals(holdingId) && loan.open()) {
                    Loan closed = loan.returnedOn(on);
                    ledger.set(index, closed);
                    return closed;
                }
            }
            throw new LibraryException(holdingId + " is not on loan");
        }

        public boolean onLoan(String holdingId) {
            return ledger.stream()
                    .anyMatch(loan -> loan.holdingId().equals(holdingId) && loan.open());
        }

        public List<Loan> openLoansFor(String card) {
            return ledger.stream()
                    .filter(loan -> loan.card().equals(card) && loan.open())
                    .toList();
        }

        /** What a member owes, in pence. Staff are never fined. */
        public int fineFor(String card, LocalDate on) {
            Member member = member(card).orElseThrow();
            if (member.staff()) {
                return 0;
            }
            return ledger.stream()
                    .filter(loan -> loan.card().equals(card))
                    .mapToInt(loan -> (int) loan.daysOverdueOn(on)
                            * holdings.get(loan.holdingId()).finePerDay())
                    .sum();
        }

        // ---------------------------------------------------------- queries

        public Query query() {
            return new Query(all());
        }
    }

    // ---------------------------------------------------------------- query

    /**
     * A composable, immutable query over holdings. Each method returns a new
     * Query rather than mutating this one, so a partly-built query can be
     * shared and reused.
     */
    public static final class Query {

        private final List<Holding> source;

        private Query(List<Holding> source) {
            this.source = source;
        }

        public Query where(Predicate<Holding> predicate) {
            return new Query(source.stream().filter(predicate).toList());
        }

        public Query titleContains(String fragment) {
            String needle = fragment.toLowerCase();
            return where(h -> h.title().toLowerCase().contains(needle));
        }

        public Query kind(Class<? extends Holding> type) {
            return where(type::isInstance);
        }

        public Query lendableOnly() {
            return where(Holding::lendable);
        }

        public Query sortedBy(Comparator<Holding> comparator) {
            return new Query(source.stream().sorted(comparator).toList());
        }

        public Query limit(int count) {
            return new Query(source.stream().limit(count).toList());
        }

        public List<Holding> toList() {
            return source;
        }

        public int count() {
            return source.size();
        }

        public Map<String, List<Holding>> groupedByKind() {
            return source.stream().collect(Collectors.groupingBy(
                    holding -> holding.getClass().getSimpleName(),
                    LinkedHashMap::new,
                    Collectors.toList()));
        }
    }

    // -------------------------------------------------------------- describe

    /**
     * A one-line description of any holding. Written as a chain of instanceof
     * checks with binding, which compiles on every Java since 16 — a switch
     * over the sealed hierarchy would be tidier but needs a newer release.
     */
    public static String describe(Holding holding) {
        if (holding instanceof Book book) {
            return "%s, %s (%d) [%s]".formatted(
                    book.author(), book.title(), book.year(), book.shelf());
        }
        if (holding instanceof Periodical periodical) {
            return "%s vol.%d no.%d, %s".formatted(
                    periodical.title(), periodical.volume(),
                    periodical.issue(), periodical.published());
        }
        if (holding instanceof AudioRecording recording) {
            return "%s — %s (%d min)".formatted(
                    recording.performer(), recording.title(), recording.minutes());
        }
        if (holding instanceof ReferenceOnly reference) {
            return "%s [reference: %s]".formatted(reference.title(), reference.note());
        }
        throw new IllegalStateException("unreachable: sealed hierarchy is closed");
    }

    // --------------------------------------------------------------- reports

    public static String money(int pence) {
        return "£%d.%02d".formatted(pence / 100, Math.abs(pence % 100));
    }

    public static List<String> overdueReport(Catalogue catalogue, LocalDate on) {
        record Row(Member member, Loan loan, long days, int fine) {
        }

        List<Row> rows = catalogue.loans().stream()
                .filter(loan -> loan.open() && loan.overdueOn(on))
                .map(loan -> {
                    Member member = catalogue.member(loan.card()).orElseThrow();
                    Holding holding = catalogue.holding(loan.holdingId()).orElseThrow();
                    long days = loan.daysOverdueOn(on);
                    int fine = member.staff() ? 0 : (int) days * holding.finePerDay();
                    return new Row(member, loan, days, fine);
                })
                .sorted(Comparator.comparingLong(Row::days).reversed())
                .toList();

        List<String> lines = new ArrayList<>();
        lines.add("Overdue as at " + on);
        lines.add("-".repeat(62));
        for (Row row : rows) {
            Holding holding = catalogue.holding(row.loan().holdingId()).orElseThrow();
            lines.add("%-22s %-26s %3d d %8s".formatted(
                    row.member().name(),
                    truncate(holding.title(), 26),
                    row.days(),
                    row.fine() == 0 ? "-" : money(row.fine())));
        }
        int total = rows.stream().mapToInt(Row::fine).sum();
        lines.add("-".repeat(62));
        lines.add("%-53s %8s".formatted(rows.size() + " item(s) overdue", money(total)));
        return lines;
    }

    public static List<String> shelfReport(Catalogue catalogue) {
        Map<Shelf, List<Book>> byShelf = catalogue.all().stream()
                .filter(Book.class::isInstance)
                .map(Book.class::cast)
                .collect(Collectors.groupingBy(Book::shelf, () -> new HashMap<>(),
                        Collectors.toList()));

        List<String> lines = new ArrayList<>();
        lines.add("Books by shelf");
        lines.add("-".repeat(48));
        for (Shelf shelf : Shelf.values()) {
            List<Book> books = byShelf.getOrDefault(shelf, List.of());
            OptionalDouble averageYear = books.stream().mapToInt(Book::year).average();
            lines.add("%-16s %3d  %s".formatted(
                    shelf,
                    books.size(),
                    averageYear.isPresent()
                            ? "mean year %.0f".formatted(averageYear.getAsDouble())
                            : "—"));
        }
        return lines;
    }

    private static String truncate(String text, int width) {
        return text.length() <= width ? text : text.substring(0, width - 1) + "…";
    }

    // ------------------------------------------------------------------ main

    private static Catalogue sampleCatalogue() {
        Catalogue catalogue = new Catalogue();

        catalogue.add(new Book("B-001", "The Lamplighter's Daughter",
                "Ilse Marchetti", 2027, "978-0-000000-01-1", Shelf.GENERAL));
        catalogue.add(new Book("B-002", "Tide Tables",
                "Oswin Bramble", 2026, "978-0-000000-02-8", Shelf.GENERAL));
        catalogue.add(new Book("B-003", "Reading an Archive",
                "Helena Vance", 2027, "978-0-000000-03-5", Shelf.SHORT_LOAN));
        catalogue.add(new Book("B-004", "Eight Things Worth Cooking Twice",
                "Beatrix Oduya", 2025, "978-0-000000-04-2", Shelf.GENERAL));
        catalogue.add(new Book("B-005", "Fenwick Before the Bridge",
                "T. Renn", 1974, "978-0-000000-05-9", Shelf.LOCAL_HISTORY));
        catalogue.add(new Book("B-006", "Estuary Birds of the North Coast",
                "N. Adeyemi", 1988, "978-0-000000-06-6", Shelf.STORE));
        catalogue.add(new Book("B-007", "The Ferry Question",
                "R. Almeida", 2027, "978-0-000000-07-3", Shelf.SHORT_LOAN));

        catalogue.add(new Periodical("P-101", "Journal of Invented Methods",
                12, 3, LocalDate.of(2026, 9, 1)));
        catalogue.add(new Periodical("P-102", "Journal of Invented Methods",
                12, 4, LocalDate.of(2026, 12, 1)));
        catalogue.add(new Periodical("P-103", "Coastal Infrastructure Quarterly",
                8, 2, LocalDate.of(2027, 4, 1)));

        catalogue.add(new AudioRecording("A-201", "Fog Signals",
                "The Halloway Consort", 47));
        catalogue.add(new AudioRecording("A-202", "Night Crossing",
                "Solveig Halvorsen", 62));

        catalogue.add(new ReferenceOnly("R-301", "Fenwick Parish Registers 1801-1899",
                "consult in the reading room"));
        catalogue.add(new ReferenceOnly("R-302", "Ordnance Survey, Fenwick sheet 41",
                "oversize, requires a table"));

        catalogue.enrol(new Member("C-0001", "Mira Oduya", LocalDate.of(2019, 4, 2), false));
        catalogue.enrol(new Member("C-0002", "Tobias Renn", LocalDate.of(2021, 9, 13), true));
        catalogue.enrol(new Member("C-0003", "Yolanda Beaumont", LocalDate.of(2023, 11, 13), false));
        catalogue.enrol(new Member("C-0004", "Aurelio Bassani", LocalDate.of(2018, 11, 5), false));

        return catalogue;
    }

    public static void main(String[] args) {
        Catalogue catalogue = sampleCatalogue();
        LocalDate today = LocalDate.of(2027, 9, 2);

        System.out.println("--- the catalogue ---");
        catalogue.query()
                .sortedBy(Comparator.comparing(Holding::title))
                .toList()
                .forEach(holding -> System.out.println("  " + describe(holding)));

        System.out.println("\n--- grouped by kind ---");
        catalogue.query().groupedByKind().forEach((kind, items) ->
                System.out.printf("  %-16s %d%n", kind, items.size()));

        System.out.println("\n--- lendable, short loan first ---");
        catalogue.query()
                .lendableOnly()
                .sortedBy(Comparator.comparingInt(Holding::loanDays)
                        .thenComparing(Holding::title))
                .limit(5)
                .toList()
                .forEach(holding -> System.out.printf("  %2d days  %s%n",
                        holding.loanDays(), holding.title()));

        System.out.println("\n--- search ---");
        catalogue.query().titleContains("journal").toList()
                .forEach(holding -> System.out.println("  " + describe(holding)));

        System.out.println("\n--- lending ---");
        catalogue.lend("B-003", "C-0001", today.minusDays(30));
        catalogue.lend("B-001", "C-0001", today.minusDays(10));
        catalogue.lend("P-101", "C-0003", today.minusDays(21));
        catalogue.lend("A-201", "C-0002", today.minusDays(40));
        catalogue.lend("B-005", "C-0004", today.minusDays(3));
        catalogue.lend("B-007", "C-0003", today.minusDays(12));
        System.out.println("  loans on the ledger: " + catalogue.loans().size());

        System.out.println("\n--- refusals ---");
        for (Runnable attempt : List.<Runnable>of(
                () -> catalogue.lend("R-301", "C-0001", today),
                () -> catalogue.lend("B-003", "C-0004", today),
                () -> catalogue.lend("B-002", "C-9999", today))) {
            try {
                attempt.run();
                System.out.println("  (unexpectedly allowed)");
            } catch (LibraryException error) {
                System.out.printf("  %-24s %s%n",
                        error.getClass().getSimpleName(), error.getMessage());
            }
        }

        System.out.println();
        overdueReport(catalogue, today).forEach(System.out::println);

        System.out.println("\n--- returns ---");
        Loan closed = catalogue.giveBack("B-003", today);
        System.out.printf("  B-003 back after %d day(s) overdue, fine %s%n",
                closed.daysOverdueOn(today),
                money((int) closed.daysOverdueOn(today) * 50));
        System.out.println("  Mira now owes " + money(catalogue.fineFor("C-0001", today)));
        System.out.println("  Tobias (staff) owes " + money(catalogue.fineFor("C-0002", today)));

        System.out.println();
        shelfReport(catalogue).forEach(System.out::println);

        System.out.println("\n--- records compare by value ---");
        Book one = new Book("B-999", "Same", "A", 2000, "x", Shelf.GENERAL);
        Book two = new Book("B-999", "Same", "A", 2000, "x", Shelf.GENERAL);
        System.out.println("  equal: " + one.equals(two)
                + ", same hash: " + (one.hashCode() == two.hashCode()));
        try {
            new Book("B-000", "Impossible", "Nobody", 1200, "x", Shelf.STORE);
        } catch (IllegalArgumentException error) {
            System.out.println("  compact constructor rejected: " + error.getMessage());
        }
    }
}
