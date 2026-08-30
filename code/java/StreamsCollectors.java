// The Stream API: filter, map, group, and reduce over a collection.

import java.util.Comparator;
import java.util.DoubleSummaryStatistics;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.IntStream;
import java.util.stream.Stream;

public class StreamsCollectors {

    record Station(String name, String line, int zone, int platforms, boolean stepFree) {}

    public static void main(String[] args) {
        List<Station> stations = List.of(
                new Station("Alder Cross", "Amber", 2, 2, true),
                new Station("Quill Wharf", "Cobalt", 3, 4, false),
                new Station("Saltwick Halt", "Amber", 5, 1, true),
                new Station("Nether Gate", "Emerald", 2, 3, true),
                new Station("Bramble Fields", "Cobalt", 4, 2, false));

        List<String> accessibleInner = stations.stream()
                .filter(Station::stepFree)
                .filter(station -> station.zone() <= 3)
                .map(Station::name)
                .sorted()
                .toList();
        System.out.println("step free, zone 3 or closer: " + accessibleInner);

        Map<String, List<String>> byLine = stations.stream()
                .collect(Collectors.groupingBy(Station::line,
                        Collectors.mapping(Station::name, Collectors.toList())));
        System.out.println("by line: " + byLine);

        Map<String, Integer> platformsPerLine = stations.stream()
                .collect(Collectors.groupingBy(Station::line,
                        Collectors.summingInt(Station::platforms)));
        System.out.println("platforms per line: " + platformsPerLine);

        Map<Boolean, Long> split = stations.stream()
                .collect(Collectors.partitioningBy(Station::stepFree, Collectors.counting()));
        System.out.println("step free vs not: " + split);

        DoubleSummaryStatistics zones = stations.stream()
                .mapToDouble(Station::zone)
                .summaryStatistics();
        System.out.printf("zones min %.0f max %.0f mean %.2f%n",
                zones.getMin(), zones.getMax(), zones.getAverage());

        System.out.println("deepest: " + stations.stream()
                .max(Comparator.comparingInt(Station::zone))
                .map(Station::name)
                .orElse("none"));

        System.out.println("joined: " + stations.stream()
                .map(Station::name)
                .collect(Collectors.joining(", ", "[", "]")));

        // Streams can be generated, not only read from a collection.
        System.out.println("squares: " + IntStream.rangeClosed(1, 8)
                .map(n -> n * n)
                .boxed()
                .toList());

        System.out.println("first three powers of two: " + Stream.iterate(1L, n -> n * 2)
                .limit(3)
                .toList());
    }
}
