class OrderRequest {
  final int productId;
  final int salesPersonId;
  final int productionManagerId;
  final int quantity;
  final String status;

  OrderRequest({
    required this.productId,
    required this.salesPersonId,
    required this.productionManagerId,
    required this.quantity,
    required this.status,
  });

  /// Convert Dart object → JSON (for API request)
  Map<String, dynamic> toJson() {
    return {
      "productId": productId,
      "salesPersonId": salesPersonId,
      "productionManagerId": productionManagerId,
      "quantity": quantity,
      "status": status,
    };
  }

  /// Convert JSON → Dart object (optional, in case API returns same object)
  factory OrderRequest.fromJson(Map<String, dynamic> json) {
    return OrderRequest(
      productId: json["productId"],
      salesPersonId: json["salesPersonId"],
      productionManagerId: json["productionManagerId"],
      quantity: json["quantity"],
      status: json["status"],
    );
  }
}
