import 'dart:convert';

class ApiResponse {
  final bool success;
  final int statusCode;
  final UserModel? data;
  final dynamic error;

  ApiResponse({
    required this.success,
    required this.statusCode,
    this.data,
    this.error,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      success: json['success'] as bool? ?? false,
      statusCode: json['statusCode'] is int
          ? json['statusCode'] as int
          : int.tryParse('${json['statusCode']}') ?? 0,
      data: json['data'] != null
          ? UserModel.fromJson(Map<String, dynamic>.from(json['data']))
          : null,
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'statusCode': statusCode,
      'data': data?.toJson(),
      'error': error,
    };
  }

  /// Encode/decode helpers if you ever want to persist ApiResponse itself
  String toRawJson() => json.encode(toJson());

  static ApiResponse fromRawJson(String str) =>
      ApiResponse.fromJson(json.decode(str) as Map<String, dynamic>);
}

class UserModel {
  final int userId;
  final String username;
  final String mobileNumber;
  final String email;
  final String userImage;
  final String roleName;
  final String fcmToken;

  UserModel({
    required this.userId,
    required this.username,
    required this.mobileNumber,
    required this.email,
    required this.userImage,
    required this.roleName,
    required this.fcmToken,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'] is int
          ? json['userId'] as int
          : int.tryParse('${json['userId']}') ?? 0,
      username: json['username'] as String? ?? '',
      mobileNumber: json['mobileNumber'] as String? ?? '',
      email: json['email'] as String? ?? '',
      userImage: json['userImage'] as String? ?? '',
      roleName: json['roleName'] as String? ?? '',
      fcmToken: json['fcmToken'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'mobileNumber': mobileNumber,
      'email': email,
      'userImage': userImage,
      'roleName': roleName,
      'fcmToken': fcmToken,
    };
  }

  /// For SharedPreferences: stringify to JSON
  String toRawJson() => json.encode(toJson());

  /// For SharedPreferences: parse back from raw JSON string
  static UserModel? fromRawJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserModel.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  UserModel copyWith({
    int? userId,
    String? username,
    String? mobileNumber,
    String? email,
    String? userImage,
    String? roleName,
    String? fcmToken,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      userImage: userImage ?? this.userImage,
      roleName: roleName ?? this.roleName,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}
