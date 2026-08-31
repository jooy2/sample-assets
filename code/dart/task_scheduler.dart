// task_scheduler.dart — an asynchronous job runner.
//
// Priority queueing, bounded concurrency, retries with exponential backoff and
// jitter, per-task timeouts, cancellation, dependencies between tasks, a
// progress stream, and a circuit breaker that stops hammering a failing
// resource.
//
//   dart run task_scheduler.dart
//
// Everything is deterministic: the clock is injected and the "random" jitter
// comes from a seeded generator, so two runs produce the same transcript.
//
// One file, dart:core and dart:async only.

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

// -------------------------------------------------------------------- model

enum Priority { low, normal, high, urgent }

enum TaskState { queued, running, succeeded, failed, cancelled, skipped }

/// What happened to one attempt at running a task.
class Attempt {
  final int number;
  final Duration waitedBefore;
  final Object? error;
  final Duration took;

  const Attempt({
    required this.number,
    required this.waitedBefore,
    required this.took,
    this.error,
  });

  bool get succeeded => error == null;
}

/// A unit of work, plus everything the scheduler needs to know about running
/// it: how important it is, what it depends on, and how hard to try.
class Task<T> {
  final String id;
  final Priority priority;
  final Set<String> dependsOn;
  final int maxAttempts;
  final Duration timeout;
  final Duration baseBackoff;
  final Future<T> Function(TaskContext context) run;

  Task({
    required this.id,
    required this.run,
    this.priority = Priority.normal,
    this.dependsOn = const {},
    this.maxAttempts = 1,
    this.timeout = const Duration(seconds: 30),
    this.baseBackoff = const Duration(milliseconds: 100),
  }) {
    if (maxAttempts < 1) {
      throw ArgumentError.value(maxAttempts, 'maxAttempts', 'must be at least 1');
    }
    if (dependsOn.contains(id)) {
      throw ArgumentError('task "$id" cannot depend on itself');
    }
  }
}

/// Handed to a running task: lets it check for cancellation and read the
/// results of the tasks it depended on.
class TaskContext {
  final String taskId;
  final int attempt;
  final Map<String, Object?> results;
  final Future<void> cancelled;

  bool _cancelled = false;

  TaskContext({
    required this.taskId,
    required this.attempt,
    required this.results,
    required this.cancelled,
  }) {
    cancelled.then((_) => _cancelled = true).ignore();
  }

  bool get isCancelled => _cancelled;

  /// Throws if the job has been cancelled. A long task should call this
  /// between steps; nothing can interrupt a task that never yields.
  void throwIfCancelled() {
    if (_cancelled) throw const TaskCancelled();
  }
}

class TaskCancelled implements Exception {
  const TaskCancelled();
  @override
  String toString() => 'cancelled';
}

class DependencyFailed implements Exception {
  final String dependency;
  const DependencyFailed(this.dependency);
  @override
  String toString() => 'dependency "$dependency" did not succeed';
}

class CircuitOpen implements Exception {
  final String resource;
  const CircuitOpen(this.resource);
  @override
  String toString() => 'circuit open for "$resource"';
}

/// The outcome of one task.
class TaskResult<T> {
  final String id;
  final TaskState state;
  final T? value;
  final Object? error;
  final List<Attempt> attempts;

  const TaskResult({
    required this.id,
    required this.state,
    required this.attempts,
    this.value,
    this.error,
  });

  bool get succeeded => state == TaskState.succeeded;

  @override
  String toString() {
    final tries = attempts.length;
    final suffix = tries > 1 ? ' after $tries attempts' : '';
    return switch (state) {
      TaskState.succeeded => '$id: ok$suffix -> $value',
      TaskState.failed => '$id: failed$suffix -- $error',
      TaskState.cancelled => '$id: cancelled',
      TaskState.skipped => '$id: skipped -- $error',
      _ => '$id: $state',
    };
  }
}

