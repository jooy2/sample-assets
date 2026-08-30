// A sealed class fixes its set of subtypes, so a switch over it can be
// checked for completeness at compile time.

sealed class Shape {
  const Shape();
}

class Circle extends Shape {
  const Circle(this.radius);
  final double radius;
}

class Rectangle extends Shape {
  const Rectangle(this.width, this.height);
  final double width;
  final double height;
}

class Triangle extends Shape {
  const Triangle(this.base, this.height);
  final double base;
  final double height;
}

// No default branch: adding a fourth Shape would break the build here,
// which is the point.
double area(Shape shape) => switch (shape) {
      Circle(:final radius) => 3.14159265 * radius * radius,
      Rectangle(:final width, :final height) => width * height,
      Triangle(:final base, :final height) => base * height / 2,
    };

String describe(Shape shape) => switch (shape) {
      Rectangle(:final width, :final height) when width == height => 'a square',
      Rectangle() => 'a rectangle',
      Circle(radius: > 10) => 'a large circle',
      Circle() => 'a circle',
      Triangle() => 'a triangle',
    };

sealed class Result<T> {
  const Result();
}

class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

class Err<T> extends Result<T> {
  const Err(this.message);
  final String message;
}

Result<int> parseZone(String raw) {
  final zone = int.tryParse(raw);
  if (zone == null) {
    return Err('"$raw" is not a number');
  }
  return zone < 1 || zone > 6 ? Err('zone $zone is outside 1-6') : Ok(zone);
}

void main() {
  const shapes = <Shape>[Circle(2), Rectangle(4, 4), Triangle(6, 2.5), Circle(12)];

  for (final shape in shapes) {
    print('${describe(shape).padRight(16)} area ${area(shape).toStringAsFixed(2)}');
  }

  for (final raw in ['3', '9', 'east']) {
    final message = switch (parseZone(raw)) {
      Ok(:final value) => 'zone $value',
      Err(:final message) => 'rejected: $message',
    };
    print('${raw.padRight(6)} $message');
  }
}
