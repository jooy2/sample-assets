// spreadsheet_engine.dart — a calculation engine for a grid of cells.
//
// Formula parsing, a dependency graph, topological recalculation, cycle
// detection, ranges, built-in functions, and error values that propagate the
// way a real spreadsheet's do.
//
//   dart run spreadsheet_engine.dart
//
// A cell holds a literal or a formula beginning with '='. Formulas refer to
// other cells (A1), to ranges (A1:B4), and to functions:
//
//   A1: 10          B1: =A1*2        C1: =SUM(A1:B1)
//   A2: 5           B2: =IF(A2>3, "big", "small")
//
// One file, no packages beyond dart:core and dart:math.

import 'dart:math' as math;

// ------------------------------------------------------------------- values

/// Everything a cell can hold. A sealed class so a switch over it is
/// exhaustive and the compiler says when a case is missing.
sealed class Value {
  const Value();

  static const Value blank = BlankValue();

  num get asNumber => switch (this) {
        NumberValue(:final value) => value,
        BoolValue(:final value) => value ? 1 : 0,
        BlankValue() => 0,
        _ => throw EvalError('#VALUE!', 'expected a number'),
      };

  String get asText => switch (this) {
        TextValue(:final value) => value,
        NumberValue(:final value) => formatNumber(value),
        BoolValue(:final value) => value ? 'TRUE' : 'FALSE',
        BlankValue() => '',
        ErrorValue(:final code) => code,
      };

  bool get truthy => switch (this) {
        BoolValue(:final value) => value,
        NumberValue(:final value) => value != 0,
        TextValue(:final value) => value.isNotEmpty,
        BlankValue() => false,
        ErrorValue() => false,
      };

  bool get isError => this is ErrorValue;
}

final class NumberValue extends Value {
  final num value;
  const NumberValue(this.value);
  @override
  String toString() => formatNumber(value);
}

final class TextValue extends Value {
  final String value;
  const TextValue(this.value);
  @override
  String toString() => value;
}

final class BoolValue extends Value {
  final bool value;
  const BoolValue(this.value);
  @override
  String toString() => value ? 'TRUE' : 'FALSE';
}

final class BlankValue extends Value {
  const BlankValue();
  @override
  String toString() => '';
}

/// An error travels through every formula that touches it, exactly as in a
/// spreadsheet: one bad cell poisons its dependants and nothing else.
final class ErrorValue extends Value {
  final String code;
  final String detail;
  const ErrorValue(this.code, [this.detail = '']);
  @override
  String toString() => code;
}

