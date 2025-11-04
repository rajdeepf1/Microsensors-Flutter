class OrderResponseModel {
  final int? orderId;
  final int? salesPersonId;
  final String? salesPersonName;
  final String? salesPersonImage;
  final int? productionManagerId;
  final String? productionManagerName;
  final String? productionManagerImage;
  final String? status;
  final String? clientName;
  final String? remarks;
  final String? priority;
  final DateTime? createdAt;
  final DateTime? dispatchOn;
  final String? orderImage;

  final List<OrderProductItem> items;
  final List<OrderHistoryItem> history;

  OrderResponseModel({
    this.orderId,
    this.salesPersonId,
    this.salesPersonName,
    this.salesPersonImage,
    this.productionManagerId,
    this.productionManagerName,
    this.productionManagerImage,
    this.status,
    this.clientName,
    this.remarks,
    this.priority,
    this.createdAt,
    this.dispatchOn,
    this.orderImage,
    this.items = const [],
    this.history = const [],
  });

  factory OrderResponseModel.fromJson(Map<String, dynamic> json) {
    return OrderResponseModel(
      orderId: json['orderId'],
      salesPersonId: json['salesPersonId'],
      salesPersonName: json['salesPersonName'],
      salesPersonImage: json['salesPersonImage'],
      productionManagerId: json['productionManagerId'],
      productionManagerName: json['productionManagerName'],
      productionManagerImage: json['productionManagerImage'],
      status: json['status'],
      clientName: json['clientName'],
      remarks: json['remarks'],
      priority: json['priority'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      dispatchOn: json['dispatchOn'] != null ? DateTime.parse(json['dispatchOn']) : null,
      orderImage: json['orderImage'],
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => OrderProductItem.fromJson(Map<String, dynamic>.from(e)))
          .toList() ??
          [],
      history: (json['history'] as List<dynamic>?)
          ?.map((e) => OrderHistoryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList() ??
          [],
    );
  }
}

class OrderProductItem {
  final int? productId;
  final String? productName;
  final String? description;
  final String? sku;
  final String? status;
  final int? quantity;
  final String? productImage;

  OrderProductItem({
    this.productId,
    this.productName,
    this.description,
    this.sku,
    this.status,
    this.quantity,
    this.productImage,
  });

  factory OrderProductItem.fromJson(Map<String, dynamic> json) {
    return OrderProductItem(
      productId: json['productId'],
      productName: json['productName'],
      description: json['description'],
      sku: json['sku'],
      status: json['status'],
      quantity: json['quantity'],
      productImage: json['productImage'],
    );
  }
}

class OrderHistoryItem {
  final int? historyId;
  final int? orderId;
  final String? oldStatus;
  final String? newStatus;
  final int? changedBy;
  final DateTime? changedAt;

  OrderHistoryItem({
    this.historyId,
    this.orderId,
    this.oldStatus,
    this.newStatus,
    this.changedBy,
    this.changedAt,
  });

  factory OrderHistoryItem.fromJson(Map<String, dynamic> json) {
    return OrderHistoryItem(
      historyId: json['historyId'],
      orderId: json['orderId'],
      oldStatus: json['oldStatus'],
      newStatus: json['newStatus'],
      changedBy: json['changedBy'],
      changedAt: json['changedAt'] != null ? DateTime.parse(json['changedAt']) : null,
    );
  }
}
