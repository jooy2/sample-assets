// Switch expressions and patterns: type, property, relational, and tuple.

using System;

abstract record Shape;
record Circle(double Radius) : Shape;
record Rectangle(double Width, double Height) : Shape;
record Triangle(double Base, double Height) : Shape;

class PatternMatching
{
    static double Area(Shape shape) => shape switch
    {
        Circle { Radius: <= 0 } => 0,
        Circle circle => Math.PI * circle.Radius * circle.Radius,
        Rectangle { Width: var w, Height: var h } => w * h,
        Triangle triangle => triangle.Base * triangle.Height / 2,
        _ => throw new ArgumentOutOfRangeException(nameof(shape)),
    };

    static string Describe(Shape shape) => shape switch
    {
        Rectangle rectangle when rectangle.Width == rectangle.Height => "a square",
        Rectangle => "a rectangle",
        Circle { Radius: > 10 } => "a large circle",
        Circle => "a circle",
        _ => "some other shape",
    };

    static string Grade(int score) => score switch
    {
        >= 90 => "A",
        >= 80 => "B",
        >= 70 => "C",
        >= 60 => "D",
        _ => "F",
    };

    static string Quadrant((double X, double Y) point) => point switch
    {
        (0, 0) => "the origin",
        ( > 0, > 0) => "quadrant I",
        ( < 0, > 0) => "quadrant II",
        ( < 0, < 0) => "quadrant III",
        ( > 0, < 0) => "quadrant IV",
        _ => "an axis",
    };

    static void Main()
    {
        Shape[] shapes = { new Circle(2), new Rectangle(4, 4), new Triangle(6, 2.5), new Circle(12) };

        foreach (var shape in shapes)
        {
            Console.WriteLine($"{Describe(shape),-16} area {Area(shape):F2}");
        }

        foreach (int score in new[] { 95, 83, 71, 42 })
        {
            Console.WriteLine($"{score} -> {Grade(score)}");
        }

        Console.WriteLine(Quadrant((-3, 4)));
        Console.WriteLine(Quadrant((0, 0)));
    }
}
