// Delegates hold methods; events let a class publish them without letting
// subscribers raise them.

using System;
using System.Collections.Generic;

class ReadingEventArgs : EventArgs
{
    public required string Device { get; init; }
    public required double Celsius { get; init; }
}

class Thermostat
{
    private double _celsius;

    public event EventHandler<ReadingEventArgs>? ReadingChanged;
    public event Action<string>? AlarmRaised;

    public double Celsius
    {
        get => _celsius;
        set
        {
            if (Math.Abs(value - _celsius) < 0.05)
            {
                return;
            }
            _celsius = value;
            ReadingChanged?.Invoke(this, new ReadingEventArgs { Device = "SNS-01", Celsius = value });

            if (value > 30)
            {
                AlarmRaised?.Invoke($"{value:F1}C is above the limit");
            }
        }
    }
}

class EventsAndDelegates
{
    static void Main()
    {
        var thermostat = new Thermostat();
        var log = new List<string>();

        void OnChanged(object? sender, ReadingEventArgs args)
            => log.Add($"{args.Device} now {args.Celsius:F1}C");

        thermostat.ReadingChanged += OnChanged;
        thermostat.AlarmRaised += message => Console.WriteLine($"ALARM {message}");

        thermostat.Celsius = 21.5;
        thermostat.Celsius = 21.5; // unchanged, so nothing is published
        thermostat.Celsius = 31.2;

        thermostat.ReadingChanged -= OnChanged;
        thermostat.Celsius = 18.0; // nobody is listening any more

        log.ForEach(Console.WriteLine);

        // A delegate is just a value, so it can be stored and combined.
        Func<int, int> twice = value => value * 2;
        Func<int, int> plusTen = value => value + 10;
        Console.WriteLine(twice(plusTen(5)));
    }
}
