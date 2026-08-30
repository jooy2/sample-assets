// Extensions add members to a type you do not own, resolved at compile time.

extension StringCasing on String {
  String get titleCase => split(' ')
      .map((word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
      .join(' ');

  String truncate(int length, {String ellipsis = '...'}) =>
      this.length <= length ? this : '${substring(0, length - ellipsis.length)}$ellipsis';

  bool get isBlank => trim().isEmpty;
}

extension NumberFormatting on num {
  String get asCurrency => '\$${toStringAsFixed(2)}';

  bool between(num low, num high) => this >= low && this <= high;
}

extension ListStatistics<T extends num> on List<T> {
  double get mean => isEmpty ? 0 : fold<double>(0, (sum, value) => sum + value) / length;

  T get largest => reduce((a, b) => a > b ? a : b);

  List<List<T>> chunked(int size) => [
        for (var start = 0; start < length; start += size)
          sublist(start, start + size > length ? length : start + size),
      ];
}

void main() {
  print('quill moor station'.titleCase);
  print('Stations on the Amber line'.truncate(18));
  print('blank: ${'   '.isBlank}');

  print(74.5.asCurrency);
  print('3 is between 1 and 5: ${3.between(1, 5)}');

  final readings = [21.4, 19.8, 24.1, 22.7, 18.9];
  print('mean ${readings.mean.toStringAsFixed(2)}, largest ${readings.largest}');
  print([1, 2, 3, 4, 5, 6, 7].chunked(3));
}
