// Reading and writing text files with java.nio.file, including streaming a
// large file one line at a time.

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.stream.Stream;

public class FileLinesReader {

    record Station(String name, String line, int zone) {
        static Station parse(String csvRow) {
            String[] fields = csvRow.split(",");
            return new Station(fields[0], fields[1], Integer.parseInt(fields[2]));
        }
    }

    public static void main(String[] args) throws IOException {
        Path file = Files.createTempFile("sample-assets-stations-", ".csv");

        List<String> rows = List.of(
                "station,line,zone",
                "Alder Cross,Amber,2",
                "Quill Wharf,Cobalt,3",
                "Saltwick Halt,Amber,5",
                "Nether Gate,Emerald,2");

        Files.write(file, rows, StandardCharsets.UTF_8);
        System.out.println("wrote " + Files.size(file) + " bytes to " + file);

        // Small file: read it all at once.
        List<String> readBack = Files.readAllLines(file, StandardCharsets.UTF_8);
        System.out.println("read " + readBack.size() + " lines, header " + readBack.get(0));

        // Large file: stream it, so only one line is in memory at a time.
        try (Stream<String> lines = Files.lines(file, StandardCharsets.UTF_8)) {
            double averageZone = lines.skip(1)
                    .map(Station::parse)
                    .mapToInt(Station::zone)
                    .average()
                    .orElse(0);
            System.out.printf("average zone %.2f%n", averageZone);
        }

        try (Stream<String> lines = Files.lines(file)) {
            lines.skip(1)
                    .map(Station::parse)
                    .filter(station -> station.line().equals("Amber"))
                    .forEach(station -> System.out.println("  Amber: " + station.name()));
        }

        // Appending, and reading the whole thing as one string.
        Files.writeString(file, "Vellin Halt,Slate,4\n",
                StandardCharsets.UTF_8, java.nio.file.StandardOpenOption.APPEND);
        System.out.println("now " + Files.readString(file).lines().count() + " lines");

        Files.deleteIfExists(file);
        System.out.println("removed: " + Files.notExists(file));
    }
}
