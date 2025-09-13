class ProductResponse {
  final bool success;
  final int statusCode;
  final Map<String, dynamic>? data; // adapt to your ProductResponseDto fields
  final String? error;

  ProductResponse({
    required this.success,
    required this.statusCode,
    this.data,
    this.error,
  });

  factory ProductResponse.fromJson(Map<String, dynamic> json) {
    return ProductResponse(
      success: json['success'] == true,
      statusCode: json['statusCode'] is int ? json['statusCode'] : int.tryParse('${json['statusCode']}') ?? 0,
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : null,
      error: json['error']?.toString(),
    );
  }
}
