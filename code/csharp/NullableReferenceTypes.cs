// With nullable reference types on, the compiler tracks which references
// are allowed to be null and warns when one is used unchecked.

#nullable enable

using System;
using System.Collections.Generic;
using System.Diagnostics.CodeAnalysis;

class Profile
{
    public required string Name { get; init; } // never null
    public string? Nickname { get; init; }     // may be null
}

class NullableReferenceTypes
{
    static IReadOnlyDictionary<string, Profile> Directory { get; } =
        new Dictionary<string, Profile>
        {
            ["imogen"] = new Profile { Name = "Imogen Hawthorne", Nickname = "Immy" },
            ["soren"] = new Profile { Name = "Soren Wexford" },
        };

    static bool TryFind(string handle, [NotNullWhen(true)] out Profile? profile)
        => Directory.TryGetValue(handle, out profile);

    static string Display(Profile profile)
        // ??  supplies a fallback when the left side is null
        => profile.Nickname ?? profile.Name;

    static void Main()
    {
        foreach (string handle in new[] { "imogen", "soren", "talia" })
        {
            if (TryFind(handle, out Profile? profile))
            {
                // Inside this branch the compiler knows `profile` is not null.
                Console.WriteLine($"{handle,-8} {Display(profile)}");
            }
            else
            {
                Console.WriteLine($"{handle,-8} not on file");
            }
        }

        Profile? maybe = null;

        // ?. stops at the first null instead of throwing.
        Console.WriteLine($"length: {maybe?.Name.Length?.ToString() ?? "unknown"}");

        // ??= assigns only when the target is null.
        maybe ??= new Profile { Name = "Placeholder" };
        Console.WriteLine(maybe.Name);

        try
        {
            Profile? missing = null;
            _ = missing!.Name; // ! silences the compiler, not the runtime
        }
        catch (NullReferenceException)
        {
            Console.WriteLine("the null-forgiving operator only quiets the warning");
        }
    }
}
