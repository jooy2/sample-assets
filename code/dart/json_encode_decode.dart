// Encoding and decoding JSON with dart:convert, and mapping it onto classes.

import 'dart:convert';

class Order {
  Order({
    required this.orderId,
    required this.userId,
    required this.total,
    required this.status,
    this.shippedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        orderId: json['order_id'] as String,
        userId: json['user_id'] as int,
        total: (json['total'] as num).toDouble(),
        status: json['status'] as String,
        shippedAt: json['shipped_at'] == null
            ? null
            : DateTime.parse(json['shipped_at'] as String),
      );

  final String orderId;
  final int userId;
  final double total;
  final String status;
  final DateTime? shippedAt;

  Map<String, dynamic> toJson() => {
        'order_id': orderId,
        'user_id': userId,
        'total': total,
        'status': status,
        if (shippedAt != null) 'shipped_at': shippedAt!.toIso8601String(),
      };
}

void main() {
  const raw = '''
  [
    {"order_id": "ORD-10001", "user_id": 82, "total": 104.35,
     "status": "delivered", "shipped_at": "2025-11-03T09:15:00Z"},
    {"order_id": "ORD-10002", "user_id": 6, "total": 42.99, "status": "pending"}
  ]
  ''';

  final decoded = (jsonDecode(raw) as List<dynamic>)
      .map((entry) => Order.fromJson(entry as Map<String, dynamic>))
      .toList();

  for (final order in decoded) {
    print('${order.orderId} ${order.status.padRight(10)} ${order.total}');
  }

  final total = decoded.fold<double>(0, (sum, order) => sum + order.total);
  print('total ${total.toStringAsFixed(2)}');

  final encoder = JsonEncoder.withIndent('  ');
  print(encoder.convert(decoded.map((order) => order.toJson()).toList()));

  try {
    jsonDecode('{"unterminated": ');
  } on FormatException catch (error) {
    print('caught: ${error.message}');
  }
}
