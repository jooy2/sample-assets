// Generic classes and methods, bounded types, and the wildcards that make
// them usable at the call site.

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

public class GenericsBox {

    /** A container for any single value. */
    static final class Box<T> {
        private T value;

        Box(T value) {
            this.value = value;
        }

        T get() {
            return value;
        }

        void set(T value) {
            this.value = value;
        }

        <R> Box<R> map(java.util.function.Function<? super T, ? extends R> mapper) {
            return new Box<>(mapper.apply(value));
        }

        @Override
        public String toString() {
            return "Box(" + value + ")";
        }
    }

    /** A bounded type parameter: T must be comparable with itself. */
    static <T extends Comparable<T>> T largest(List<T> values) {
        T best = values.get(0);
        for (T value : values) {
            if (value.compareTo(best) > 0) {
                best = value;
            }
        }
        return best;
    }

    /** Producer extends: this only reads from the collection. */
    static double sum(Collection<? extends Number> numbers) {
        double total = 0;
        for (Number number : numbers) {
            total += number.doubleValue();
        }
        return total;
    }

    /** Consumer super: this only writes into the collection. */
    static void fillWithZones(Collection<? super Integer> target) {
        for (int zone = 1; zone <= 5; zone++) {
            target.add(zone);
        }
    }

    public static void main(String[] args) {
        Box<String> name = new Box<>("Alder Cross");
        System.out.println(name + " -> " + name.map(String::length));

        System.out.println("largest int: " + largest(List.of(23, 5, 91, 42)));
        System.out.println("largest string: " + largest(List.of("amber", "cobalt", "emerald")));

        System.out.println("sum of ints: " + sum(List.of(1, 2, 3)));
        System.out.println("sum of doubles: " + sum(List.of(1.5, 2.25)));

        List<Object> mixed = new ArrayList<>();
        fillWithZones(mixed);
        System.out.println("filled: " + mixed);

        // Generics are erased at runtime, so both lists share one class.
        System.out.println("same runtime class: "
                + (new ArrayList<String>().getClass() == new ArrayList<Integer>().getClass()));
    }
}
