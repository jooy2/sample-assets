// Dart enums can carry fields, take constructor arguments, and declare
// methods like any other class.

enum TransitLine {
  amber('Amber', 24, isAccessible: true),
  cobalt('Cobalt', 31, isAccessible: true),
  emerald('Emerald', 18, isAccessible: false),
  crimson('Crimson', 27, isAccessible: true),
  slate('Slate', 12, isAccessible: false);

  const TransitLine(this.label, this.stationCount, {required this.isAccessible});

  final String label;
  final int stationCount;
  final bool isAccessible;

  bool get isLong => stationCount >= 25;

  String get summary => '$label: $stationCount stations'
      '${isAccessible ? ', step free' : ''}';

  static TransitLine? byLabel(String label) {
    for (final line in values) {
      if (line.label.toLowerCase() == label.toLowerCase()) {
        return line;
      }
    }
    return null;
  }
}

enum Priority { low, normal, high, urgent }

void main() {
  for (final line in TransitLine.values) {
    print(line.summary);
  }

  print('\nlongest: ${TransitLine.values.reduce((a, b) => a.stationCount > b.stationCount ? a : b).label}');
  print('accessible: ${TransitLine.values.where((l) => l.isAccessible).map((l) => l.label).join(', ')}');
  print('lookup: ${TransitLine.byLabel('emerald')?.summary}');
  print('unknown: ${TransitLine.byLabel('violet')}');

  // A switch over an enum is checked for completeness.
  for (final priority in Priority.values) {
    final response = switch (priority) {
      Priority.low => 'within a week',
      Priority.normal => 'within two days',
      Priority.high => 'within four hours',
      Priority.urgent => 'immediately',
    };
    print('${priority.name.padRight(7)} $response');
  }

  print('index of high: ${Priority.high.index}, from name: ${Priority.values.byName('urgent')}');
}
