// models/orders/order_models.dart
class StatusHistoryItem {
  final int historyId;
  final int orderId;
  final String? oldStatus;
  final String? newStatus;
  final int? changedBy;
  final DateTime? changedAt;

  StatusHistoryItem({
    required this.historyId,
    required this.orderId,
    this.oldStatus,
    required this.newStatus,
    this.changedBy,
    required this.changedAt,
  });

  factory StatusHistoryItem.fromJson(Map<String, dynamic> j){
    return StatusHistoryItem(
      historyId: j['historyId'] as int,
      orderId: j['orderId'] as int,
      oldStatus: j['oldStatus'] as String?,
      newStatus: j['newStatus'] as String?,
      changedBy: j['changedBy'] as int?,
      changedAt: j['changedAt'] != null ? DateTime.parse(j['changedAt'] as String).toLocal() : null,
    );
  }
}
