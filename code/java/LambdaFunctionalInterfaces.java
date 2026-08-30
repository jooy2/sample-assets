// Lambdas, method references, and the functional interfaces in
// java.util.function that they fit into.

import java.util.List;
import java.util.function.BiFunction;
import java.util.function.BinaryOperator;
import java.util.function.Consumer;
import java.util.function.Function;
import java.util.function.Predicate;
import java.util.function.Supplier;
import java.util.function.UnaryOperator;

public class LambdaFunctionalInterfaces {

    /** Any interface with one abstract method can be written as a lambda. */
    @FunctionalInterface
    interface Fare {
        double forZones(int from, int to);

        default double returnTrip(int from, int to) {
            return forZones(from, to) * 2;
        }
    }

    public static void main(String[] args) {
        Predicate<String> isLong = name -> name.length() > 11;
        Function<String, Integer> length = String::length;
        Supplier<List<String>> lines = () -> List.of("Amber", "Cobalt", "Emerald");
        Consumer<String> print = System.out::println;
        BiFunction<Integer, Integer, Integer> add = Integer::sum;
        UnaryOperator<String> shout = String::toUpperCase;
        BinaryOperator<Integer> larger = Integer::max;

        List<String> stations = List.of("Alder Cross", "Quill Wharf", "Saltwick Halt");

        System.out.println("long names: " + stations.stream().filter(isLong).toList());
        System.out.println("lengths: " + stations.stream().map(length).toList());
        System.out.println("lines: " + lines.get());
        stations.forEach(print);
        System.out.println("3 + 4 = " + add.apply(3, 4));
        System.out.println(shout.apply("amber") + ", larger of 4 and 9 is " + larger.apply(4, 9));

        // Predicates and functions compose.
        Predicate<String> startsWithA = name -> name.startsWith("A");
        System.out.println("long and starts with A: "
                + stations.stream().filter(isLong.and(startsWithA)).toList());
        System.out.println("not long: " + stations.stream().filter(isLong.negate()).toList());

        Function<String, String> firstWord = name -> name.split(" ")[0];
        System.out.println("composed: " + firstWord.andThen(shout).apply("Quill Wharf"));

        Fare flat = (from, to) -> 2.40 + Math.abs(to - from) * 0.85;
        System.out.printf("zone 2 to 5 costs %.2f, return %.2f%n",
                flat.forZones(2, 5), flat.returnTrip(2, 5));

        // The four kinds of method reference.
        Function<String, Integer> parse = Integer::parseInt;                 // static
        Function<String, String> trim = String::trim;                        // unbound instance
        Supplier<String> constant = "Alder Cross"::toUpperCase;              // bound instance
        Supplier<StringBuilder> builder = StringBuilder::new;                // constructor

        System.out.println(parse.apply("42") + " " + trim.apply("  x  ")
                + " " + constant.get() + " " + builder.get().append("built"));
    }
}
