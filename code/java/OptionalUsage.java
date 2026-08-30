// Optional makes "there may be no value" part of the return type, so the
// caller cannot forget the empty case.

import java.util.List;
import java.util.Map;
import java.util.Optional;

public class OptionalUsage {

    record Station(String name, int zone, Optional<String> nickname) {}

    private static final Map<String, Station> NETWORK = Map.of(
            "alder", new Station("Alder Cross", 2, Optional.of("the Cross")),
            "quill", new Station("Quill Wharf", 3, Optional.empty()));

    static Optional<Station> find(String handle) {
        return Optional.ofNullable(NETWORK.get(handle));
    }

    static String label(Station station) {
        return station.nickname().orElseGet(station::name);
    }

    public static void main(String[] args) {
        for (String handle : List.of("alder", "quill", "nether")) {
            String description = find(handle)
                    .map(station -> label(station) + " (zone " + station.zone() + ")")
                    .orElse("not on the network");
            System.out.printf("%-8s %s%n", handle, description);
        }

        // ifPresentOrElse runs one branch or the other, never both.
        find("alder").ifPresentOrElse(
                station -> System.out.println("found " + station.name()),
                () -> System.out.println("nothing found"));

        // filter narrows an Optional that is already present.
        System.out.println("deep station: " + find("alder")
                .filter(station -> station.zone() > 4)
                .map(Station::name)
                .orElse("none in zone 5 or beyond"));

        // flatMap avoids Optional<Optional<T>>.
        Optional<String> nickname = find("alder").flatMap(Station::nickname);
        System.out.println("nickname: " + nickname.orElse("(none)"));

        // orElseThrow turns absence into an exception at a chosen point.
        try {
            find("nether").orElseThrow(() -> new IllegalStateException("nether is not on file"));
        } catch (IllegalStateException error) {
            System.out.println("caught: " + error.getMessage());
        }

        System.out.println("stream of one: " + find("quill").stream().map(Station::name).toList());
    }
}
