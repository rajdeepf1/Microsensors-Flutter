class OrderStatusCountModel {
  final int created;
  final int received;
  final int productionStarted;
  final int dispatched;
  final int rejected;
  final int total;

  const OrderStatusCountModel({
    required this.created,
    required this.received,
    required this.productionStarted,
    required this.dispatched,
    required this.rejected,
    required this.total,
  });

  factory OrderStatusCountModel.fromJson(Map<String, dynamic> json) {
    return OrderStatusCountModel(
      created: json['created'] ?? 0,
      received: json['received'] ?? 0,
      productionStarted: json['productionStarted'] ?? 0,
      dispatched: json['dispatched'] ?? 0,
      rejected: json['rejected'] ?? 0,
      total: json['total'] ?? 0,
    );
  }
}
