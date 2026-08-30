// Records: value equality, `with` expressions, and deconstruction, without
// writing any of it by hand.

using System;

record Address(string City, string Country, string PostalCode);

record User(int Id, string FirstName, string LastName, Address Address)
{
    public string FullName => $"{FirstName} {LastName}";

    // Records can still declare their own members and validation.
    public bool IsInCountry(string country) =>
        string.Equals(Address.Country, country, StringComparison.OrdinalIgnoreCase);
}

readonly record struct Point(double X, double Y);

class RecordTypes
{
    static void Main()
    {
        var original = new User(1, "Imogen", "Hawthorne",
            new Address("Harrowgate", "Kestrand", "KE-8256"));

        // `with` copies everything except the members it names.
        var moved = original with { Address = original.Address with { City = "Stonebay" } };

        Console.WriteLine(original.FullName);
        Console.WriteLine(original);
        Console.WriteLine(moved.Address);

        var same = new User(1, "Imogen", "Hawthorne",
            new Address("Harrowgate", "Kestrand", "KE-8256"));

        Console.WriteLine($"value equality: {original == same}");
        Console.WriteLine($"reference equality: {ReferenceEquals(original, same)}");
        Console.WriteLine($"after the move: {original == moved}");

        var (city, country, postal) = original.Address;
        Console.WriteLine($"deconstructed: {city}, {country}, {postal}");

        Console.WriteLine(new Point(3, 4) with { Y = 5 });
    }
}
