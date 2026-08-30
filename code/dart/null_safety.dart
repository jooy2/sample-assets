// Dart separates `String` from `String?` and will not let a nullable value
// be used until it has been checked.

class Station {
  Station({required this.name, this.nickname, required this.zone});

  final String name;      // never null
  final String? nickname; // may be null
  final int zone;
}

String label(Station station) {
  // ?? supplies a fallback when the left side is null.
  return station.nickname ?? station.name;
}

int? zoneOf(Map<String, Station> network, String name) => network[name]?.zone;

void main() {
  final network = <String, Station>{
    'alder': Station(name: 'Alder Cross', nickname: 'the Cross', zone: 2),
    'quill': Station(name: 'Quill Wharf', zone: 3),
  };

  for (final key in ['alder', 'quill', 'nether']) {
    final station = network[key];

    if (station == null) {
      print('$key is not on the network');
      continue;
    }
    // Past the check, the compiler treats `station` as non-nullable.
    print('$key -> ${label(station)} (zone ${station.zone})');
  }

  print('zone of quill: ${zoneOf(network, 'quill')}');
  print('zone of nether: ${zoneOf(network, 'nether') ?? -1}');

  // ??= assigns only when the target is still null.
  String? cached;
  cached ??= 'computed once';
  cached ??= 'never reached';
  print(cached);

  // late defers the initialisation without giving up non-nullability.
  late final String expensive;
  expensive = 'built on first use';
  print(expensive);

  final lengths = <String?>['amber', null, 'cobalt']
      .map((line) => line?.length ?? 0)
      .toList();
  print('lengths $lengths');
}
