// `yield return` builds a sequence lazily: nothing runs until it is walked,
// and only as far as the caller goes.

using System;
using System.Collections.Generic;
using System.Linq;

class IteratorYield
{
    static IEnumerable<long> Fibonacci()
    {
        long previous = 0;
        long current = 1;

        while (true)
        {
            yield return current;
            (previous, current) = (current, previous + current);
        }
    }

    static IEnumerable<int> Traced(IEnumerable<int> source, string label)
    {
        foreach (int value in source)
        {
            Console.WriteLine($"  {label} sees {value}");
            yield return value;
        }
    }

    static IEnumerable<string> ReadParagraphs(string text)
    {
        foreach (string block in text.Split("\n\n", StringSplitOptions.RemoveEmptyEntries))
        {
            yield return block.Replace('\n', ' ').Trim();
        }
    }

    static void Main()
    {
        Console.WriteLine(string.Join(", ", Fibonacci().Take(12)));

        Console.WriteLine("\nlazily, only three values are pulled through:");
        var pipeline = Traced(Enumerable.Range(1, 100), "source")
            .Where(value => value % 7 == 0)
            .Take(3);

        Console.WriteLine(string.Join(", ", pipeline));

        const string text = "First line\nsecond line\n\nA new paragraph\nwrapped over two lines";
        foreach (string paragraph in ReadParagraphs(text))
        {
            Console.WriteLine($"- {paragraph}");
        }
    }
}
