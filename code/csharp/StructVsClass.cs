// A struct is copied on assignment; a class is a reference to shared state.

using System;

struct PointStruct
{
    public double X;
    public double Y;

    public PointStruct(double x, double y) => (X, Y) = (x, y);

    public override string ToString() => $"({X}, {Y})";
}

class PointClass
{
    public double X;
    public double Y;

    public PointClass(double x, double y) => (X, Y) = (x, y);

    public override string ToString() => $"({X}, {Y})";
}

readonly struct Temperature
{
    public double Celsius { get; }

    public Temperature(double celsius) => Celsius = celsius;

    public double Fahrenheit => Celsius * 9 / 5 + 32;

    // A readonly struct cannot be mutated, so it returns a new value instead.
    public Temperature Warmer(double degrees) => new(Celsius + degrees);
}

class StructVsClass
{
    static void MoveRight(PointStruct point) => point.X += 100;
    static void MoveRight(PointClass point) => point.X += 100;

    static void Main()
    {
        var structPoint = new PointStruct(1, 2);
        var structCopy = structPoint;
        structCopy.X = 99;
        MoveRight(structPoint);
        Console.WriteLine($"struct original {structPoint}, copy {structCopy}");

        var classPoint = new PointClass(1, 2);
        var classAlias = classPoint;
        classAlias.X = 99;
        MoveRight(classPoint);
        Console.WriteLine($"class  original {classPoint}, alias {classAlias}");

        // Structs compare by their fields, classes by reference unless told otherwise.
        Console.WriteLine($"struct equality: {new PointStruct(1, 2).Equals(new PointStruct(1, 2))}");
        Console.WriteLine($"class equality:  {new PointClass(1, 2).Equals(new PointClass(1, 2))}");

        var reading = new Temperature(21.5);
        Console.WriteLine($"{reading.Celsius}C is {reading.Fahrenheit:F1}F");
        Console.WriteLine($"warmer: {reading.Warmer(4).Celsius}C, original still {reading.Celsius}C");
    }
}
