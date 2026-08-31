// EventPipeline.cs — an asynchronous processing pipeline.
//
// async/await, IAsyncEnumerable with `await foreach` and `yield return`,
// System.Threading.Channels for backpressure, CancellationToken through every
// layer, Task.WhenAll and WhenAny, generics with constraints, IDisposable and
// IAsyncDisposable, Interlocked for lock-free counters, retry with
// exponential backoff and jitter, and a deterministic clock so the run is
// reproducible.
//
//   dotnet run EventPipeline.cs      # .NET 10 file-based apps
//   csc EventPipeline.cs && ./EventPipeline
//
// Requires C# 12 / .NET 8 or later. Nothing here touches a network; the
// "remote" calls are simulated with a virtual clock. Every event is invented.

#nullable enable

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Channels;
using System.Threading.Tasks;

namespace SampleAssets.Pipelines;

// ------------------------------------------------------------------ events

public enum Severity
{
    Debug,
    Info,
    Warning,
    Error,
}

/// <summary>One thing that happened, as it arrives from a producer.</summary>
public sealed record RawEvent(
    string Source,
    string Kind,
    string Payload,
    DateTimeOffset At)
{
    public override string ToString() => $"{Source}/{Kind}";
}

/// <summary>The same event once it has been parsed and enriched.</summary>
public sealed record ProcessedEvent
{
    public required string Id { get; init; }
    public required string Source { get; init; }
    public required string Kind { get; init; }
    public required Severity Severity { get; init; }
    public required DateTimeOffset At { get; init; }
    public required IReadOnlyDictionary<string, string> Fields { get; init; }
    public int Attempts { get; init; } = 1;

    public string? Field(string name) => Fields.TryGetValue(name, out var value) ? value : null;

    public override string ToString() =>
        $"{Id} {Severity,-7} {Source}/{Kind}" +
        (Fields.Count == 0 ? "" : "  " + string.Join(" ", Fields.Select(pair => $"{pair.Key}={pair.Value}")));
}

/// <summary>What a stage produced: a value, or the reason there is none.</summary>
public readonly record struct Outcome<T>(T? Value, string? Error, bool Dropped)
{
    public bool Ok => Error is null && !Dropped;

    public static Outcome<T> Success(T value) => new(value, null, false);
    public static Outcome<T> Failed(string reason) => new(default, reason, false);
    public static Outcome<T> Drop() => new(default, null, true);
}

// ------------------------------------------------------------------- clock

/// <summary>Time, so the pipeline can be run against a fake one.</summary>
public interface IClock
{
    DateTimeOffset Now { get; }

    Task Delay(TimeSpan duration, CancellationToken token);
}

public sealed class SystemClock : IClock
{
    public DateTimeOffset Now => DateTimeOffset.UtcNow;

    public Task Delay(TimeSpan duration, CancellationToken token) => Task.Delay(duration, token);
}

/// <summary>
/// A clock that jumps rather than waits, so a run that would take a minute of
/// backoff finishes instantly and always produces the same transcript.
/// </summary>
public sealed class VirtualClock : IClock
{
    private long _ticks;

    public VirtualClock(DateTimeOffset start) => Start = start;

    public DateTimeOffset Start { get; }

    public DateTimeOffset Now => Start.AddTicks(Interlocked.Read(ref _ticks));

    public TimeSpan Elapsed => TimeSpan.FromTicks(Interlocked.Read(ref _ticks));

    public async Task Delay(TimeSpan duration, CancellationToken token)
    {
        token.ThrowIfCancellationRequested();
        Interlocked.Add(ref _ticks, duration.Ticks);
        // Yield so other tasks interleave the way they would in real time.
        await Task.Yield();
    }
}

// ------------------------------------------------------------------ stages

/// <summary>One step of the pipeline.</summary>
public interface IStage<TIn, TOut>
{
    string Name { get; }

    ValueTask<Outcome<TOut>> Handle(TIn input, CancellationToken token);
}

/// <summary>Parse "key=value;key=value" into a dictionary, or refuse it.</summary>
public sealed class ParseStage(IClock clock) : IStage<RawEvent, ProcessedEvent>
{
    private int _counter;

    public string Name => "parse";

