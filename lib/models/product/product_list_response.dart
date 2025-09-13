class ProductListResponse {
  final bool success;
  final int statusCode;
  final List<dynamic>? data; // <-- changed to List
  final String? error;

  ProductListResponse({
    required this.success,
    required this.statusCode,
    this.data,
    this.error,
  });

  factory ProductListResponse.fromJson(Map<String, dynamic> json) {
    return ProductListResponse(
      success: json['success'] == true,
      statusCode: json['statusCode'] is int
          ? json['statusCode']
          : int.tryParse('${json['statusCode']}') ?? 0,
      data: json['data'] is List ? List<dynamic>.from(json['data']) : null,
      error: json['error']?.toString(),
    );
  }

  /// Helper to convert data into List<ProductDataModel>
  List<ProductDataModel> toProductList() {
    final list = data ?? <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map((m) => ProductDataModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }
}


class ProductDataModel {
  final int productId;
  final String productName;
  final String description;
  final double price;
  final int stockQuantity;
  final String sku;
  final String status;
  final String? productImage;
  final int createdByUserId;
  final String createdByUsername;
  final String createdAt;
  final String? updatedAt;

  ProductDataModel({
    required this.productId,
    required this.productName,
    required this.description,
    required this.price,
    required this.stockQuantity,
    required this.sku,
    required this.status,
    required this.productImage,
    required this.createdByUserId,
    required this.createdByUsername,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductDataModel.fromJson(Map<String, dynamic> json) {
    return ProductDataModel(
      productId: json['productId'] as int,
      productName: json['productName'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: json['stockQuantity'] as int? ?? 0,
      sku: json['sku'] ?? '',
      status: json['status'] ?? '',
      productImage: json['productImage'],
      createdByUserId: json['createdByUserId'] as int,
      createdByUsername: json['createdByUsername'] ?? '',
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'],
    );
  }

  /// Custom formatted date (no intl)
  String get formattedCreatedAt {
    try {
      final parsed = DateTime.parse(createdAt).toLocal();
      final day = parsed.day.toString().padLeft(2, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      final year = parsed.year;

      final hour = parsed.hour > 12 ? parsed.hour - 12 : parsed.hour;
      final minute = parsed.minute.toString().padLeft(2, '0');
      final ampm = parsed.hour >= 12 ? 'PM' : 'AM';

      return "$day-$month-$year $hour:$minute $ampm";
    } catch (_) {
      return createdAt; // fallback to raw string if parse fails
    }
  }
}