/// Emitted on the scheduler's progress stream.
class Progress {
  final String taskId;
  final TaskState state;
  final int done;
  final int total;
  final String? note;

  const Progress(this.taskId, this.state, this.done, this.total, [this.note]);

  double get fraction => total == 0 ? 1 : done / total;

  @override
  String toString() {
    final percent = (fraction * 100).toStringAsFixed(0).padLeft(3);
    final label = state.name.padRight(9);
    return '[$percent%] $label $taskId${note == null ? '' : '  ($note)'}';
  }
}

// --------------------------------------------------------- circuit breaker

/// Stops calling a resource that keeps failing, and lets one probe through
/// after a cooling-off period.
class CircuitBreaker {
  final String resource;
  final int threshold;
  final Duration cooldown;
  final Duration Function() _now;

  int _consecutiveFailures = 0;
  Duration? _openedAt;

  CircuitBreaker({
    required this.resource,
    required Duration Function() now,
    this.threshold = 3,
    this.cooldown = const Duration(seconds: 5),
  }) : _now = now;

  bool get isOpen {
    if (_openedAt == null) return false;
    if (_now() - _openedAt! >= cooldown) {
      // Half-open: let exactly one call through to see whether it recovered.
      _openedAt = null;
      _consecutiveFailures = threshold - 1;
      return false;
    }
    return true;
  }

  void recordSuccess() {
    _consecutiveFailures = 0;
    _openedAt = null;
  }

  void recordFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= threshold) _openedAt = _now();
  }

  @override
  String toString() =>
      'breaker($resource, failures=$_consecutiveFailures, open=$isOpen)';
}

// ------------------------------------------------------------------- clock

/// A clock the scheduler can fast-forward, so tests and demonstrations do not
/// actually wait five seconds for a backoff.
class VirtualClock {
  Duration _elapsed = Duration.zero;

  Duration get elapsed => _elapsed;

  Duration now() => _elapsed;

  Future<void> sleep(Duration duration) async {
    _elapsed += duration;
    // Yield to the event loop so other tasks interleave realistically.
    await Future<void>.delayed(Duration.zero);
  }

  String stamp() {
    final ms = _elapsed.inMilliseconds;
    return '${(ms / 1000).toStringAsFixed(3).padLeft(7)}s';
  }
}

// --------------------------------------------------------------- scheduler

class Scheduler {
  final int concurrency;
  final VirtualClock clock;
  final math.Random _random;
  final Map<String, CircuitBreaker> _breakers = {};

  final _progress = StreamController<Progress>.broadcast();

  Scheduler({this.concurrency = 3, VirtualClock? clock, int seed = 20270902})
      : clock = clock ?? VirtualClock(),
        _random = math.Random(seed) {
    if (concurrency < 1) {
      throw ArgumentError.value(concurrency, 'concurrency', 'must be at least 1');
    }
  }

  Stream<Progress> get progress => _progress.stream;

  CircuitBreaker breakerFor(String resource) => _breakers.putIfAbsent(
      resource,
      () => CircuitBreaker(resource: resource, now: clock.now));

  Future<void> close() => _progress.close();

