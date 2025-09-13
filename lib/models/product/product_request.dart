class ProductRequest {
  final String productName;
  final String? description;
  final double? price;
  final int? stockQuantity;
  final String? sku;
  final String? status; // "ACTIVE" / "INACTIVE"
  final int? createdByUserId; // backend expects createdBy user id

  ProductRequest({
    required this.productName,
    this.description,
    this.price,
    this.stockQuantity,
    this.sku,
    this.status,
    this.createdByUserId,
  });

  Map<String, dynamic> toJson() => {
    'productName': productName,
    'description': description,
    'price': price,
    'stockQuantity': stockQuantity,
    'sku': sku,
    'status': status,
    'createdByUserId': createdByUserId,
  };
}
