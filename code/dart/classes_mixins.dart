// Constructors, inheritance, and mixins, which add behaviour without a
// second base class.

abstract class Vehicle {
  Vehicle(this.name, this.capacity);

  final String name;
  final int capacity;

  String describe() => '$name carries $capacity';
}

mixin Electric {
  int chargePercent = 100;

  void drain(int amount) {
    chargePercent = (chargePercent - amount).clamp(0, 100);
  }

  String get chargeLabel => '$chargePercent% charged';
}

mixin Trackable {
  final List<String> _stops = [];

  void arriveAt(String stop) => _stops.add(stop);

  List<String> get route => List.unmodifiable(_stops);
}

class Tram extends Vehicle with Electric, Trackable {
  Tram(super.name, super.capacity, this.line);

  final String line;

  @override
  String describe() => '${super.describe()} on the $line line, $chargeLabel';
}

class Ferry extends Vehicle with Trackable {
  Ferry(super.name, super.capacity);
}

void main() {
  final tram = Tram('Tram 14', 180, 'Amber')
    ..arriveAt('Alder Cross')
    ..arriveAt('Quill Wharf')
    ..drain(35);

  print(tram.describe());
  print('route: ${tram.route.join(' -> ')}');

  final ferry = Ferry('Harbour Ferry', 240)..arriveAt('Stonebay Pier');
  print(ferry.describe());
  print('route: ${ferry.route}');

  print('tram is a Vehicle: ${tram is Vehicle}');
  print('tram is Electric: ${tram is Electric}');
  print('ferry is Electric: ${ferry is Electric}');
}
