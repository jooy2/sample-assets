// Throwing, catching by type, rethrowing, and cleaning up in finally.

class ValidationException implements Exception {
  ValidationException(this.field, this.message, [this.cause]);

  final String field;
  final String message;
  final Object? cause;

  @override
  String toString() => 'ValidationException($field): $message';
}

int parseZone(String raw) {
  try {
    final zone = int.parse(raw);
    if (zone < 1 || zone > 6) {
      throw ValidationException('zone', 'zone $zone is outside 1-6');
    }
    return zone;
  } on FormatException catch (error) {
    // Wrap the low-level failure in something the caller can act on.
    throw ValidationException('zone', '"$raw" is not a number', error);
  }
}

Future<String> loadWithRetry(int attempts) async {
  for (var attempt = 1; attempt <= attempts; attempt++) {
    try {
      if (attempt < attempts) {
        throw StateError('attempt $attempt failed');
      }
      return 'loaded on attempt $attempt';
    } on StateError catch (error) {
      print('  ${error.message}');
      if (attempt == attempts) {
        rethrow; // out of retries: let the caller deal with it
      }
    }
  }
  throw StateError('unreachable');
}

Future<void> main() async {
  for (final raw in ['3', '9', 'east']) {
    try {
      print('${raw.padRight(6)} -> zone ${parseZone(raw)}');
    } on ValidationException catch (error) {
      final because = error.cause == null ? '' : ' (from ${error.cause.runtimeType})';
      print('${raw.padRight(6)} -> ${error.message}$because');
    }
  }

  print(await loadWithRetry(3));

  final open = <String>['report.csv'];
  try {
    throw const FormatException('the file ended halfway through a row');
  } on FormatException catch (error, stack) {
    print('caught: ${error.message}');
    print('stack has ${stack.toString().split('\n').length} frames');
  } finally {
    open.clear();
    print('cleaned up, ${open.length} handles left open');
  }
}
