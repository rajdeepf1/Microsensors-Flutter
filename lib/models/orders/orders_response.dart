class OrderResponse {
  final bool success;
  final int statusCode;
  final OrderData? data;
  final String? error;

  OrderResponse({
    required this.success,
    required this.statusCode,
    this.data,
    this.error,
  });

  factory OrderResponse.fromJson(Map<String, dynamic> json) {
    return OrderResponse(
      success: json["success"],
      statusCode: json["statusCode"],
      data: json["data"] != null ? OrderData.fromJson(json["data"]) : null,
      error: json["error"],
    );
  }
}

class OrderData {
  final int orderId;
  final int productId;
  final String productName;
  final int salesPersonId;
  final String salesPersonName;
  final int productionManagerId;
  final String productionManagerName;
  final int quantity;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  OrderData({
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.salesPersonId,
    required this.salesPersonName,
    required this.productionManagerId,
    required this.productionManagerName,
    required this.quantity,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory OrderData.fromJson(Map<String, dynamic> json) {
    return OrderData(
      orderId: json["orderId"],
      productId: json["productId"],
      productName: json["productName"],
      salesPersonId: json["salesPersonId"],
      salesPersonName: json["salesPersonName"],
      productionManagerId: json["productionManagerId"],
      productionManagerName: json["productionManagerName"],
      quantity: json["quantity"],
      status: json["status"],
      createdAt: DateTime.parse(json["createdAt"]),
      updatedAt: json["updatedAt"] != null ? DateTime.tryParse(json["updatedAt"]) : null,
    );
  }
}
