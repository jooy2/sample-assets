// Writing, reading, and streaming a text file asynchronously.

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

class FileIoAsync
{
    static async Task Main()
    {
        string path = Path.Combine(Path.GetTempPath(), "sample-assets-stations.csv");

        string[] lines =
        {
            "station,line,zone",
            "Alder Cross,Amber,2",
            "Quill Wharf,Cobalt,3",
            "Saltwick Halt,Amber,5",
            "Nether Gate,Emerald,2",
        };

        await File.WriteAllLinesAsync(path, lines);
        Console.WriteLine($"wrote {new FileInfo(path).Length} bytes to {path}");

        string whole = await File.ReadAllTextAsync(path);
        Console.WriteLine($"read back {whole.Split('\n', StringSplitOptions.RemoveEmptyEntries).Length} lines");

        // Streaming keeps only one line in memory at a time.
        var zones = new List<int>();
        using (var reader = new StreamReader(path))
        {
            await reader.ReadLineAsync(); // skip the header
            while (await reader.ReadLineAsync() is { } line)
            {
                zones.Add(int.Parse(line.Split(',')[2]));
            }
        }
        Console.WriteLine($"zones {string.Join(", ", zones)} (average {zones.Average():F2})");

        await foreach (string line in File.ReadLinesAsync(path).Take(2))
        {
            Console.WriteLine($"  {line}");
        }

        File.Delete(path);
        Console.WriteLine($"removed: {!File.Exists(path)}");
    }
}
