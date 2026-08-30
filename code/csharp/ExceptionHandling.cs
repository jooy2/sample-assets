// Throwing, catching, filtering, and wrapping exceptions.

using System;
using System.Collections.Generic;
using System.IO;

class ValidationException : Exception
{
    public string Field { get; }

    public ValidationException(string field, string message) : base(message) => Field = field;

    public ValidationException(string field, string message, Exception inner)
        : base(message, inner) => Field = field;
}

class ExceptionHandling
{
    static int ParseZone(string raw)
    {
        try
        {
            int zone = int.Parse(raw);
            if (zone is < 1 or > 6)
            {
                throw new ValidationException(nameof(zone), $"zone {zone} is outside 1-6");
            }
            return zone;
        }
        catch (FormatException error)
        {
            // Wrap the low-level failure in something the caller can act on.
            throw new ValidationException(nameof(zone), $"'{raw}' is not a number", error);
        }
    }

    static void Main()
    {
        foreach (string raw in new[] { "3", "9", "east", "5" })
        {
            try
            {
                Console.WriteLine($"{raw,-5} -> zone {ParseZone(raw)}");
            }
            catch (ValidationException error) when (error.InnerException is not null)
            {
                Console.WriteLine($"{raw,-5} -> {error.Message} (from {error.InnerException.GetType().Name})");
            }
            catch (ValidationException error)
            {
                Console.WriteLine($"{raw,-5} -> {error.Message}");
            }
        }

        // finally runs whether or not the try block succeeded.
        var opened = new List<string>();
        try
        {
            opened.Add("report.csv");
            throw new IOException("the disk went away");
        }
        catch (IOException error)
        {
            Console.WriteLine($"caught {error.Message}");
        }
        finally
        {
            opened.Clear();
            Console.WriteLine($"cleaned up, {opened.Count} handles left open");
        }
    }
}
