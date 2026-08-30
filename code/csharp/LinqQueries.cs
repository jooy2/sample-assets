// LINQ over an in-memory collection: filter, project, group, and aggregate.

using System;
using System.Collections.Generic;
using System.Linq;

record Station(string Name, string Line, int Zone, int Platforms, bool StepFree);

class LinqQueries
{
    static void Main()
    {
        var stations = new List<Station>
        {
            new("Alder Cross", "Amber", 2, 2, true),
            new("Quill Wharf", "Cobalt", 3, 4, false),
            new("Saltwick Halt", "Amber", 5, 1, true),
            new("Nether Gate", "Emerald", 2, 3, true),
            new("Bramble Fields", "Cobalt", 4, 2, false),
        };

        var accessibleInnerZones = stations
            .Where(station => station.StepFree && station.Zone <= 3)
            .OrderBy(station => station.Name)
            .Select(station => station.Name);

        Console.WriteLine("Step free, zone 3 or closer:");
        foreach (var name in accessibleInnerZones)
        {
            Console.WriteLine($"  {name}");
        }

        var byLine = stations
            .GroupBy(station => station.Line)
            .Select(group => new
            {
                Line = group.Key,
                Count = group.Count(),
                Platforms = group.Sum(station => station.Platforms),
            })
            .OrderByDescending(summary => summary.Platforms);

        Console.WriteLine("\nBy line:");
        foreach (var summary in byLine)
        {
            Console.WriteLine($"  {summary.Line,-8} {summary.Count} stations, {summary.Platforms} platforms");
        }

        Console.WriteLine($"\nAverage zone: {stations.Average(station => station.Zone):F2}");
        Console.WriteLine($"Deepest zone: {stations.Max(station => station.Zone)}");
        Console.WriteLine($"Any on Violet? {stations.Any(station => station.Line == "Violet")}");
    }
}
