// lib/models/orders/order_response_model.dart
class ProductionManagerChangeStatusResponse {
  final int? orderId;
  final int? productId;
  final String? productName;
  final int? salesPersonId;
  final String? salesPersonName;
  final int? productionManagerId;
  final String? productionManagerName;
  final int? quantity;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // history from server may be null; if you later return full history, add List<StatusHistoryModel>
  ProductionManagerChangeStatusResponse({
    this.orderId,
    this.productId,
    this.productName,
    this.salesPersonId,
    this.salesPersonName,
    this.productionManagerId,
    this.productionManagerName,
    this.quantity,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductionManagerChangeStatusResponse.fromJson(Map<String, dynamic> json) {
    DateTime? _parse(String? s) {
      if (s == null) return null;
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    final data = json;
    return ProductionManagerChangeStatusResponse(
      orderId: data['orderId'] is int ? data['orderId'] as int : (data['orderId'] != null ? int.tryParse('${data['orderId']}') : null),
      productId: data['productId'] is int ? data['productId'] as int : (data['productId'] != null ? int.tryParse('${data['productId']}') : null),
      productName: data['productName'] as String?,
      salesPersonId: data['salesPersonId'] is int ? data['salesPersonId'] as int : (data['salesPersonId'] != null ? int.tryParse('${data['salesPersonId']}') : null),
      salesPersonName: data['salesPersonName'] as String?,
      productionManagerId: data['productionManagerId'] is int ? data['productionManagerId'] as int : (data['productionManagerId'] != null ? int.tryParse('${data['productionManagerId']}') : null),
      productionManagerName: data['productionManagerName'] as String?,
      quantity: data['quantity'] is int ? data['quantity'] as int : (data['quantity'] != null ? int.tryParse('${data['quantity']}') : null),
      status: data['status'] as String?,
      createdAt: _parse(data['createdAt'] as String?),
      updatedAt: _parse(data['updatedAt'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'productId': productId,
    'productName': productName,
    'salesPersonId': salesPersonId,
    'salesPersonName': salesPersonName,
    'productionManagerId': productionManagerId,
    'productionManagerName': productionManagerName,
    'quantity': quantity,
    'status': status,
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };
}
