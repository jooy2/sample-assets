// Extension methods add behaviour to a type you do not own.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;

static class StringExtensions
{
    public static string Truncate(this string text, int length, string ellipsis = "...")
        => text.Length <= length ? text : text[..Math.Max(0, length - ellipsis.Length)] + ellipsis;

    public static string ToKebabCase(this string text)
    {
        var builder = new StringBuilder();

        foreach (char character in text)
        {
            if (char.IsUpper(character) && builder.Length > 0)
            {
                builder.Append('-');
            }
            builder.Append(char.ToLower(character, CultureInfo.InvariantCulture));
        }
        return builder.ToString();
    }

    public static bool IsBlank(this string? text) => string.IsNullOrWhiteSpace(text);
}

static class EnumerableExtensions
{
    public static IEnumerable<IReadOnlyList<T>> Chunked<T>(this IEnumerable<T> source, int size)
    {
        var batch = new List<T>(size);

        foreach (T item in source)
        {
            batch.Add(item);
            if (batch.Count == size)
            {
                yield return batch;
                batch = new List<T>(size);
            }
        }
        if (batch.Count > 0)
        {
            yield return batch;
        }
    }
}

class ExtensionMethods
{
    static void Main()
    {
        Console.WriteLine("Stations on the Amber line".Truncate(18));
        Console.WriteLine("SensorReadingBatch".ToKebabCase());
        Console.WriteLine($"blank: {"   ".IsBlank()}, not blank: {"x".IsBlank()}");

        foreach (var chunk in Enumerable.Range(1, 10).Chunked(4))
        {
            Console.WriteLine(string.Join(", ", chunk));
        }
    }
}
