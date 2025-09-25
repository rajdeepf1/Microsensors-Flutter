// lib/models/pm_order_list_item.dart
class PmOrderListItem {
  final int? orderId;
  final int? productId;
  final String? productName;
  final String? productImage;
  final String? sku;

  final int? salesPersonId;
  final String? salesPersonName;
  final String? salesPersonImage;

  final int? productionManagerId;
  final String? productionManagerName;
  final String? productionManagerImage;

  final int? quantity;
  final String? currentStatus;
  final DateTime? createdAt;

  final List<StatusHistory> statusHistory;
  final List<String> allowedNextStatuses;

  PmOrderListItem({
    this.orderId,
    this.productId,
    this.productName,
    this.productImage,
    this.sku,
    this.salesPersonId,
    this.salesPersonName,
    this.salesPersonImage,
    this.productionManagerId,
    this.productionManagerName,
    this.productionManagerImage,
    this.quantity,
    this.currentStatus,
    this.createdAt,
    this.statusHistory = const [],
    this.allowedNextStatuses = const [],
  });

  factory PmOrderListItem.fromJson(Map<String, dynamic> json) {
    return PmOrderListItem(
      orderId: json['orderId'],
      productId: json['productId'],
      productName: json['productName'],
      productImage: json['productImage'],
      sku: json['sku'],
      salesPersonId: json['salesPersonId'],
      salesPersonName: json['salesPersonName'],
      salesPersonImage: json['salesPersonImage'],
      productionManagerId: json['productionManagerId'],
      productionManagerName: json['productionManagerName'],
      productionManagerImage: json['productionManagerImage'],
      quantity: json['quantity'],
      currentStatus: json['currentStatus'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      statusHistory: (json['statusHistory'] as List<dynamic>?)
          ?.map((e) => StatusHistory.fromJson(e))
          .toList() ??
          [],
      allowedNextStatuses: (json['allowedNextStatuses'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
          [],
    );
  }
}

class StatusHistory {
  final int? historyId;
  final int? orderId;
  final String? oldStatus;
  final String? newStatus;
  final int? changedBy;
  final DateTime? changedAt;

  StatusHistory({
    this.historyId,
    this.orderId,
    this.oldStatus,
    this.newStatus,
    this.changedBy,
    this.changedAt,
  });

  factory StatusHistory.fromJson(Map<String, dynamic> json) {
    return StatusHistory(
      historyId: json['historyId'],
      orderId: json['orderId'],
      oldStatus: json['oldStatus'],
      newStatus: json['newStatus'],
      changedBy: json['changedBy'],
      changedAt: json['changedAt'] != null ? DateTime.parse(json['changedAt']) : null,
    );
  }
}
