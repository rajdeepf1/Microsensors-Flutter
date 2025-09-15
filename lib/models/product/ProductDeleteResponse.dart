class ProductDeleteResponse {
  final bool success;
  final int statusCode;
  final dynamic data; // can be string or null
  final String? error;

  ProductDeleteResponse({
    required this.success,
    required this.statusCode,
    this.data,
    this.error,
  });

  factory ProductDeleteResponse.fromJson(Map<String, dynamic> json) {
    return ProductDeleteResponse(
      success: json['success'] ?? false,
      statusCode: json['statusCode'] ?? 0,
      data: json['data'],
      error: json['error'],
    );
  }
}