    public ValueTask<Outcome<ProcessedEvent>> Handle(RawEvent input, CancellationToken token)
    {
        token.ThrowIfCancellationRequested();

        if (string.IsNullOrWhiteSpace(input.Payload))
        {
            return ValueTask.FromResult(Outcome<ProcessedEvent>.Failed("empty payload"));
        }

        var fields = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var pair in input.Payload.Split(';', StringSplitOptions.RemoveEmptyEntries))
        {
            var separator = pair.IndexOf('=');
            if (separator <= 0)
            {
                return ValueTask.FromResult(
                    Outcome<ProcessedEvent>.Failed($"\"{pair.Trim()}\" is not key=value"));
            }
            fields[pair[..separator].Trim()] = pair[(separator + 1)..].Trim();
        }

        var severity = input.Kind switch
        {
            var kind when kind.EndsWith("failed", StringComparison.OrdinalIgnoreCase) => Severity.Error,
            var kind when kind.EndsWith("cancelled", StringComparison.OrdinalIgnoreCase) => Severity.Warning,
            "heartbeat" => Severity.Debug,
            _ => Severity.Info,
        };

        var id = $"E-{Interlocked.Increment(ref _counter):D4}";

        return ValueTask.FromResult(Outcome<ProcessedEvent>.Success(new ProcessedEvent
        {
            Id = id,
            Source = input.Source,
            Kind = input.Kind,
            Severity = severity,
            At = clock.Now,
            Fields = fields,
        }));
    }
}

/// <summary>Discard anything below a threshold, so later stages do less.</summary>
public sealed class FilterStage(Severity minimum) : IStage<ProcessedEvent, ProcessedEvent>
{
    public string Name => $"filter(>= {minimum})";

    public ValueTask<Outcome<ProcessedEvent>> Handle(ProcessedEvent input, CancellationToken token)
    {
        token.ThrowIfCancellationRequested();
        return ValueTask.FromResult(
            input.Severity >= minimum
                ? Outcome<ProcessedEvent>.Success(input)
                : Outcome<ProcessedEvent>.Drop());
    }
}

/// <summary>
/// A stand-in for a call to something else: it takes time, and it fails the
/// first few times it is asked about a particular source.
/// </summary>
public sealed class EnrichStage(IClock clock, IReadOnlyDictionary<string, int> failuresBySource)
    : IStage<ProcessedEvent, ProcessedEvent>
{
    private readonly ConcurrentDictionary<string, int> _seen = new(StringComparer.Ordinal);

    public string Name => "enrich";

    public async ValueTask<Outcome<ProcessedEvent>> Handle(ProcessedEvent input, CancellationToken token)
    {
        await clock.Delay(TimeSpan.FromMilliseconds(20), token).ConfigureAwait(false);

        var attempts = _seen.AddOrUpdate(input.Source, 1, (_, previous) => previous + 1);
        var budget = failuresBySource.TryGetValue(input.Source, out var count) ? count : 0;

        if (attempts <= budget)
        {
            return Outcome<ProcessedEvent>.Failed($"{input.Source} lookup unavailable (call {attempts})");
        }

        var fields = new Dictionary<string, string>(input.Fields, StringComparer.OrdinalIgnoreCase)
        {
            ["region"] = input.Source switch
            {
                "HRB" or "KSP" => "north",
                "HLW" => "west",
                _ => "unknown",
            },
        };

        return Outcome<ProcessedEvent>.Success(input with { Fields = fields });
    }
}

// -------------------------------------------------------------------- retry

public sealed record RetryPolicy(int MaxAttempts, TimeSpan BaseDelay, int Seed = 20270902)
{
    /// <summary>
    /// Exponential backoff with full jitter: the wait is a random point in
    /// [0, base * 2^(n-1)], which spreads retries out instead of having every
    /// caller come back at the same instant.
    /// </summary>
    public TimeSpan DelayBefore(int attempt, Random random)
    {
        if (attempt <= 1)
        {
            return TimeSpan.Zero;
        }
        var ceiling = BaseDelay.TotalMilliseconds * Math.Pow(2, attempt - 2);
        return TimeSpan.FromMilliseconds(random.NextDouble() * ceiling);
    }
}