  /// Run every task, honouring dependencies and the concurrency limit.
  ///
  /// Returns one result per task, in the order the tasks were given.
  Future<Map<String, TaskResult<Object?>>> runAll(
    List<Task<Object?>> tasks, {
    Future<void>? cancel,
  }) async {
    _checkForCycles(tasks);

    final results = <String, TaskResult<Object?>>{};
    final values = <String, Object?>{};
    final completed = <String>{};
    var done = 0;

    final cancelSignal = cancel ?? Completer<void>().future;
    var cancelled = false;
    unawaited(cancelSignal.then((_) => cancelled = true));

    // Highest priority first; ties broken by the order they were submitted so
    // that a run is reproducible.
    final submissionOrder = {
      for (var i = 0; i < tasks.length; i++) tasks[i].id: i
    };
    final pending = SplayTreeSet<Task<Object?>>((a, b) {
      final byPriority = b.priority.index.compareTo(a.priority.index);
      if (byPriority != 0) return byPriority;
      return submissionOrder[a.id]!.compareTo(submissionOrder[b.id]!);
    })
      ..addAll(tasks);

    final running = <String, Future<void>>{};

    void emit(String id, TaskState state, [String? note]) {
      if (!_progress.isClosed) {
        _progress.add(Progress(id, state, done, tasks.length, note));
      }
    }

    while (pending.isNotEmpty || running.isNotEmpty) {
      // Start whatever is ready and fits under the concurrency limit.
      final ready = pending
          .where((task) => task.dependsOn.every(completed.contains))
          .take(concurrency - running.length)
          .toList();

      for (final task in ready) {
        pending.remove(task);

        final failedDependency = task.dependsOn.firstWhere(
          (id) => results[id] != null && !results[id]!.succeeded,
          orElse: () => '',
        );
        if (failedDependency.isNotEmpty) {
          results[task.id] = TaskResult<Object?>(
            id: task.id,
            state: TaskState.skipped,
            attempts: const [],
            error: DependencyFailed(failedDependency),
          );
          completed.add(task.id);
          done++;
          emit(task.id, TaskState.skipped, 'needs $failedDependency');
          continue;
        }

        if (cancelled) {
          results[task.id] = TaskResult<Object?>(
            id: task.id, state: TaskState.cancelled, attempts: const []);
          completed.add(task.id);
          done++;
          emit(task.id, TaskState.cancelled);
          continue;
        }

        emit(task.id, TaskState.running);
        running[task.id] = _runOne(task, values, cancelSignal).then((result) {
          results[task.id] = result;
          if (result.succeeded) values[task.id] = result.value;
          completed.add(task.id);
          running.remove(task.id);
          done++;
          emit(task.id, result.state,
              result.attempts.length > 1
                  ? '${result.attempts.length} attempts'
                  : null);
        });
      }

      if (running.isEmpty && pending.isNotEmpty && ready.isEmpty) {
        // Nothing can start: the remaining tasks depend on something that
        // will never complete.
        for (final task in pending.toList()) {
          results[task.id] = TaskResult<Object?>(
            id: task.id,
            state: TaskState.skipped,
            attempts: const [],
            error: DependencyFailed(task.dependsOn.firstWhere(
                (id) => !completed.contains(id),
                orElse: () => '?')),
          );
          done++;
          emit(task.id, TaskState.skipped, 'blocked');
        }
        pending.clear();
        break;
      }

      if (running.isNotEmpty) await Future.any(running.values);
    }

    return {for (final task in tasks) task.id: results[task.id]!};
  }

  Future<TaskResult<Object?>> _runOne(
    Task<Object?> task,
    Map<String, Object?> values,
    Future<void> cancelSignal,
  ) async {
    final attempts = <Attempt>[];
    final breaker = breakerFor(task.id.split(':').first);

    for (var attempt = 1; attempt <= task.maxAttempts; attempt++) {
      var waited = Duration.zero;

      if (attempt > 1) {
        // Exponential backoff with full jitter: the wait is a random point in
        // [0, base * 2^(n-1)], which spreads retries out instead of having
        // every caller come back at the same instant.
        final ceiling = task.baseBackoff * math.pow(2, attempt - 2).toDouble();
        waited = Duration(
            microseconds: _random.nextInt(ceiling.inMicroseconds.clamp(1, 1 << 30)));
        await clock.sleep(waited);
      }

      if (breaker.isOpen) {
        attempts.add(Attempt(
            number: attempt,
            waitedBefore: waited,
            took: Duration.zero,
            error: CircuitOpen(breaker.resource)));
        break;
      }

      final started = clock.now();
      final context = TaskContext(
        taskId: task.id,
        attempt: attempt,
        results: Map.unmodifiable(values),
        cancelled: cancelSignal,
      );

      try {
        final value = await task.run(context).timeout(task.timeout);
        breaker.recordSuccess();
        attempts.add(Attempt(
            number: attempt, waitedBefore: waited, took: clock.now() - started));
        return TaskResult<Object?>(
            id: task.id,
            state: TaskState.succeeded,
            value: value,
            attempts: attempts);
      } on TaskCancelled {
        return TaskResult<Object?>(
            id: task.id, state: TaskState.cancelled, attempts: attempts);
      } catch (error) {
        breaker.recordFailure();
        attempts.add(Attempt(
            number: attempt,
            waitedBefore: waited,
            took: clock.now() - started,
            error: error));
      }
    }

    return TaskResult<Object?>(
      id: task.id,
      state: TaskState.failed,
      error: attempts.isEmpty ? 'never ran' : attempts.last.error,
      attempts: attempts,
    );
  }

