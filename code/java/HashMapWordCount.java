// Counting words with a HashMap, then ranking them, using the map methods
// that avoid a null check.

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

public class HashMapWordCount {

    public static void main(String[] args) {
        String text = """
                The tide came in and the tide went out
                and the shore stayed where it was
                """;

        Map<String, Integer> counts = new HashMap<>();
        for (String word : text.toLowerCase().split("\\W+")) {
            if (word.isEmpty()) {
                continue;
            }
            counts.merge(word, 1, Integer::sum);
        }

        System.out.println(counts.size() + " distinct words");

        List<Map.Entry<String, Integer>> ranked = new ArrayList<>(counts.entrySet());
        ranked.sort(Map.Entry.<String, Integer>comparingByValue().reversed()
                .thenComparing(Map.Entry.comparingByKey()));

        ranked.stream().limit(5)
                .forEach(entry -> System.out.printf("%2d  %s%n", entry.getValue(), entry.getKey()));

        // computeIfAbsent builds the value only when the key is new.
        Map<Character, List<String>> byFirstLetter = new TreeMap<>();
        for (String word : counts.keySet()) {
            byFirstLetter.computeIfAbsent(word.charAt(0), key -> new ArrayList<>()).add(word);
        }
        byFirstLetter.values().forEach(java.util.Collections::sort);
        System.out.println("\ngrouped: " + byFirstLetter);

        // getOrDefault reads without inserting.
        System.out.println("count of 'tide': " + counts.getOrDefault("tide", 0));
        System.out.println("count of 'ferry': " + counts.getOrDefault("ferry", 0));

        // A LinkedHashMap keeps insertion order; a TreeMap keeps key order.
        Map<String, Integer> ordered = new LinkedHashMap<>();
        ranked.stream().limit(3).forEach(entry -> ordered.put(entry.getKey(), entry.getValue()));
        System.out.println("top three in order: " + ordered);

        counts.entrySet().removeIf(entry -> entry.getValue() < 2);
        System.out.println("words seen more than once: " + new TreeMap<>(counts).keySet());

        System.out.println("longest: " + counts.keySet().stream()
                .max(Comparator.comparingInt(String::length)).orElse("(none)"));
    }
}