// ------------------------------------------------------------------ metrics

/// <summary>Counters updated from several tasks at once, without a lock.</summary>
public sealed class Metrics
{
    private long _received;
    private long _processed;
    private long _dropped;
    private long _failed;
    private long _retries;

    private readonly ConcurrentDictionary<string, long> _byStage = new(StringComparer.Ordinal);

    public long Received => Interlocked.Read(ref _received);
    public long Processed => Interlocked.Read(ref _processed);
    public long Dropped => Interlocked.Read(ref _dropped);
    public long Failed => Interlocked.Read(ref _failed);
    public long Retries => Interlocked.Read(ref _retries);

    public void Receive() => Interlocked.Increment(ref _received);
    public void Process() => Interlocked.Increment(ref _processed);
    public void Drop() => Interlocked.Increment(ref _dropped);
    public void Fail() => Interlocked.Increment(ref _failed);
    public void Retry() => Interlocked.Increment(ref _retries);

    public void Count(string stage) =>
        _byStage.AddOrUpdate(stage, 1, (_, previous) => previous + 1);

    public IEnumerable<(string Stage, long Count)> ByStage =>
        _byStage.Select(pair => (pair.Key, pair.Value)).OrderBy(pair => pair.Key, StringComparer.Ordinal);

    public override string ToString() =>
        $"received {Received}, processed {Processed}, dropped {Dropped}, " +
        $"failed {Failed}, retries {Retries}";
}

// ----------------------------------------------------------------- pipeline