  /// Depth-first search for a dependency cycle, reported by name.
  void _checkForCycles(List<Task<Object?>> tasks) {
    final byId = {for (final task in tasks) task.id: task};
    final visiting = <String>{};
    final done = <String>{};
    final path = <String>[];

    void visit(String id) {
      if (done.contains(id)) return;
      if (!visiting.add(id)) {
        final start = path.indexOf(id);
        throw StateError(
            'circular dependency: ${[...path.sublist(start), id].join(' -> ')}');
      }
      path.add(id);
      for (final next in byId[id]?.dependsOn ?? const <String>{}) {
        if (byId.containsKey(next)) visit(next);
      }
      path.removeLast();
      visiting.remove(id);
      done.add(id);
    }

    for (final task in tasks) {
      visit(task.id);
    }
  }
}

// ---------------------------------------------------------------- the demo

/// A stand-in for a network call: takes some virtual time, and fails the
/// first `failures` times it is asked.
Future<String> Function(TaskContext) flaky(
  VirtualClock clock,
  String label, {
  int failures = 0,
  Duration takes = const Duration(milliseconds: 200),
}) {
  var seen = 0;
  return (TaskContext context) async {
    await clock.sleep(takes);
    context.throwIfCancelled();
    if (seen++ < failures) {
      throw StateError('$label unavailable (call ${seen})');
    }
    return '$label ok';
  };
}

