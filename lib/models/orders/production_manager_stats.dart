class PmOrderStats {
  final int created;
  final int received;
  final int productionStarted;
  final int productionCompleted;
  final int dispatched;
  final int acknowledged;

  PmOrderStats({
    required this.created,
    required this.received,
    required this.productionStarted,
    required this.productionCompleted,
    required this.dispatched,
    required this.acknowledged,
  });

  /// Factory constructor to build from API response
  factory PmOrderStats.fromJson(Map<String, dynamic> json) {
    return PmOrderStats(
      created: (json['Created'] as num?)?.toInt() ?? 0,
      received: (json['Received'] as num?)?.toInt() ?? 0,
      productionStarted: (json['Production Started'] as num?)?.toInt() ?? 0,
      productionCompleted: (json['Production Completed'] as num?)?.toInt() ?? 0,
      dispatched: (json['Dispatched'] as num?)?.toInt() ?? 0,
      acknowledged: (json['Acknowledged'] as num?)?.toInt() ?? 0,
    );
  }

  /// Convert back to Map (if needed)
  Map<String, int> toMap() {
    return {
      'Created': created,
      'Received': received,
      'Production Started': productionStarted,
      'Production Completed': productionCompleted,
      'Dispatched': dispatched,
      'Acknowledged': acknowledged,
    };
  }
}