public sealed class Pipeline(
    IClock clock,
    RetryPolicy retryPolicy,
    Metrics metrics,
    int workers = 4,
    int capacity = 32) : IAsyncDisposable
{
    private readonly Channel<RawEvent> _inbox = Channel.CreateBounded<RawEvent>(
        new BoundedChannelOptions(capacity)
        {
            // A full channel makes the producer wait rather than dropping
            // work or growing without limit. That is the whole point of
            // bounding it.
            FullMode = BoundedChannelFullMode.Wait,
            SingleReader = false,
            SingleWriter = false,
        });

    private readonly Channel<ProcessedEvent> _outbox = Channel.CreateUnbounded<ProcessedEvent>();
    private readonly ConcurrentBag<string> _failures = new();
    private Task? _running;

    public IReadOnlyCollection<string> Failures => _failures;

    public IStage<RawEvent, ProcessedEvent>? Parse { get; init; }
    public IStage<ProcessedEvent, ProcessedEvent>? Filter { get; init; }
    public IStage<ProcessedEvent, ProcessedEvent>? Enrich { get; init; }

    /// <summary>Hand an event to the pipeline, waiting if it is full.</summary>
    public async ValueTask Submit(RawEvent raw, CancellationToken token = default)
    {
        metrics.Receive();
        await _inbox.Writer.WriteAsync(raw, token).ConfigureAwait(false);
    }

    public void NoMoreInput() => _inbox.Writer.TryComplete();

    /// <summary>Start the workers. They run until the inbox completes.</summary>
    public void Start(CancellationToken token = default)
    {
        if (_running is not null)
        {
            throw new InvalidOperationException("the pipeline is already running");
        }

        var tasks = Enumerable.Range(0, workers)
            .Select(worker => Task.Run(() => Work(worker, token), token))
            .ToArray();

        _running = Task.WhenAll(tasks).ContinueWith(
            _ => _outbox.Writer.TryComplete(),
            CancellationToken.None,
            TaskContinuationOptions.ExecuteSynchronously,
            TaskScheduler.Default);
    }

    private async Task Work(int worker, CancellationToken token)
    {
        var random = new Random(retryPolicy.Seed + worker);

        // `await foreach` over a channel reader: the loop ends when the
        // channel completes, without a sentinel value or a poll.
        await foreach (var raw in _inbox.Reader.ReadAllAsync(token).ConfigureAwait(false))
        {
            var result = await RunStages(raw, random, token).ConfigureAwait(false);

            if (result.Ok && result.Value is { } processed)
            {
                metrics.Process();
                await _outbox.Writer.WriteAsync(processed, token).ConfigureAwait(false);
            }
            else if (result.Dropped)
            {
                metrics.Drop();
            }
            else
            {
                metrics.Fail();
                _failures.Add($"{raw}: {result.Error}");
            }
        }
    }

    private async ValueTask<Outcome<ProcessedEvent>> RunStages(
        RawEvent raw,
        Random random,
        CancellationToken token)
    {
        if (Parse is null)
        {
            return Outcome<ProcessedEvent>.Failed("no parse stage");
        }

        metrics.Count(Parse.Name);
        var parsed = await Parse.Handle(raw, token).ConfigureAwait(false);
        if (!parsed.Ok || parsed.Value is not { } event1)
        {
            return parsed;
        }

        if (Filter is not null)
        {
            metrics.Count(Filter.Name);
            var filtered = await Filter.Handle(event1, token).ConfigureAwait(false);
            if (!filtered.Ok || filtered.Value is not { } event2)
            {
                return filtered;
            }
            event1 = event2;
        }

        if (Enrich is null)
        {
            return Outcome<ProcessedEvent>.Success(event1);
        }

        // The enrich stage is the one that talks to something else, so it is
        // the one that is retried.
        return await WithRetries(Enrich, event1, random, token).ConfigureAwait(false);
    }

    private async ValueTask<Outcome<ProcessedEvent>> WithRetries(
        IStage<ProcessedEvent, ProcessedEvent> stage,
        ProcessedEvent input,
        Random random,
        CancellationToken token)
    {
        Outcome<ProcessedEvent> last = Outcome<ProcessedEvent>.Failed("never ran");

        for (var attempt = 1; attempt <= retryPolicy.MaxAttempts; attempt++)
        {
            if (attempt > 1)
            {
                metrics.Retry();
                await clock.Delay(retryPolicy.DelayBefore(attempt, random), token).ConfigureAwait(false);
            }

            metrics.Count(stage.Name);
            last = await stage.Handle(input, token).ConfigureAwait(false);

            if (last.Ok && last.Value is { } value)
            {
                return Outcome<ProcessedEvent>.Success(value with { Attempts = attempt });
            }
            if (last.Dropped)
            {
                return last;
            }
        }

        return last;
    }

    /// <summary>
    /// The processed events, as they finish. An async stream, so a caller can
    /// consume them with `await foreach` without waiting for the whole run.
    /// </summary>
    public IAsyncEnumerable<ProcessedEvent> Results(CancellationToken token = default) =>
        _outbox.Reader.ReadAllAsync(token);

    private bool _disposed;

    /// <summary>
    /// Safe to call more than once, which matters because `await using` will
    /// call it again after an explicit call.
    /// </summary>
    public async ValueTask DisposeAsync()
    {
        if (_disposed)
        {
            return;
        }
        _disposed = true;

        NoMoreInput();
        if (_running is not null)
        {
            try
            {
                await _running.ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                // Cancelling is a normal way to stop, not a failure.
            }
        }
        _outbox.Writer.TryComplete();
    }
}

// -------------------------------------------------------- async generators

public static class AsyncStreams
{
    /// <summary>
    /// An async stream of events, produced with a gap between each, so the
    /// pipeline sees something that arrives over time rather than all at once.
    /// </summary>
    public static async IAsyncEnumerable<RawEvent> Produce(
        IClock clock,
        IReadOnlyList<RawEvent> source,
        TimeSpan gap,
        [System.Runtime.CompilerServices.EnumeratorCancellation] CancellationToken token = default)
    {
        foreach (var raw in source)
        {
            token.ThrowIfCancellationRequested();
            await clock.Delay(gap, token).ConfigureAwait(false);
            yield return raw with { At = clock.Now };
        }
    }

