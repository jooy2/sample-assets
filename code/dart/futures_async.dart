// Futures: awaiting one at a time, and awaiting several at once.

import 'dart:async';

Future<String> fetchStation(String id, int milliseconds) async {
  await Future<void>.delayed(Duration(milliseconds: milliseconds));
  return 'station $id';
}

Future<int> failingCall() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
  throw StateError('the upstream gave up');
}

Future<void> main() async {
  final watch = Stopwatch()..start();

  // Sequential: the second call starts only once the first has finished.
  final first = await fetchStation('ST-001', 120);
  final second = await fetchStation('ST-002', 120);
  print('$first, $second in ${watch.elapsedMilliseconds} ms');

  // Concurrent: both are in flight before either is awaited.
  watch.reset();
  final both = await Future.wait([
    fetchStation('ST-003', 120),
    fetchStation('ST-004', 120),
    fetchStation('ST-005', 80),
  ]);
  print('${both.join(', ')} in ${watch.elapsedMilliseconds} ms');

  // The first one to settle wins.
  final winner = await Future.any([
    fetchStation('slow', 200),
    fetchStation('quick', 30),
  ]);
  print('winner: $winner');

  try {
    await failingCall();
  } on StateError catch (error) {
    print('caught: ${error.message}');
  } finally {
    print('finally always runs');
  }

  final recovered = await failingCall().catchError((Object _) => -1);
  print('recovered with $recovered');
}
