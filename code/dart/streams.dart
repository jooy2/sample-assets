// A Stream is a sequence that arrives over time; async* produces one and
// `await for` consumes it.

import 'dart:async';

Stream<int> countTo(int limit, {Duration gap = const Duration(milliseconds: 20)}) async* {
  for (var value = 1; value <= limit; value++) {
    await Future<void>.delayed(gap);
    yield value;
  }
}

Stream<double> temperatures() async* {
  var celsius = 20.0;
  for (var step = 0; step < 8; step++) {
    celsius += step.isEven ? 0.6 : -0.4;
    yield double.parse(celsius.toStringAsFixed(1));
  }
}

Future<void> main() async {
  final seen = <int>[];
  await for (final value in countTo(5)) {
    seen.add(value);
  }
  print('counted ${seen.join(' ')}');

  // A stream carries the same transformations an Iterable has.
  final warm = await temperatures().where((c) => c > 20.5).map((c) => '${c}C').toList();
  print('above 20.5: ${warm.join(', ')}');

  final total = await countTo(4, gap: Duration.zero).fold<int>(0, (sum, value) => sum + value);
  print('sum $total');

  // take() ends the subscription early; the producer stops there.
  final firstTwo = await countTo(100, gap: Duration.zero).take(2).toList();
  print('first two $firstTwo');

  // A broadcast stream can have more than one listener.
  final controller = StreamController<String>.broadcast();
  controller.stream.listen((event) => print('listener A: $event'));
  controller.stream.listen((event) => print('listener B: $event'));

  controller
    ..add('door opened')
    ..add('door closed');
  await controller.close();

  // Errors travel along the stream and are caught where it is consumed.
  Stream<int> failing() async* {
    yield 1;
    throw StateError('sensor dropped out');
  }

  try {
    await for (final value in failing()) {
      print('got $value');
    }
  } on StateError catch (error) {
    print('caught: ${error.message}');
  }
}
