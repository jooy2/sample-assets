// Records give value semantics for free; a sealed interface fixes the set
// of implementations so a switch over it can be exhaustive.
//
// The pattern switch below is standard from Java 21 onwards.

import java.util.List;

public class RecordsAndSealed {

    sealed interface Shape permits Circle, Rectangle, Triangle {}

    record Circle(double radius) implements Shape {
        Circle {
            if (radius <= 0) {
                throw new IllegalArgumentException("radius must be positive");
            }
        }

        double diameter() {
            return radius * 2;
        }
    }

    record Rectangle(double width, double height) implements Shape {
        boolean isSquare() {
            return width == height;
        }
    }

    record Triangle(double base, double height) implements Shape {}

    static double area(Shape shape) {
        return switch (shape) {
            case Circle circle -> Math.PI * circle.radius() * circle.radius();
            case Rectangle rectangle -> rectangle.width() * rectangle.height();
            case Triangle triangle -> triangle.base() * triangle.height() / 2;
        };
    }

    static String describe(Shape shape) {
        if (shape instanceof Rectangle rectangle && rectangle.isSquare()) {
            return "a square";
        }
        if (shape instanceof Circle circle && circle.radius() > 10) {
            return "a large circle";
        }
        return shape.getClass().getSimpleName().toLowerCase();
    }

    public static void main(String[] args) {
        List<Shape> shapes = List.of(
                new Circle(2), new Rectangle(4, 4), new Triangle(6, 2.5), new Circle(12));

        double total = 0;
        for (Shape shape : shapes) {
            total += area(shape);
            System.out.printf("%-16s area %7.2f%n", describe(shape), area(shape));
        }
        System.out.printf("total %.2f%n", total);

        // Records get equals, hashCode, and toString from their components.
        Circle first = new Circle(2);
        Circle second = new Circle(2);
        System.out.println(first);
        System.out.println("equal: " + first.equals(second) + ", same object: " + (first == second));
        System.out.println("diameter: " + first.diameter());

        try {
            new Circle(-1);
        } catch (IllegalArgumentException error) {
            System.out.println("compact constructor rejected it: " + error.getMessage());
        }
    }
}
