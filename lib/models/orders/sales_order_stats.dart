// lib/models/order/order_stats.dart
class OrderStats {
  final int active;
  final int inProduction;
  final int dispatched;

  OrderStats({required this.active, required this.inProduction, required this.dispatched});

  factory OrderStats.fromJson(Map<String, dynamic> m) {
    return OrderStats(
      active: (m['active'] as num?)?.toInt() ?? 0,
      inProduction: (m['inProduction'] as num?)?.toInt() ?? 0,
      dispatched: (m['dispatched'] as num?)?.toInt() ?? 0,
    );
  }
}
