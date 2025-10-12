class ChangeOrderStatusModel {
  final bool success;
  final int statusCode;
  final String? data;
  final String? error;

  ChangeOrderStatusModel({
    required this.success,
    required this.statusCode,
    this.data,
    this.error,
  });

  factory ChangeOrderStatusModel.fromJson(Map<String, dynamic> json) {
    return ChangeOrderStatusModel(
      success: json['success'] ?? false,
      statusCode: json['statusCode'] ?? 0,
      data: json['data']?.toString(),
      error: json['error']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'statusCode': statusCode,
      'data': data,
      'error': error,
    };
  }

  bool get isSuccess => success && (error == null || error!.isEmpty);
}