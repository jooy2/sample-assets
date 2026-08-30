// Lists, sets, and maps, with collection-if, collection-for, and spreads.

void main() {
  const lines = ['Amber', 'Cobalt', 'Emerald'];
  const includeReserve = true;

  final all = <String>[
    ...lines,
    if (includeReserve) 'Slate',
    for (final line in lines) '$line Express',
  ];
  print(all);

  final zones = <String, int>{
    'Alder Cross': 2,
    'Quill Wharf': 3,
    'Saltwick Halt': 5,
    'Nether Gate': 2,
  };

  final inner = zones.entries.where((entry) => entry.value <= 2).map((entry) => entry.key);
  print('inner zones: ${inner.join(', ')}');

  final byZone = <int, List<String>>{};
  zones.forEach((station, zone) => byZone.putIfAbsent(zone, () => []).add(station));
  print('grouped: $byZone');

  final platforms = [2, 4, 1, 3, 2, 6];
  print('total ${platforms.reduce((a, b) => a + b)}, '
      'largest ${platforms.reduce((a, b) => a > b ? a : b)}');

  final unique = platforms.toSet();
  print('unique $unique, has 5: ${unique.contains(5)}');
  print('union ${unique.union({7, 8})}, intersection ${unique.intersection({1, 2, 9})}');

  final sorted = [...zones.keys]..sort((a, b) => zones[a]!.compareTo(zones[b]!));
  print('by zone: $sorted');

  print('any deep: ${zones.values.any((zone) => zone > 4)}');
  print('all mapped: ${zones.values.every((zone) => zone > 0)}');
}
