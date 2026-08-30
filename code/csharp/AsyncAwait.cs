// Running work concurrently with Task, and awaiting the results.

using System;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;

class AsyncAwait
{
    static async Task<int> FetchAsync(string name, int milliseconds)
    {
        Console.WriteLine($"start  {name}");
        await Task.Delay(milliseconds);
        Console.WriteLine($"finish {name}");
        return milliseconds;
    }

    static async Task Main()
    {
        var watch = Stopwatch.StartNew();

        // Sequential: each await blocks the next call from starting.
        int first = await FetchAsync("sequential-a", 150);
        int second = await FetchAsync("sequential-b", 150);
        Console.WriteLine($"sequential total {first + second} ms in {watch.ElapsedMilliseconds} ms\n");

        // Concurrent: both start, then both are awaited together.
        watch.Restart();
        var tasks = new[]
        {
            FetchAsync("concurrent-a", 150),
            FetchAsync("concurrent-b", 150),
            FetchAsync("concurrent-c", 100),
        };
        int[] results = await Task.WhenAll(tasks);
        Console.WriteLine($"concurrent total {results.Sum()} ms in {watch.ElapsedMilliseconds} ms");

        Task winner = await Task.WhenAny(Task.Delay(50), Task.Delay(500));
        Console.WriteLine($"first task finished: {winner.IsCompleted}");
    }
}