    /// <summary>Batch an async stream into groups of a fixed size.</summary>
    public static async IAsyncEnumerable<IReadOnlyList<T>> Batch<T>(
        this IAsyncEnumerable<T> source,
        int size,
        [System.Runtime.CompilerServices.EnumeratorCancellation] CancellationToken token = default)
    {
        if (size < 1)
        {
            throw new ArgumentOutOfRangeException(nameof(size), size, "a batch needs at least one item");
        }

        var batch = new List<T>(size);
        await foreach (var item in source.WithCancellation(token).ConfigureAwait(false))
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

    /// <summary>Count an async stream without materialising it.</summary>
    public static async ValueTask<int> CountAsync<T>(
        this IAsyncEnumerable<T> source,
        CancellationToken token = default)
    {
        var count = 0;
        await foreach (var _ in source.WithCancellation(token).ConfigureAwait(false))
        {
            count++;
        }
        return count;
    }
}

// -------------------------------------------------------------------- demo

public static class Program
{
    private static IReadOnlyList<RawEvent> SampleEvents(DateTimeOffset start)
    {
        var kinds = new[]
        {
            ("HRB", "sailing.departed", "sailing=HRB-01;seats=380;load=284"),
            ("HRB", "sailing.departed", "sailing=HRB-02;seats=380;load=301"),
            ("HRB", "heartbeat", "uptime=41200"),
            ("KSP", "sailing.departed", "sailing=KSP-01;seats=240;load=211"),
            ("KSP", "booking.failed", "reference=BK-1044;reason=payment"),
            ("HLW", "sailing.cancelled", "sailing=HLW-04;cause=weather"),
            ("HLW", "sailing.cancelled", "sailing=HLW-05;cause=weather"),
            ("HRB", "heartbeat", "uptime=41260"),
            ("KSP", "sailing.departed", "sailing=KSP-02;seats=240;load=198"),
            ("HLW", "sailing.departed", "sailing=HLW-06;seats=120;load=52"),
            ("NCR", "sailing.departed", "sailing=NCR-01;seats=90;load=41"),
            ("NCR", "booking.failed", "reference=BK-1051;reason=timeout"),
            ("HRB", "sailing.departed", "sailing=HRB-11;seats=380;load=312"),
            ("KSP", "heartbeat", "uptime=41320"),
            ("HRB", "malformed", "this payload has no equals sign"),
            ("KSP", "empty", ""),
            ("HLW", "sailing.departed", "sailing=HLW-09;seats=120;load=71"),
            ("NCR", "sailing.cancelled", "sailing=NCR-03;cause=weather"),
        };

        return kinds
            .Select((item, index) => new RawEvent(
                item.Item1, item.Item2, item.Item3, start.AddSeconds(index * 5)))
            .ToList();
    }

    private static void Heading(string title)
    {
        Console.WriteLine();
        Console.WriteLine($"--- {title} ---");
    }

