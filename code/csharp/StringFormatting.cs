// Interpolation, format specifiers, alignment, and StringBuilder.

using System;
using System.Globalization;
using System.Text;

class StringFormatting
{
    static void Main()
    {
        string station = "Alder Cross";
        int platforms = 2;
        decimal fare = 3.4m;
        var opened = new DateTime(1978, 4, 11);

        Console.WriteLine($"{station} has {platforms} platform{(platforms == 1 ? "" : "s")}");
        Console.WriteLine($"fare {fare:C} | {fare:F3} | {fare:P0}");
        Console.WriteLine($"opened {opened:yyyy-MM-dd} ({opened:MMMM yyyy})");
        Console.WriteLine($"padded |{station,20}| and |{station,-20}|");
        Console.WriteLine($"hex {255:X4}, binary {5:B8}, thousands {1234567:N0}");

        // A culture decides the separators and the currency symbol.
        var german = CultureInfo.GetCultureInfo("de-DE");
        Console.WriteLine(string.Format(german, "{0:N2} / {0:C}", 1234.5));

        // Raw string literals keep quotes and newlines as written.
        string json = """
            {
              "station": "Alder Cross",
              "zone": 2
            }
            """;
        Console.WriteLine(json);

        // StringBuilder avoids allocating a new string per concatenation.
        var builder = new StringBuilder();
        for (int zone = 1; zone <= 5; zone++)
        {
            builder.Append("zone ").Append(zone);
            if (zone < 5)
            {
                builder.Append(" -> ");
            }
        }
        Console.WriteLine(builder.ToString());

        Console.WriteLine(string.Join(" | ", "  amber , cobalt ,emerald ".Split(',',
            StringSplitOptions.TrimEntries)));
    }
}