String formatNumber(num value) {
  if (value is int || value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  var text = value.toStringAsFixed(4);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
}

class EvalError implements Exception {
  final String code;
  final String detail;
  EvalError(this.code, [this.detail = '']);
  @override
  String toString() => detail.isEmpty ? code : '$code ($detail)';
}

// -------------------------------------------------------------- references

/// An A1-style cell reference, and the conversions in both directions.
class Ref implements Comparable<Ref> {
  final int row; // zero-based
  final int column; // zero-based

  const Ref(this.row, this.column);

  static final RegExp pattern = RegExp(r'^([A-Za-z]+)([0-9]+)$');

  static Ref? tryParse(String text) {
    final match = pattern.firstMatch(text.trim());
    if (match == null) return null;

    var column = 0;
    for (final unit in match.group(1)!.toUpperCase().codeUnits) {
      column = column * 26 + (unit - 64); // 'A' is 65
    }
    final row = int.parse(match.group(2)!);
    if (row < 1 || column < 1) return null;
    return Ref(row - 1, column - 1);
  }

  String get label {
    var name = '';
    var remaining = column + 1;
    while (remaining > 0) {
      final digit = (remaining - 1) % 26;
      name = String.fromCharCode(65 + digit) + name;
      remaining = (remaining - 1) ~/ 26;
    }
    return '$name${row + 1}';
  }

  @override
  bool operator ==(Object other) =>
      other is Ref && other.row == row && other.column == column;

  @override
  int get hashCode => Object.hash(row, column);

  @override
  int compareTo(Ref other) =>
      row != other.row ? row.compareTo(other.row) : column.compareTo(other.column);

  @override
  String toString() => label;
}

/// A rectangular block of cells, inclusive at both corners.
class Range {
  final Ref start;
  final Ref end;

  Range(Ref a, Ref b)
      : start = Ref(math.min(a.row, b.row), math.min(a.column, b.column)),
        end = Ref(math.max(a.row, b.row), math.max(a.column, b.column));

  Iterable<Ref> get cells sync* {
    for (var row = start.row; row <= end.row; row++) {
      for (var column = start.column; column <= end.column; column++) {
        yield Ref(row, column);
      }
    }
  }

  @override
  String toString() => '${start.label}:${end.label}';
}

// ------------------------------------------------------------------ syntax

sealed class Expr {
  const Expr();
}

final class LiteralExpr extends Expr {
  final Value value;
  const LiteralExpr(this.value);
}

final class RefExpr extends Expr {
  final Ref ref;
  const RefExpr(this.ref);
}

final class RangeExpr extends Expr {
  final Range range;
  const RangeExpr(this.range);
}

final class UnaryExpr extends Expr {
  final String op;
  final Expr operand;
  const UnaryExpr(this.op, this.operand);
}

final class BinaryExpr extends Expr {
  final String op;
  final Expr left;
  final Expr right;
  const BinaryExpr(this.op, this.left, this.right);
}

final class CallExpr extends Expr {
  final String name;
  final List<Expr> arguments;
  const CallExpr(this.name, this.arguments);
}

// ------------------------------------------------------------------ parser

class FormulaParser {
  final String source;
  int _position = 0;

  FormulaParser(this.source);

  Expr parse() {
    final expr = _parseComparison();
    _skipSpace();
    if (_position < source.length) {
      throw EvalError('#ERROR!', 'unexpected "${source.substring(_position)}"');
    }
    return expr;
  }

  void _skipSpace() {
    while (_position < source.length && source[_position] == ' ') {
      _position++;
    }
  }

  bool _take(String text) {
    _skipSpace();
    if (source.startsWith(text, _position)) {
      _position += text.length;
      return true;
    }
    return false;
  }

  String? _peekOperator(List<String> operators) {
    _skipSpace();
    for (final op in operators) {
      if (source.startsWith(op, _position)) return op;
    }
    return null;
  }

  Expr _parseComparison() {
    var left = _parseConcat();
    // Two-character operators must be tried before their prefixes.
    while (true) {
      final op = _peekOperator(['<=', '>=', '<>', '=', '<', '>']);
      if (op == null) break;
      _position += op.length;
      left = BinaryExpr(op, left, _parseConcat());
    }
    return left;
  }

  Expr _parseConcat() {
    var left = _parseAdditive();
    while (_peekOperator(['&']) != null) {
      _position += 1;
      left = BinaryExpr('&', left, _parseAdditive());
    }
    return left;
  }

  Expr _parseAdditive() {
    var left = _parseMultiplicative();
    while (true) {
      final op = _peekOperator(['+', '-']);
      if (op == null) break;
      _position += 1;
      left = BinaryExpr(op, left, _parseMultiplicative());
    }
    return left;
  }

  Expr _parseMultiplicative() {
    var left = _parsePower();
    while (true) {
      final op = _peekOperator(['*', '/']);
      if (op == null) break;
      _position += 1;
      left = BinaryExpr(op, left, _parsePower());
    }
    return left;
  }

  Expr _parsePower() {
    final base = _parseUnary();
    if (_peekOperator(['^']) != null) {
      _position += 1;
      return BinaryExpr('^', base, _parsePower()); // right-associative
    }
    return base;
  }

  Expr _parseUnary() {
    _skipSpace();
    if (_take('-')) return UnaryExpr('-', _parseUnary());
    if (_take('+')) return _parseUnary();
    return _parsePercent();
  }

  Expr _parsePercent() {
    var expr = _parsePrimary();
    while (_take('%')) {
      expr = BinaryExpr('/', expr, const LiteralExpr(NumberValue(100)));
    }
    return expr;
  }

  Expr _parsePrimary() {
    _skipSpace();
    if (_position >= source.length) {
      throw EvalError('#ERROR!', 'formula ended early');
    }

    final char = source[_position];

    if (char == '(') {
      _position++;
      final inner = _parseComparison();
      if (!_take(')')) throw EvalError('#ERROR!', 'missing ")"');
      return inner;
    }

    if (char == '"') {
      _position++;
      final buffer = StringBuffer();
      while (_position < source.length) {
        if (source[_position] == '"') {
          // A doubled quote is a literal quote, as in a spreadsheet.
          if (_position + 1 < source.length && source[_position + 1] == '"') {
            buffer.write('"');
            _position += 2;
            continue;
          }
          _position++;
          return LiteralExpr(TextValue(buffer.toString()));
        }
        buffer.write(source[_position++]);
      }
      throw EvalError('#ERROR!', 'unterminated text');
    }

    if (RegExp(r'[0-9.]').hasMatch(char)) {
      final start = _position;
      while (_position < source.length &&
          RegExp(r'[0-9.]').hasMatch(source[_position])) {
        _position++;
      }
      final text = source.substring(start, _position);
      final number = num.tryParse(text);
      if (number == null) throw EvalError('#NUM!', 'bad number "$text"');
      return LiteralExpr(NumberValue(number));
    }

    if (RegExp(r'[A-Za-z_]').hasMatch(char)) {
      final start = _position;
      while (_position < source.length &&
          RegExp(r'[A-Za-z0-9_.]').hasMatch(source[_position])) {
        _position++;
      }
      final word = source.substring(start, _position);

      if (_take('(')) {
        final arguments = <Expr>[];
        if (!_take(')')) {
          do {
            arguments.add(_parseComparison());
          } while (_take(','));
          if (!_take(')')) throw EvalError('#ERROR!', 'missing ")" in $word');
        }
        return CallExpr(word.toUpperCase(), arguments);
      }

      if (word.toUpperCase() == 'TRUE') return const LiteralExpr(BoolValue(true));
      if (word.toUpperCase() == 'FALSE') return const LiteralExpr(BoolValue(false));

      final ref = Ref.tryParse(word);
      if (ref == null) throw EvalError('#NAME?', 'unknown name "$word"');

      if (_take(':')) {
        final start2 = _position;
        while (_position < source.length &&
            RegExp(r'[A-Za-z0-9]').hasMatch(source[_position])) {
          _position++;
        }
        final other = Ref.tryParse(source.substring(start2, _position));
        if (other == null) throw EvalError('#REF!', 'bad range end');
        return RangeExpr(Range(ref, other));
      }

      return RefExpr(ref);
    }

    throw EvalError('#ERROR!', 'unexpected "$char"');
  }
}

// ----------------------------------------------------------------- the sheet

typedef Builtin = Value Function(List<Value> flat, List<Value> raw);

class Sheet {
  final Map<Ref, String> _input = {};
  final Map<Ref, Expr?> _parsed = {};
  final Map<Ref, Value> _cache = {};
  final Set<Ref> _evaluating = {};

  /// Set a cell's contents. Anything beginning with '=' is a formula.
  void set(String reference, String contents) {
    final ref = Ref.tryParse(reference);
    if (ref == null) throw ArgumentError('not a cell reference: $reference');

    _input[ref] = contents;
    _parsed.remove(ref);
    _cache.clear(); // any cell may depend on this one
  }

  void setAll(Map<String, String> cells) => cells.forEach(set);

  String raw(String reference) => _input[Ref.tryParse(reference)!] ?? '';

  Value value(String reference) {
    final ref = Ref.tryParse(reference);
    if (ref == null) return const ErrorValue('#REF!');
    return _evaluate(ref);
  }

  String display(String reference) => value(reference).asText;

  /// Every cell that has anything in it, in reading order.
  List<Ref> get filled => _input.keys.toList()..sort();

  /// The cells a formula reads, directly.
  Set<Ref> dependencies(Ref ref) {
    final expr = _parse(ref);
    final out = <Ref>{};
    void walk(Expr? node) {
      switch (node) {
        case null:
          return;
        case RefExpr(:final ref):
          out.add(ref);
        case RangeExpr(:final range):
          out.addAll(range.cells);
        case UnaryExpr(:final operand):
          walk(operand);
        case BinaryExpr(:final left, :final right):
          walk(left);
          walk(right);
        case CallExpr(:final arguments):
          arguments.forEach(walk);
        case LiteralExpr():
          return;
      }
    }

    walk(expr);
    return out;
  }

  /// Recalculation order: dependencies before dependants.
  List<Ref> calculationOrder() {
    final incoming = <Ref, int>{};
    final dependants = <Ref, List<Ref>>{};

    for (final ref in filled) {
      incoming.putIfAbsent(ref, () => 0);
      for (final source in dependencies(ref)) {
        if (!_input.containsKey(source)) continue;
        dependants.putIfAbsent(source, () => []).add(ref);
        incoming[ref] = (incoming[ref] ?? 0) + 1;
      }
    }

    final ready = incoming.entries
        .where((entry) => entry.value == 0)
        .map((entry) => entry.key)
        .toList()
      ..sort();
    final order = <Ref>[];

    while (ready.isNotEmpty) {
      final ref = ready.removeAt(0);
      order.add(ref);
      for (final dependant in (dependants[ref] ?? const <Ref>[])) {
        incoming[dependant] = incoming[dependant]! - 1;
        if (incoming[dependant] == 0) ready.add(dependant);
      }
      ready.sort();
    }

    return order; // shorter than `filled` when a cycle exists
  }

  List<Ref> get circular {
    final ordered = calculationOrder().toSet();
    return filled.where((ref) => !ordered.contains(ref)).toList();
  }

  // ------------------------------------------------------------ internals

  Expr? _parse(Ref ref) {
    if (_parsed.containsKey(ref)) return _parsed[ref];

    final contents = _input[ref];
    Expr? expr;
    if (contents != null && contents.startsWith('=')) {
      try {
        expr = FormulaParser(contents.substring(1)).parse();
      } on EvalError catch (error) {
        expr = LiteralExpr(ErrorValue(error.code, error.detail));
      }
    }
    _parsed[ref] = expr;
    return expr;
  }

  Value _evaluate(Ref ref) {
    final cached = _cache[ref];
    if (cached != null) return cached;

    if (_evaluating.contains(ref)) {
      return const ErrorValue('#CIRCULAR!', 'a cell depends on itself');
    }

    final contents = _input[ref];
    if (contents == null || contents.isEmpty) return Value.blank;

    Value result;
    if (!contents.startsWith('=')) {
      final number = num.tryParse(contents);
      result = number != null ? NumberValue(number) : TextValue(contents);
    } else {
      _evaluating.add(ref);
      try {
        result = _eval(_parse(ref)!);
      } on EvalError catch (error) {
        result = ErrorValue(error.code, error.detail);
      } finally {
        _evaluating.remove(ref);
      }
    }

    _cache[ref] = result;
    return result;
  }

  Value _eval(Expr expr) {
    switch (expr) {
      case LiteralExpr(:final value):
        return value;

      case RefExpr(:final ref):
        return _evaluate(ref);

      case RangeExpr():
        throw EvalError('#VALUE!', 'a range needs a function around it');

      case UnaryExpr(:final op, :final operand):
        final value = _eval(operand);
        if (value.isError) return value;
        return op == '-' ? NumberValue(-value.asNumber) : value;

      case BinaryExpr(:final op, :final left, :final right):
        final a = _eval(left);
        if (a.isError) return a;
        final b = _eval(right);
        if (b.isError) return b;
        return _binary(op, a, b);

      case CallExpr(:final name, :final arguments):
        final builtin = builtins[name];
        if (builtin == null) throw EvalError('#NAME?', 'no function $name');

        final flat = <Value>[];
        final raw = <Value>[];
        for (final argument in arguments) {
          if (argument is RangeExpr) {
            final values =
                argument.range.cells.map(_evaluate).toList(growable: false);
            flat.addAll(values);
            raw.add(values.isEmpty ? Value.blank : values.first);
          } else {
            final value = _eval(argument);
            flat.add(value);
            raw.add(value);
          }
        }

        // IF must not evaluate both branches eagerly for the error to be
        // avoidable, so it is handled before the general path.
        if (name == 'IF') {
          if (arguments.length < 2) {
            throw EvalError('#VALUE!', 'IF needs a test and a result');
          }
          final test = _eval(arguments[0]);
          if (test.isError) return test;
          if (test.truthy) return _eval(arguments[1]);
          return arguments.length > 2 ? _eval(arguments[2]) : const BoolValue(false);
        }

        for (final value in flat) {
          if (value.isError && name != 'ISERROR' && name != 'IFERROR') {
            return value;
          }
        }
        return builtin(flat, raw);
    }
  }

  Value _binary(String op, Value a, Value b) {
    if (op == '&') return TextValue(a.asText + b.asText);

    if (['=', '<>', '<', '<=', '>', '>='].contains(op)) {
      final comparison = (a is TextValue || b is TextValue)
          ? a.asText.compareTo(b.asText)
          : a.asNumber.compareTo(b.asNumber);
      return BoolValue(switch (op) {
        '=' => comparison == 0,
        '<>' => comparison != 0,
        '<' => comparison < 0,
        '<=' => comparison <= 0,
        '>' => comparison > 0,
        _ => comparison >= 0,
      });
    }

    final x = a.asNumber;
    final y = b.asNumber;
    return switch (op) {
      '+' => NumberValue(x + y),
      '-' => NumberValue(x - y),
      '*' => NumberValue(x * y),
      '/' => y == 0
          ? const ErrorValue('#DIV/0!')
          : NumberValue(x / y),
      '^' => NumberValue(math.pow(x, y)),
      _ => throw EvalError('#ERROR!', 'unknown operator $op'),
    };
  }
}

// --------------------------------------------------------------- built-ins

Iterable<num> _numbers(List<Value> values) => values
    .where((value) => value is NumberValue || value is BoolValue)
    .map((value) => value.asNumber);

final Map<String, Builtin> builtins = {
  'SUM': (flat, _) => NumberValue(_numbers(flat).fold<num>(0, (a, b) => a + b)),
  'PRODUCT': (flat, _) =>
      NumberValue(_numbers(flat).fold<num>(1, (a, b) => a * b)),
  'COUNT': (flat, _) => NumberValue(_numbers(flat).length),
  'COUNTA': (flat, _) =>
      NumberValue(flat.where((value) => value is! BlankValue).length),
  'AVERAGE': (flat, _) {
    final values = _numbers(flat).toList();
    if (values.isEmpty) return const ErrorValue('#DIV/0!');
    return NumberValue(values.reduce((a, b) => a + b) / values.length);
  },
  'MIN': (flat, _) {
    final values = _numbers(flat).toList();
    return values.isEmpty ? const NumberValue(0) : NumberValue(values.reduce(math.min));
  },
  'MAX': (flat, _) {
    final values = _numbers(flat).toList();
    return values.isEmpty ? const NumberValue(0) : NumberValue(values.reduce(math.max));
  },
  'MEDIAN': (flat, _) {
    final values = _numbers(flat).toList()..sort();
    if (values.isEmpty) return const ErrorValue('#NUM!');
    final middle = values.length ~/ 2;
    return NumberValue(values.length.isOdd
        ? values[middle]
        : (values[middle - 1] + values[middle]) / 2);
  },
  'ROUND': (flat, _) {
    if (flat.isEmpty) return const ErrorValue('#VALUE!');
    final digits = flat.length > 1 ? flat[1].asNumber.toInt() : 0;
    final scale = math.pow(10, digits);
    return NumberValue((flat[0].asNumber * scale).round() / scale);
  },
  'ABS': (flat, _) => NumberValue(flat[0].asNumber.abs()),
  'SQRT': (flat, _) => flat[0].asNumber < 0
      ? const ErrorValue('#NUM!', 'square root of a negative')
      : NumberValue(math.sqrt(flat[0].asNumber.toDouble())),
  'POWER': (flat, _) => NumberValue(math.pow(flat[0].asNumber, flat[1].asNumber)),
  'AND': (flat, _) => BoolValue(flat.every((value) => value.truthy)),
  'OR': (flat, _) => BoolValue(flat.any((value) => value.truthy)),
  'NOT': (flat, _) => BoolValue(!flat[0].truthy),
  'IF': (flat, _) => flat.isEmpty ? const ErrorValue('#VALUE!') : flat[0],
  'ISERROR': (flat, _) => BoolValue(flat.isNotEmpty && flat[0].isError),
  'IFERROR': (flat, _) => flat.isEmpty
      ? const ErrorValue('#VALUE!')
      : (flat[0].isError && flat.length > 1 ? flat[1] : flat[0]),
  'CONCAT': (flat, _) => TextValue(flat.map((value) => value.asText).join()),
  'LEN': (flat, _) => NumberValue(flat[0].asText.length),
  'UPPER': (flat, _) => TextValue(flat[0].asText.toUpperCase()),
  'LOWER': (flat, _) => TextValue(flat[0].asText.toLowerCase()),
  'TRIM': (flat, _) => TextValue(flat[0].asText.trim()),
};

// ------------------------------------------------------------- presentation

void printSheet(Sheet sheet, {bool formulas = false}) {
  final filled = sheet.filled;
  if (filled.isEmpty) {
    print('  (empty)');
    return;
  }

  final lastRow = filled.map((ref) => ref.row).reduce(math.max);
  final lastColumn = filled.map((ref) => ref.column).reduce(math.max);

  final widths = <int>[];
  for (var column = 0; column <= lastColumn; column++) {
    var width = Ref(0, column).label.replaceAll(RegExp(r'\d'), '').length;
    for (var row = 0; row <= lastRow; row++) {
      final ref = Ref(row, column);
      final text = formulas
          ? sheet.raw(ref.label)
          : sheet.display(ref.label);
      width = math.max(width, text.length);
    }
    widths.add(math.max(width, 5));
  }

  final header = StringBuffer('     ');
  for (var column = 0; column <= lastColumn; column++) {
    final label = Ref(0, column).label.replaceAll(RegExp(r'\d'), '');
    header.write(label.padRight(widths[column] + 2));
  }
  print('  ${header.toString().trimRight()}');

  for (var row = 0; row <= lastRow; row++) {
    final line = StringBuffer('${(row + 1).toString().padLeft(3)}  ');
    for (var column = 0; column <= lastColumn; column++) {
      final ref = Ref(row, column);
      final text = formulas ? sheet.raw(ref.label) : sheet.display(ref.label);
      line.write(text.padRight(widths[column] + 2));
    }
    print('  ${line.toString().trimRight()}');
  }
}

// -------------------------------------------------------------------- main

void main(List<String> arguments) {
  final sheet = Sheet();

  // A quarterly revenue model. Every figure is invented.
  sheet.setAll({
    'A1': 'Route', 'B1': 'Q1', 'C1': 'Q2', 'D1': 'Total', 'E1': 'Share',
    'A2': 'Harbour Loop', 'B2': '1284', 'C2': '1461',
    'A3': 'Kestrel Point', 'B3': '902', 'C3': '988',
    'A4': 'Halloway', 'B4': '341', 'C4': '355',
    'A5': 'Night Crossing', 'B5': '556', 'C5': '612',
    'D2': '=SUM(B2:C2)', 'D3': '=SUM(B3:C3)',
    'D4': '=SUM(B4:C4)', 'D5': '=SUM(B5:C5)',
    'E2': '=ROUND(D2/\$D\$7*100, 1)',
    'A7': 'Total', 'B7': '=SUM(B2:B5)', 'C7': '=SUM(C2:C5)',
    'D7': '=SUM(D2:D5)',
    'A8': 'Mean', 'B8': '=AVERAGE(B2:B5)', 'C8': '=AVERAGE(C2:C5)',
    'A9': 'Best', 'B9': '=MAX(B2:B5)', 'C9': '=MAX(C2:C5)',
    'A10': 'Growth', 'B10': '=ROUND((C7-B7)/B7*100, 2)&"%"',
    'A11': 'Verdict', 'B11': '=IF(C7>B7, "up", "down")',
  });
  sheet.set('E2', '=ROUND(D2/D7*100, 1)');
  sheet.set('E3', '=ROUND(D3/D7*100, 1)');
  sheet.set('E4', '=ROUND(D4/D7*100, 1)');
  sheet.set('E5', '=ROUND(D5/D7*100, 1)');

  print('--- values ---');
  printSheet(sheet);

  print('\n--- formulas ---');
  printSheet(sheet, formulas: true);

  print('\n--- calculation order ---');
  final order = sheet.calculationOrder();
  print('  ${order.map((ref) => ref.label).join(' -> ')}');

  print('\n--- dependencies of D7 ---');
  final deps = sheet.dependencies(Ref.tryParse('D7')!).toList()..sort();
  print('  ${deps.map((ref) => ref.label).join(', ')}');

  print('\n--- editing propagates ---');
  print('  D7 before: ${sheet.display('D7')}, E2 before: ${sheet.display('E2')}');
  sheet.set('B2', '1500');
  print('  B2 := 1500');
  print('  D7 after:  ${sheet.display('D7')}, E2 after:  ${sheet.display('E2')}');

  print('\n--- errors propagate ---');
  final broken = Sheet();
  broken.setAll({
    'A1': '10',
    'A2': '0',
    'A3': '=A1/A2',
    'A4': '=A3+1',
    'A5': '=SUM(A1:A4)',
    'A6': '=IFERROR(A3, "recovered")',
    'A7': '=ISERROR(A3)',
    'A8': '=NOSUCH(1)',
    'A9': '=SQRT(-4)',
    'A10': '=1+',
  });
  for (final ref in broken.filled) {
    print('  ${ref.label.padRight(4)} '
        '${broken.raw(ref.label).padRight(22)} ${broken.display(ref.label)}');
  }

  print('\n--- circular references ---');
  final loop = Sheet();
  loop.setAll({'A1': '=B1+1', 'B1': '=C1+1', 'C1': '=A1+1', 'D1': '5'});
  print('  cells that never settle: '
      '${loop.circular.map((ref) => ref.label).join(', ')}');
  print('  A1 evaluates to ${loop.display('A1')}');
  print('  D1, which is outside the loop, is still ${loop.display('D1')}');

  print('\n--- text and comparison ---');
  final text = Sheet();
  text.setAll({
    'A1': 'Fenwick',
    'A2': 'District',
    'B1': '=UPPER(A1)&" "&LOWER(A2)',
    'B2': '=LEN(B1)',
    'B3': '=CONCAT("a", "b", "c")',
    'B4': '=A1="Fenwick"',
    'B5': '=IF(LEN(A1)>5, "long", "short")',
    'B6': r'=10%*200',
    'B7': '=2^3^2',
  });
  for (final ref in text.filled.where((ref) => ref.column == 1)) {
    print('  ${ref.label}  ${text.raw(ref.label).padRight(26)} '
        '${text.display(ref.label)}');
  }
}
