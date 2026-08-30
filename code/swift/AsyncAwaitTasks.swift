// async/await, structured concurrency, and actors. Run with
// `swift AsyncAwaitTasks.swift`.

import Foundation

func fetch(_ name: String, milliseconds: UInt64) async throws -> String {
    try await Task.sleep(nanoseconds: milliseconds * 1_000_000)
    return "\(name) ready"
}

enum FetchError: Error {
    case upstreamGaveUp
}

func failing() async throws -> String {
    try await Task.sleep(nanoseconds: 20_000_000)
    throw FetchError.upstreamGaveUp
}

// An actor serialises access to its own state, so it cannot be raced.
actor Counter {
    private(set) var value = 0

    func increment(by amount: Int = 1) {
        value += amount
    }
}

func main() async throws {
    var started = Date()

    // Sequential: each await holds up the next call.
    _ = try await fetch("cached-report", milliseconds: 120)
    _ = try await fetch("full-export", milliseconds: 120)
    print("sequential took ~\(Int(Date().timeIntervalSince(started) * 1000)) ms")

    // async let starts the work immediately and awaits it later.
    started = Date()
    async let first = fetch("a", milliseconds: 120)
    async let second = fetch("b", milliseconds: 120)
    let both = try await [first, second]
    print("\(both) in ~\(Int(Date().timeIntervalSince(started) * 1000)) ms")

    // A task group handles a number of children only known at runtime.
    let limits = [50, 80, 30, 100]
    let results = try await withThrowingTaskGroup(of: String.self) { group in
        for (index, limit) in limits.enumerated() {
            group.addTask { try await fetch("job-\(index)", milliseconds: UInt64(limit)) }
        }
        var collected: [String] = []
        for try await result in group {
            collected.append(result)
        }
        return collected
    }
    print("task group returned \(results.count) results")

    // One failing child cancels its siblings.
    do {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { try await fetch("sibling", milliseconds: 500) }
            group.addTask { try await failing() }
            for try await _ in group {}
        }
    } catch {
        print("the group failed with: \(error)")
    }

    // An unstructured task runs on its own and can be cancelled.
    let task = Task { try await fetch("background", milliseconds: 500) }
    try await Task.sleep(nanoseconds: 30_000_000)
    task.cancel()
    do {
        _ = try await task.value
    } catch {
        print("cancelled: \(error is CancellationError || error is FetchError)")
    }

    // Actor state is safe to touch from many tasks at once.
    let counter = Counter()
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<100 {
            group.addTask { await counter.increment() }
        }
    }
    print("counter reached \(await counter.value)")

    // An AsyncSequence is consumed with `for await`.
    let stream = AsyncStream<Int> { continuation in
        Task {
            for value in 1...5 {
                try? await Task.sleep(nanoseconds: 10_000_000)
                continuation.yield(value)
            }
            continuation.finish()
        }
    }
    var seen: [Int] = []
    for await value in stream {
        seen.append(value)
    }
    print("stream produced \(seen)")
}

// Top-level code cannot be async, so the entry point runs in a task.
let semaphore = DispatchSemaphore(value: 0)
Task {
    try await main()
    semaphore.signal()
}
semaphore.wait()
