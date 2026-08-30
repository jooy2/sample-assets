// Iterable operations are lazy: nothing is computed until the sequence is
// walked, and only as far as the caller goes.

Iterable<int> naturals() sync* {
  var value = 1;
  while (true) {
    yield value++;
  }
}

Iterable<int> traced(Iterable<int> source, List<String> log) sync* {
  for (final value in source) {
    log.add('saw $value');
    yield value;
  }
}

Iterable<BigInt> fibonacci() sync* {
  var previous = BigInt.zero;
  var current = BigInt.one;

  while (true) {
    yield current;
    final next = previous + current;
    previous = current;
    current = next;
  }
}

void main() {
  print(naturals().where((n) => n % 7 == 0).take(5).toList());

  final log = <String>[];
  final firstThree = traced(naturals(), log).where((n) => n.isEven).take(3).toList();
  print('result $firstThree');
  print('the source was pulled ${log.length} times, not infinitely');

  print(fibonacci().take(15).map((n) => n.toString()).join(' '));
  print('50th fibonacci: ${fibonacci().elementAt(49)}');

  const stations = ['Alder Cross', 'Quill Wharf', 'Saltwick Halt', 'Nether Gate'];

  print(stations.map((s) => s.split(' ').first).join(', '));
  print(stations.expand((s) => s.split(' ')).toSet().toList()..sort());
  print('first long name: ${stations.firstWhere((s) => s.length > 11, orElse: () => 'none')}');
  print('skipWhile: ${stations.skipWhile((s) => s.startsWith('A')).toList()}');
}
