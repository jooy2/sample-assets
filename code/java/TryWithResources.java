// try-with-resources closes everything it opened, in reverse order, even
// when the body throws.

import java.io.BufferedReader;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

public class TryWithResources {

    /** Any AutoCloseable can take part, including your own types. */
    static final class Workspace implements AutoCloseable {
        private final Path path;

        Workspace(String name) throws IOException {
            path = Files.createTempDirectory(name);
            System.out.println("created " + path);
        }

        Path write(String fileName, List<String> lines) throws IOException {
            return Files.write(path.resolve(fileName), lines);
        }

        @Override
        public void close() throws IOException {
            try (var entries = Files.walk(path)) {
                entries.sorted((a, b) -> b.compareTo(a)).forEach(entry -> {
                    try {
                        Files.delete(entry);
                    } catch (IOException error) {
                        throw new UncheckedIOException(error);
                    }
                });
            }
            System.out.println("removed " + path);
        }
    }

    public static void main(String[] args) throws IOException {
        try (Workspace workspace = new Workspace("sample-assets-")) {
            Path file = workspace.write("stations.csv",
                    List.of("station,line,zone", "Alder Cross,Amber,2", "Quill Wharf,Cobalt,3"));

            try (BufferedReader reader = Files.newBufferedReader(file)) {
                String header = reader.readLine();
                System.out.println("header: " + header);
                reader.lines().forEach(line -> System.out.println("  " + line));
            }
        }

        // The resource is still closed when the body throws.
        try (Workspace workspace = new Workspace("sample-assets-failing-")) {
            workspace.write("notes.txt", List.of("one line"));
            throw new IllegalStateException("interrupted halfway");
        } catch (IllegalStateException error) {
            System.out.println("caught: " + error.getMessage());
        }
    }
}
