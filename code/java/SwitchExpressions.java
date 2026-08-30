// A switch expression returns a value, needs no breaks, and must cover
// every case.

import java.time.DayOfWeek;
import java.util.List;

public class SwitchExpressions {

    enum Priority { LOW, NORMAL, HIGH, URGENT }

    static String responseTime(Priority priority) {
        return switch (priority) {
            case LOW -> "within a week";
            case NORMAL -> "within two days";
            case HIGH -> "within four hours";
            case URGENT -> "immediately";
        };
    }

    static int platformsFor(String line) {
        // Several labels can share one arm.
        return switch (line) {
            case "Amber", "Cobalt" -> 4;
            case "Emerald", "Crimson" -> 3;
            case "Slate" -> 2;
            default -> 1;
        };
    }

    /** A block arm uses `yield` to produce the value. */
    static String describeZone(int zone) {
        return switch (zone) {
            case 1, 2 -> "central";
            case 3, 4 -> {
                String suffix = zone == 3 ? " (still frequent)" : "";
                yield "suburban" + suffix;
            }
            default -> {
                if (zone > 6) {
                    yield "off the network";
                }
                yield "outer";
            }
        };
    }

    static boolean isWeekend(DayOfWeek day) {
        return switch (day) {
            case SATURDAY, SUNDAY -> true;
            default -> false;
        };
    }

    public static void main(String[] args) {
        for (Priority priority : Priority.values()) {
            System.out.printf("%-7s %s%n", priority, responseTime(priority));
        }

        for (String line : List.of("Amber", "Slate", "Violet")) {
            System.out.println(line + " -> " + platformsFor(line) + " platforms");
        }

        for (int zone : new int[] {1, 3, 4, 5, 9}) {
            System.out.println("zone " + zone + " is " + describeZone(zone));
        }

        System.out.println("Saturday is a weekend: " + isWeekend(DayOfWeek.SATURDAY));
        System.out.println("Tuesday is a weekend: " + isWeekend(DayOfWeek.TUESDAY));
    }
}
