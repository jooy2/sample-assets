// Records bundle values without declaring a class; patterns take them apart.

typedef Reading = ({String device, double celsius, int battery});

(int, int, int) splitSeconds(int total) =>
    (total ~/ 3600, (total % 3600) ~/ 60, total % 60);

String classify(Reading reading) => switch (reading) {
      (device: _, celsius: > 30, battery: _) => 'too warm',
      (device: _, celsius: _, battery: < 15) => 'battery low',
      (device: final id, celsius: final c, battery: _) when c < 0 =>
        '$id is below freezing',
      _ => 'nominal',
    };

void main() {
  // A positional record, destructured in one line.
  final (hours, minutes, seconds) = splitSeconds(9045);
  print('${hours}h ${minutes}m ${seconds}s');

  final readings = <Reading>[
    (device: 'SNS-01', celsius: -18.4, battery: 74),
    (device: 'SNS-04', celsius: 31.2, battery: 88),
    (device: 'SNS-07', celsius: 21.0, battery: 9),
    (device: 'SNS-09', celsius: 19.6, battery: 62),
  ];

  for (final reading in readings) {
    print('${reading.device.padRight(8)} ${classify(reading)}');
  }

  // Patterns work in if-case too.
  const payload = {'station': 'Alder Cross', 'zone': 2, 'platforms': 2};
  if (payload case {'station': final String name, 'zone': final int zone}) {
    print('$name sits in zone $zone');
  }

  // List patterns, including a rest element.
  const lines = ['Amber', 'Cobalt', 'Emerald', 'Crimson'];
  if (lines case [final first, final second, ...final rest]) {
    print('first two: $first, $second; ${rest.length} more');
  }
}