Future<void> main() async {
  print('--- a pipeline with dependencies ---');
  {
    final clock = VirtualClock();
    final scheduler = Scheduler(concurrency: 2, clock: clock);
    final seen = <String>[];
    final subscription =
        scheduler.progress.listen((event) => seen.add(event.toString()));

    final tasks = <Task<Object?>>[
      Task<Object?>(
        id: 'fetch:routes',
        priority: Priority.high,
        run: flaky(clock, 'routes', takes: const Duration(milliseconds: 300)),
      ),
      Task<Object?>(
        id: 'fetch:fares',
        run: flaky(clock, 'fares', takes: const Duration(milliseconds: 150)),
      ),
      Task<Object?>(
        id: 'join',
        dependsOn: {'fetch:routes', 'fetch:fares'},
        run: (context) async {
          await clock.sleep(const Duration(milliseconds: 80));
          return 'joined ${context.results.length} input(s)';
        },
      ),
      Task<Object?>(
        id: 'report',
        priority: Priority.low,
        dependsOn: {'join'},
        run: (context) async {
          await clock.sleep(const Duration(milliseconds: 50));
          return 'report from "${context.results['join']}"';
        },
      ),
    ];

    final results = await scheduler.runAll(tasks);
    await subscription.cancel();
    await scheduler.close();

    for (final line in seen) {
      print('  $line');
    }
    print('  --');
    for (final result in results.values) {
      print('  $result');
    }
    print('  virtual time elapsed: ${clock.stamp()}');
  }

  print('\n--- retries with backoff ---');
  {
    final clock = VirtualClock();
    final scheduler = Scheduler(concurrency: 1, clock: clock);

    final results = await scheduler.runAll([
      // The breaker is keyed on the part of the id before the colon, so
      // these two tasks must not share a prefix -- otherwise the second
      // task's failures would trip the breaker on the first one.
      Task<Object?>(
        id: 'alpha:upload',
        maxAttempts: 5,
        baseBackoff: const Duration(milliseconds: 200),
        run: flaky(clock, 'upload', failures: 2),
      ),
      Task<Object?>(
        id: 'beta:upload',
        maxAttempts: 3,
        baseBackoff: const Duration(milliseconds: 200),
        run: flaky(clock, 'stubborn', failures: 99),
      ),
    ]);
    await scheduler.close();

    for (final result in results.values) {
      print('  $result');
      for (final attempt in result.attempts) {
        final waited = attempt.waitedBefore.inMilliseconds;
        print('      attempt ${attempt.number}: waited ${waited}ms, '
            '${attempt.succeeded ? 'ok' : attempt.error}');
      }
    }
    print('  virtual time elapsed: ${clock.stamp()}');
  }

  print('\n--- a failed dependency skips its dependants ---');
  {
    final clock = VirtualClock();
    final scheduler = Scheduler(concurrency: 3, clock: clock);

    final results = await scheduler.runAll([
      Task<Object?>(id: 'a', run: flaky(clock, 'a')),
      Task<Object?>(id: 'b', run: flaky(clock, 'b', failures: 99)),
      Task<Object?>(id: 'c', dependsOn: {'b'}, run: flaky(clock, 'c')),
      Task<Object?>(id: 'd', dependsOn: {'c'}, run: flaky(clock, 'd')),
      Task<Object?>(id: 'e', dependsOn: {'a'}, run: flaky(clock, 'e')),
    ]);
    await scheduler.close();

    for (final result in results.values) {
      print('  $result');
    }
  }

  print('\n--- cancellation ---');
  {
    final clock = VirtualClock();
    final scheduler = Scheduler(concurrency: 1, clock: clock);
    final cancel = Completer<void>();

    final results = await scheduler.runAll(
      [
        Task<Object?>(
          id: 'quick',
          priority: Priority.urgent,
          run: (context) async {
            await clock.sleep(const Duration(milliseconds: 10));
            cancel.complete(); // pull the plug once the first task is done
            return 'finished before the cancel';
          },
        ),
        Task<Object?>(
          id: 'slow',
          run: (context) async {
            for (var step = 0; step < 5; step++) {
              await clock.sleep(const Duration(milliseconds: 100));
              context.throwIfCancelled();
            }
            return 'should not get here';
          },
        ),
        Task<Object?>(id: 'never', run: flaky(clock, 'never')),
      ],
      cancel: cancel.future,
    );
    await scheduler.close();

    for (final result in results.values) {
      print('  $result');
    }
  }

  print('\n--- the circuit breaker ---');
  {
    final clock = VirtualClock();
    final scheduler = Scheduler(concurrency: 1, clock: clock);
    final breaker = scheduler.breakerFor('flaky');

    final results = await scheduler.runAll([
      Task<Object?>(
        id: 'flaky:call',
        maxAttempts: 6,
        baseBackoff: const Duration(milliseconds: 50),
        run: flaky(clock, 'downstream', failures: 99),
      ),
    ]);
    await scheduler.close();

    final result = results['flaky:call']!;
    print('  $result');
    print('  attempts made: ${result.attempts.length} of 6 allowed');
    print('  $breaker');
    print('  the breaker stopped the remaining attempts before they were made');
  }

  print('\n--- a cycle is refused up front ---');
  {
    final scheduler = Scheduler();
    try {
      await scheduler.runAll([
        Task<Object?>(id: 'x', dependsOn: {'z'}, run: (_) async => 1),
        Task<Object?>(id: 'y', dependsOn: {'x'}, run: (_) async => 2),
        Task<Object?>(id: 'z', dependsOn: {'y'}, run: (_) async => 3),
      ]);
      print('  (unexpectedly accepted)');
    } on StateError catch (error) {
      print('  ${error.message}');
    }
    await scheduler.close();
  }
}
