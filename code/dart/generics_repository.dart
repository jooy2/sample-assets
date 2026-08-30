// Generic classes, generic methods, and a bound on the type parameter.

abstract interface class Identifiable {
  int get id;
}

class Product implements Identifiable {
  Product(this.id, this.name, this.price);

  @override
  final int id;
  final String name;
  final double price;

  @override
  String toString() => '#$id $name (${price.toStringAsFixed(2)})';
}

class Repository<T extends Identifiable> {
  final Map<int, T> _items = {};

  void add(T item) {
    if (_items.containsKey(item.id)) {
      throw ArgumentError('id ${item.id} is already taken');
    }
    _items[item.id] = item;
  }

  T? find(int id) => _items[id];

  bool remove(int id) => _items.remove(id) != null;

  Iterable<T> where(bool Function(T) test) => _items.values.where(test);

  int get length => _items.length;
}

// A generic function: the type argument is inferred from the call.
T largestBy<T>(Iterable<T> values, Comparable<Object> Function(T) key) =>
    values.reduce((best, next) => key(next).compareTo(key(best)) > 0 ? next : best);

void main() {
  final repository = Repository<Product>()
    ..add(Product(1, 'Matte Ceramic Mug', 12.50))
    ..add(Product(2, 'Bamboo Desk Mat', 32.00))
    ..add(Product(3, 'Cast Iron Skillet', 59.00));

  print(repository.find(2));
  print('missing: ${repository.find(99)}');
  print('over 20: ${repository.where((p) => p.price > 20).join(' | ')}');
  print('dearest: ${largestBy(repository.where((_) => true), (Product p) => p.price)}');

  try {
    repository.add(Product(1, 'Duplicate', 0));
  } on ArgumentError catch (error) {
    print('caught: ${error.message}');
  }

  print('length ${repository.length}, removed 3: ${repository.remove(3)}');
}
