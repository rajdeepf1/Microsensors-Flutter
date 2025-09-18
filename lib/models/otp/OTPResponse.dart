class OtpResponse {
  final bool success;
  final int statusCode;
  final String? data; // data will always be a String (or null)
  final String? error;

  OtpResponse({
    required this.success,
    required this.statusCode,
    this.data,
    this.error,
  });

  factory OtpResponse.fromJson(Map<String, dynamic> json) {
    return OtpResponse(
      success: json['success'] as bool? ?? false,
      statusCode: json['statusCode'] is int
          ? json['statusCode'] as int
          : int.tryParse('${json['statusCode']}') ?? 0,
      data: json['data']?.toString(),
      error: json['error'] as String?,
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
}