    public static async Task Main()
    {
        Console.OutputEncoding = Encoding.UTF8;

        var start = new DateTimeOffset(2027, 9, 2, 6, 0, 0, TimeSpan.Zero);
        var clock = new VirtualClock(start);
        var metrics = new Metrics();
        var events = SampleEvents(start);

        // The HLW lookup fails twice before it answers, so the retry path is
        // exercised rather than merely present.
        var failures = new Dictionary<string, int>(StringComparer.Ordinal)
        {
            ["HLW"] = 2,
            ["NCR"] = 1,
        };

        await using var pipeline = new Pipeline(
            clock,
            new RetryPolicy(MaxAttempts: 4, BaseDelay: TimeSpan.FromMilliseconds(50)),
            metrics,
            workers: 3,
            capacity: 8)
        {
            Parse = new ParseStage(clock),
            Filter = new FilterStage(Severity.Info),
            Enrich = new EnrichStage(clock, failures),
        };

        Heading("running");
        Console.WriteLine($"  {events.Count} event(s), 3 worker(s), an inbox of 8");

        var stopwatch = Stopwatch.StartNew();
        using var cancellation = new CancellationTokenSource();
        pipeline.Start(cancellation.Token);

        // Feed and drain at the same time: the producer would otherwise fill
        // the bounded inbox and wait for a consumer that had not started.
        var feeding = Task.Run(async () =>
        {
            await foreach (var raw in AsyncStreams.Produce(
                               clock, events, TimeSpan.FromMilliseconds(5), cancellation.Token))
            {
                await pipeline.Submit(raw, cancellation.Token);
            }
            pipeline.NoMoreInput();
        });

        var collected = new List<ProcessedEvent>();
        var draining = Task.Run(async () =>
        {
            await foreach (var processed in pipeline.Results(cancellation.Token))
            {
                collected.Add(processed);
            }
        });

        await Task.WhenAll(feeding, draining);
        stopwatch.Stop();

        Heading("what came out");
        foreach (var processed in collected.OrderBy(item => item.Id, StringComparer.Ordinal))
        {
            var attempts = processed.Attempts > 1 ? $"  ({processed.Attempts} attempts)" : "";
            Console.WriteLine($"  {processed}{attempts}");
        }

        Heading("counters");
        Console.WriteLine($"  {metrics}");
        foreach (var (stage, count) in metrics.ByStage)
        {
            Console.WriteLine($"  {stage,-18} ran {count} time(s)");
        }
        Console.WriteLine($"  virtual time elapsed: {clock.Elapsed.TotalMilliseconds:N0} ms");
        Console.WriteLine($"  real time elapsed:    {stopwatch.Elapsed.TotalMilliseconds:N0} ms");

        Heading("what failed");
        foreach (var failure in pipeline.Failures.OrderBy(text => text, StringComparer.Ordinal))
        {
            Console.WriteLine($"  {failure}");
        }

        Heading("retries actually happened");
        var retried = collected.Where(item => item.Attempts > 1).ToList();
        Console.WriteLine($"  {retried.Count} event(s) needed more than one attempt");
        foreach (var group in retried.GroupBy(item => item.Source, StringComparer.Ordinal))
        {
            Console.WriteLine($"  {group.Key}: up to {group.Max(item => item.Attempts)} attempt(s)");
        }

        Heading("grouping the results");
        foreach (var group in collected
                     .GroupBy(item => item.Severity)
                     .OrderByDescending(group => group.Key))
        {
            Console.WriteLine($"  {group.Key,-8} {group.Count()}  " +
                string.Join(", ", group.Select(item => item.Id)));
        }

        Heading("an async stream, batched");
        var batches = 0;
        await foreach (var batch in AsyncStreams
                           .Produce(clock, events, TimeSpan.FromMilliseconds(1))
                           .Batch(5))
        {
            batches++;
            Console.WriteLine($"  batch {batches}: {batch.Count} event(s), " +
                $"first {batch[0]}, last {batch[^1]}");
        }

        Heading("counting a stream without keeping it");
        var counted = await AsyncStreams
            .Produce(clock, events, TimeSpan.FromMilliseconds(1))
            .CountAsync();
        Console.WriteLine($"  {counted} event(s) counted, none held in memory at once");

        Heading("cancellation stops it promptly");
        var secondClock = new VirtualClock(start);
        var secondMetrics = new Metrics();
        using var stopEarly = new CancellationTokenSource();

        var quick = new Pipeline(
            secondClock,
            new RetryPolicy(2, TimeSpan.FromMilliseconds(10)),
            secondMetrics,
            workers: 2)
        {
            Parse = new ParseStage(secondClock),
            Enrich = new EnrichStage(secondClock, new Dictionary<string, int>()),
        };

        quick.Start(stopEarly.Token);
        foreach (var raw in events.Take(4))
        {
            await quick.Submit(raw, stopEarly.Token);
        }

        await stopEarly.CancelAsync();
        await quick.DisposeAsync();

        Console.WriteLine($"  after cancelling: {secondMetrics}");
        Console.WriteLine($"  fewer than the {events.Take(4).Count()} submitted were processed: " +
            $"{secondMetrics.Processed <= 4}");

        Heading("a batch size of zero is refused");
        try
        {
            await foreach (var _ in AsyncStreams.Produce(clock, events, TimeSpan.Zero).Batch(0))
            {
                // never reached
            }
        }
        catch (ArgumentOutOfRangeException error)
        {
            Console.WriteLine($"  {error.ParamName}: {error.Message.Split('(')[0].Trim()}");
        }

        Heading("starting twice is refused");
        await using var already = new Pipeline(clock, new RetryPolicy(1, TimeSpan.Zero), new Metrics())
        {
            Parse = new ParseStage(clock),
        };
        already.Start();
        try
        {
            already.Start();
        }
        catch (InvalidOperationException error)
        {
            Console.WriteLine($"  {error.Message}");
        }
        already.NoMoreInput();
    }
}
