// Isolates run on their own thread with their own memory, so work is
// handed over by message rather than shared.

import 'dart:async';
import 'dart:isolate';

// Runs in the isolate: no state is shared with the caller.
int countPrimes(int limit) {
  final composite = List<bool>.filled(limit + 1, false);
  var found = 0;

  for (var candidate = 2; candidate <= limit; candidate++) {
    if (composite[candidate]) {
      continue;
    }
    found++;
    for (var multiple = candidate * candidate; multiple <= limit; multiple += candidate) {
      composite[multiple] = true;
    }
  }
  return found;
}

// A worker that answers on the port it is given.
Future<void> worker(SendPort reply) async {
  final inbox = ReceivePort();
  reply.send(inbox.sendPort);

  await for (final message in inbox) {
    if (message is int) {
      reply.send('$message has ${countPrimes(message)} primes');
    } else if (message == 'stop') {
      inbox.close();
    }
  }
}

Future<void> main() async {
  // Isolate.run is the short form: one computation, one result.
  final quick = await Isolate.run(() => countPrimes(200000));
  print('Isolate.run counted $quick primes');

  // The long form keeps an isolate alive and talks to it over ports.
  final inbox = ReceivePort();
  await Isolate.spawn(worker, inbox.sendPort);

  final events = StreamQueue<dynamic>(inbox);
  final SendPort outbox = await events.next as SendPort;

  for (final limit in [1000, 10000, 100000]) {
    outbox.send(limit);
    print(await events.next);
  }

  outbox.send('stop');
  await events.cancel();
  print('worker stopped');
}

// A tiny queue over a stream, so replies can be awaited one at a time.
class StreamQueue<T> {
  StreamQueue(Stream<T> stream) : _iterator = StreamIterator<T>(stream);

  final StreamIterator<T> _iterator;

  Future<T> get next async {
    await _iterator.moveNext();
    return _iterator.current;
  }

  Future<void> cancel() => _iterator.cancel();
}
